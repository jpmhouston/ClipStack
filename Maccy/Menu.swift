// swiftlint:disable file_length
import AppKit

// Custom menu supporting "search-as-you-type" based on https://github.com/mikekazakov/MGKMenuWithFilter.
// swiftlint:disable type_body_length
class Menu: NSMenu, NSMenuDelegate {
  static let menuWidth = 300
  static let popoverGap = 5.0

  class IndexedItem: NSObject {
    var value: String
    var title: String { item?.title ?? "" }
    var item: HistoryItem?
    var menuItems: [HistoryMenuItem]
    var popoverAnchor: NSMenuItem?

    init(value: String, item: HistoryItem?, menuItems: [HistoryMenuItem]) {
      self.value = value
      self.item = item
      self.menuItems = menuItems
      if #unavailable(macOS 14) {
        self.popoverAnchor = HistoryMenuItem.PreviewMenuItem()
      }
    }
  }

  public let maxHotKey = 9

  public var isVisible: Bool = false

  internal var historyMenuItems: [HistoryMenuItem] {
    items.compactMap({ $0 as? HistoryMenuItem })
  }

  private let search = Search()

  private static let subsequentPreviewDelay = 0.2
  private var initialPreviewDelay: Double { Double(UserDefaults.standard.previewDelay) / 1000 }
  private lazy var previewThrottle = Throttler(minimumDelay: initialPreviewDelay)
  private var previewPopover: NSPopover?

  private let historyMenuItemOffset = 1 // The first item is reserved for header.
  private let historyMenuItemsGroup = 2 // 1 main and 2 alternates
  private var previewMenuItemOffset = 0

  private var clipboard: Clipboard!
  private var history: History!

  private var indexedItems: [IndexedItem] = []

  // When menu opens, we don't know which of the alternate menu items
  // is actually visible. We would like to highlight the one that is currently
  // visible and it seems like the only way to do is to try to find out
  // which ones has keyEquivalentModifierMask matching currently pressed
  // modifier flags.
  private var firstVisibleHistoryMenuItem: HistoryMenuItem? {
    let firstMenuItems = historyMenuItems.prefix(historyMenuItemsGroup)
    return firstMenuItems.first(where: { NSEvent.modifierFlags == $0.keyEquivalentModifierMask }) ??
      firstMenuItems.first(where: { NSEvent.modifierFlags.isSuperset(of: $0.keyEquivalentModifierMask) }) ??
      firstMenuItems.first
  }

  private var maxMenuItems: Int { min(UserDefaults.standard.maxMenuItems, UserDefaults.standard.size) }
  private var maxVisibleItems: Int { maxMenuItems * historyMenuItemsGroup }
  private var lastMenuLocation: PopupLocation?
  private var menuHeader: MenuHeaderView? { items.first?.view as? MenuHeaderView }
  private var menuWindow: NSWindow? { NSApp.menuWindow }

  required init(coder decoder: NSCoder) {
    super.init(coder: decoder)
  }

  init(history: History, clipboard: Clipboard) {
    super.init(title: "Cleepp")

    self.history = history
    self.clipboard = clipboard
    self.delegate = self
    self.minimumWidth = CGFloat(Menu.menuWidth)

    if #unavailable(macOS 14) {
      self.previewMenuItemOffset = 1
    }
  }

  func popUpMenu(at location: NSPoint, ofType locationType: PopupLocation) {
    prepareForPopup(location: locationType)
    super.popUp(positioning: nil, at: location, in: nil)
  }

  func prepareForPopup(location: PopupLocation) {
    lastMenuLocation = location
    updateItemVisibility()
  }

  func menuWillOpen(_ menu: NSMenu) {
    isVisible = true
    previewThrottle.minimumDelay = initialPreviewDelay
    
    // TODO: restore this if we want to highlight the first history item when menu opens
//    highlight(firstVisibleHistoryMenuItem ?? historyMenuItems.first)
  }

  func menuDidClose(_ menu: NSMenu) {
    isVisible = false
    lastMenuLocation = nil
    offloadCurrentPreview()
    
    Maccy.showExpandedMenu = false // revert to showing full menu next time (until option-clicked again)
    
    DispatchQueue.main.async {
      self.menuHeader?.setQuery("", throttle: false)
      self.menuHeader?.queryField.refusesFirstResponder = true
    }
  }

  func menu(_ menu: NSMenu, willHighlight item: NSMenuItem?) {
    offloadCurrentPreview()

    guard let item = item as? HistoryMenuItem else {
      return
    }

    previewThrottle.throttle { [self] in
      previewPopover = NSPopover()
      previewPopover?.animates = false
      previewPopover?.behavior = .semitransient
      previewPopover?.contentViewController = Preview(item: item.item)

      guard let previewWindow = menuWindow,
            let windowContentView = previewWindow.contentView,
            let boundsOfVisibleMenuItem = boundsOfMenuItem(item, windowContentView) else {
        return
      }

      previewThrottle.minimumDelay = Menu.subsequentPreviewDelay

      previewPopover?.show(
        relativeTo: boundsOfVisibleMenuItem,
        of: windowContentView,
        preferredEdge: .maxX
      )

      if let popoverWindow = previewPopover?.contentViewController?.view.window {
        if popoverWindow.frame.minX < previewWindow.frame.minX {
          popoverWindow.setFrameOrigin(
            NSPoint(x: popoverWindow.frame.minX - Menu.popoverGap, y: popoverWindow.frame.minY)
          )
        } else {
          popoverWindow.setFrameOrigin(
            NSPoint(x: popoverWindow.frame.minX + Menu.popoverGap, y: popoverWindow.frame.minY)
          )
        }
      }
    }
  }

  func buildItems() {
    clearAll()

    for item in history.all {
      let menuItems = buildMenuItems(item)
      guard let menuItem = menuItems.first else {
        continue
      }
      let indexedItem = IndexedItem(
        value: menuItem.value,
        item: item,
        menuItems: menuItems
      )
      indexedItems.append(indexedItem)
      menuItems.forEach(safeAddItem)
      addPopoverAnchor(indexedItem)
    }
  }

  func add(_ item: HistoryItem) {
    let sortedItems = history.all
    guard let insertionIndex = sortedItems.firstIndex(where: { $0 == item }) else {
      return
    }

    let menuItems = buildMenuItems(item)
    guard let menuItem = menuItems.first else {
      return
    }
    let indexedItem = IndexedItem(
      value: menuItem.value,
      item: item,
      menuItems: menuItems
    )
    indexedItems.insert(indexedItem, at: insertionIndex)

    ensureInEventTrackingModeIfVisible {
      let menuItemInsertionIndex = insertionIndex * (self.historyMenuItemsGroup + self.previewMenuItemOffset) + self.historyMenuItemOffset
      self.insertPopoverAnchor(indexedItem, menuItemInsertionIndex)

      for menuItem in menuItems.reversed() {
        self.safeInsertItem(menuItem, at: menuItemInsertionIndex)
      }

      self.clearRemovedItems()
    }
  }

  func clearAll() {
    clear(indexedItems)
  }

  // TODO: will be removed, not sure if we want a special version of clear in its place or not
  func clearUnpinned() {
    clear(indexedItems) // was: clear(indexedItems.filter({ $0.item?.pin == nil }))
  }

  func updateFilter(filter: String) {
    let window = menuWindow
    var savedTopLeft = window?.frame.origin ?? NSPoint()
    savedTopLeft.y += window?.frame.height ?? 0.0
    
    var results = search.search(string: filter, within: indexedItems)
    
    // Strip the results that are longer than visible items.
    if maxMenuItems > 0 && maxMenuItems < results.count {
      results = Array(results[0...maxMenuItems - 1])
    }
    
    // Get all the items that match results.
    let foundItems = results.map({ $0.object })
    
    // TODO: figure out if we really can skip all this
//    // Ensure that pinned items are visible after search is cleared.
//    if filter.isEmpty {
//      results.append(
//        contentsOf: indexedItems
//          .filter({ $0.item?.pin != nil })
//          .map({ Search.SearchResult(score: nil, object: $0, titleMatches: []) })
//      )
//    }
    
    // First, remove items that don't match search.
    for indexedItem in indexedItems {
      if !foundItems.contains(indexedItem) {
        indexedItem.menuItems.forEach(safeRemoveItem)
      }
      removePopoverAnchor(indexedItem)
    }
    
    // Second, update order of items to match search results order.
    for result in results.reversed() {
      if let popoverAnchor = result.object.popoverAnchor {
        safeRemoveItem(popoverAnchor)
        safeInsertItem(popoverAnchor, at: historyMenuItemOffset)
      }
      for menuItem in result.object.menuItems.reversed() {
        safeRemoveItem(menuItem)
        menuItem.highlight(result.titleMatches)
        safeInsertItem(menuItem, at: historyMenuItemOffset)
      }
    }
    
    // TODO: restore this if we want to highlight the first history item when menu opens
//    highlight(historyMenuItems.first)
    
    ensureInEventTrackingModeIfVisible(dispatchLater: true) {
      let window = self.menuWindow
      window?.setFrameTopLeftPoint(savedTopLeft)
    }
  }

  func select() {
    if let item = highlightedItem {
      performActionForItem(at: index(of: item))
    }
  }
  
  // TODO: figure out what this one was for, maybe being it back: func select(_ searchQuery: String)

  func select(position: Int) -> String? {
    guard indexedItems.count > position,
          let item = indexedItems[position].menuItems.first else {
      return nil
    }

    performActionForItem(at: index(of: item))
    return indexedItems[position].value
  }

  func historyItem(at position: Int) -> HistoryItem? {
    guard indexedItems.indices.contains(position) else {
      return nil
    }

    return indexedItems[position].item
  }

  func selectPrevious() {
    if !highlightNext(items.reversed()) {
      highlight(highlightableItems(items).last) // start from the end after reaching the first item
    }
  }

  func selectNext() {
    if !highlightNext(items) {
      highlight(highlightableItems(items).first) // start from the beginning after reaching the last item
    }
  }

  func delete() {
    guard let itemToRemove = highlightedItem else {
      return
    }

    if let historyItemToRemove = itemToRemove as? HistoryMenuItem {
      let historyItemToRemoveIndex = index(of: historyItemToRemove)

      // When deleting mulitple items by holding the removal keys
      // we sometimes get into a race condition with menu updating indices.
      // https://github.com/p0deje/Maccy/issues/628
      guard historyItemToRemoveIndex != -1 else { return }

      if let indexedItem = indexedItems.first(where: { $0.item == historyItemToRemove.item }) {
        removePopoverAnchor(indexedItem)
        indexedItem.menuItems.forEach(safeRemoveItem)
        if let removeIndex = indexedItems.firstIndex(of: indexedItem) {
          indexedItems.remove(at: removeIndex)
        }
      }

      history.remove(historyItemToRemove.item)

      updateItemVisibility()
      highlight(items[historyItemToRemoveIndex])
    }
  }

  func delete(position: Int) -> String? {
    guard indexedItems.count > position else {
      return nil
    }

    let indexedItem = indexedItems[position]
    let value = indexedItem.value

    removePopoverAnchor(indexedItem)
    indexedItem.menuItems.forEach(safeRemoveItem)
    history.remove(indexedItem.item)
    indexedItems.remove(at: position)

    return value
  }

  func resizeImageMenuItems() {
    historyMenuItems.forEach {
      $0.resizeImage()
    }
  }

  func regenerateMenuItemTitles() {
    historyMenuItems.forEach {
      $0.regenerateTitle()
    }
    update()
  }

  func updateItemVisibility() {
    // TODO: fix this to hide all when not option-clicked menu, hide all but queued when in queued mode
    let historyMenuItemsCount = historyMenuItems.count

    if maxVisibleItems <= 0 {
      let allItemsCount = indexedItems.flatMap({ $0.menuItems }).count
      if historyMenuItemsCount < allItemsCount {
        appendItemsUntilLimit(allItemsCount)
      }
    } else if historyMenuItemsCount < maxVisibleItems {
      appendItemsUntilLimit(historyMenuItemsCount)
    } else { // historyMenuItemsCount >= maxVisibleItems
      hideItemsOverLimit(historyMenuItemsCount)
    }
  }

  internal func adjustMenuWindowPosition() {
    guard let location = lastMenuLocation else {
      return
    }
    if let point = location.location(for: self.size) {
      menuWindow?.setFrameTopLeftPoint(point)
    }
  }

  private func highlightNext(_ items: [NSMenuItem]) -> Bool {
    let highlightableItems = self.highlightableItems(items)
    let currentHighlightedItem = highlightedItem ?? highlightableItems.first
    var itemsIterator = highlightableItems.makeIterator()
    while let item = itemsIterator.next() {
      if item == currentHighlightedItem {
        if let itemToHighlight = itemsIterator.next() {
          highlight(itemToHighlight)
          return true
        }
      }
    }
    return false
  }

  private func highlightableItems(_ items: [NSMenuItem]) -> [NSMenuItem] {
    return items.filter { !$0.isSeparatorItem && $0.isEnabled && !$0.isHidden }
  }

  private func highlight(_ itemToHighlight: NSMenuItem?) {
    if #available(macOS 14, *) {
      DispatchQueue.main.async { self.highlightItem(itemToHighlight) }
    } else {
      highlightItem(itemToHighlight)
    }
  }

  private func highlightItem(_ itemToHighlight: NSMenuItem?) {
    let highlightItemSelector = NSSelectorFromString("highlightItem:")
    // we need to highlight filter menu item to force menu redrawing
    // when it has more items that can fit into the screen height
    // and scrolling items are added to the top and bottom of menu
    perform(highlightItemSelector, with: items.first)
    if let item = itemToHighlight, !item.isHighlighted, items.contains(item) {
      perform(highlightItemSelector, with: item)
    } else {
      // Unhighlight current item.
      perform(highlightItemSelector, with: nil)
    }
  }

  private func clear(_ itemsToClear: [IndexedItem]) {
    for indexedItem in itemsToClear {
      removePopoverAnchor(indexedItem)
      indexedItem.menuItems.forEach(safeRemoveItem)

      if let removeIndex = indexedItems.firstIndex(of: indexedItem) {
        indexedItems.remove(at: removeIndex)
      }
    }
  }

  private func addPopoverAnchor(_ item: IndexedItem) {
    if #unavailable(macOS 14), let popoverAnchor = item.popoverAnchor {
      safeAddItem(popoverAnchor)
    }
  }

  private func insertPopoverAnchor(_ item: IndexedItem, _ index: Int) {
    if #unavailable(macOS 14), let popoverAnchor = item.popoverAnchor {
      safeInsertItem(popoverAnchor, at: index)
    }
  }

  private func removePopoverAnchor(_ item: IndexedItem) {
    if #unavailable(macOS 14) {
      safeRemoveItem(item.popoverAnchor)
    }
  }

  private func hideItemsOverLimit(_ limit: Int) {
    var limit = limit
    for indexedItem in indexedItems.reversed() {
      if maxVisibleItems != 0 && maxVisibleItems >= limit {
        return
      }
      
      let menuItems = indexedItem.menuItems.filter({ historyMenuItems.contains($0) })
      if menuItems.isEmpty {
        continue
      }
      
      removePopoverAnchor(indexedItem)
      menuItems.forEach { historyMenuItem in
        safeRemoveItem(historyMenuItem)
        limit -= 1
      }
    }
  }

  private func appendItemsUntilLimit(_ limit: Int) {
    var limit = limit
    for indexedItem in indexedItems {
      // TODO: fix the logic of this so that when in queue mode there's no limit
      if maxVisibleItems != 0 && maxVisibleItems <= limit {
        return
      }
      
      // if menu contains this item already skip it
      let menuItems = indexedItem.menuItems.filter({ !historyMenuItems.contains($0) })
      if menuItems.isEmpty {
        continue
      }
      
      var insertIndex = previewMenuItemOffset + 1
      if let lastItem = historyMenuItems.last {
        insertIndex += index(of: lastItem)
      }
      insertPopoverAnchor(indexedItem, insertIndex)
      menuItems.reversed().forEach { historyMenuItem in
        safeInsertItem(historyMenuItem, at: insertIndex)
        // TODO: what is this limit such that its incremeneted inside the forEach loop, we might need a count not including alternates
        limit += 1
      }
    }
  }

  private func buildMenuItems(_ item: HistoryItem) -> [HistoryMenuItem] {
    let menuItems = [
      HistoryMenuItem.CopyMenuItem(item: item, clipboard: clipboard),
      HistoryMenuItem.StartHereMenuItem(item: item, clipboard: clipboard)
    ]
    
    assert(menuItems.count == historyMenuItemsGroup)
    
    return menuItems.sorted(by: { !$0.isAlternate && $1.isAlternate })
  }

  private func chunks(_ items: [HistoryMenuItem]) -> [[HistoryMenuItem]] {
    return stride(from: 0, to: items.count, by: historyMenuItemsGroup).map({ index in
      Array(items[index ..< Swift.min(index + historyMenuItemsGroup, items.count)])
    })
  }

  private func clearRemovedItems() {
    let currentHistoryItems = history.all
    for indexedItem in indexedItems {
      if let historyItem = indexedItem.item,
         !currentHistoryItems.contains(historyItem) {
        removePopoverAnchor(indexedItem)
        indexedItem.menuItems.forEach(safeRemoveItem)

        if let removeIndex = indexedItems.firstIndex(of: indexedItem) {
          indexedItems.remove(at: removeIndex)
        }
      }
    }
  }

  private func safeAddItem(_ item: NSMenuItem) {
    guard !items.contains(item) else {
      return
    }

    addItem(item)
  }

  private func safeInsertItem(_ item: NSMenuItem, at index: Int) {
    guard !items.contains(item), index <= items.count else {
      return
    }

    insertItem(item, at: index)
  }

  private func safeRemoveItem(_ item: NSMenuItem?) {
    guard let item = item,
          items.contains(item) else {
      return
    }

    removeItem(item)
  }

  private func offloadCurrentPreview() {
    previewThrottle.cancel()
    previewPopover?.close()
    previewPopover = nil
  }

  private func boundsOfMenuItem(_ item: NSMenuItem, _ windowContentView: NSView) -> NSRect? {
    if #available(macOS 14, *) {
      let windowRectInScreenCoordinates = windowContentView.accessibilityFrame()
      let menuItemRectInScreenCoordinates = item.accessibilityFrame()
      return NSRect(
        origin: NSPoint(
          x: menuItemRectInScreenCoordinates.origin.x - windowRectInScreenCoordinates.origin.x,
          y: menuItemRectInScreenCoordinates.origin.y - windowRectInScreenCoordinates.origin.y),
        size: menuItemRectInScreenCoordinates.size
      )
    } else {
      guard let item = item as? HistoryMenuItem,
            let itemIndex = indexedItems.firstIndex(where: { $0.menuItems.contains(item) }) else {
        return nil
      }
      let indexedItem = indexedItems[itemIndex]
      guard let previewView = indexedItem.popoverAnchor?.view else {
        return nil
      }

      func getPrecedingView() -> NSView? {
        for index in (0..<itemIndex).reversed() {
          // PreviewMenuItem always has a view
          // Check if preview item is visible (it may be hidden by the search filter)
          if let view = indexedItems[index].popoverAnchor?.view,
             view.window != nil {
            return view
          }
        }
        // If the item is the first visible one, the preceding view is the header.
        guard let header = menuHeader else {
          // Should never happen as we always have a MenuHeader installed.
          return nil
        }
        return header
      }

      guard let precedingView = getPrecedingView() else {
        return nil
      }

      let bottomPoint = previewView.convert(
        NSPoint(x: previewView.bounds.minX, y: previewView.bounds.maxY),
        to: windowContentView
      )
      let topPoint = precedingView.convert(
        NSPoint(x: previewView.bounds.minX, y: precedingView.bounds.minY),
        to: windowContentView
      )

      let heightOfVisibleMenuItem = abs(topPoint.y - bottomPoint.y)
      return NSRect(
        origin: bottomPoint,
        size: NSSize(width: item.menu?.size.width ?? 0, height: heightOfVisibleMenuItem)
      )
    }
  }

  private func ensureInEventTrackingModeIfVisible(
    dispatchLater: Bool = false,
    block: @escaping () -> Void
  ) {
    if isVisible && (
      dispatchLater ||
      RunLoop.current != RunLoop.main ||
      RunLoop.current.currentMode != .eventTracking
    ) {
      RunLoop.main.perform(inModes: [.eventTracking], block: block)
    } else {
      block()
    }
  }
}
// swiftlint:enable type_body_length
// swiftlint:enable file_length
