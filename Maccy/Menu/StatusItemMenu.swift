// swiftlint:disable file_length
import AppKit

// Custom menu supporting "search-as-you-type" based on https://github.com/mikekazakov/MGKMenuWithFilter.
// swiftlint:disable type_body_length
class StatusItemMenu: NSMenu, NSMenuDelegate {
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
  
  enum Item: Int, CaseIterable {
    // these must match tag values set in nib file
    case queueStart = 101
    case queueStop
    case queueCopy
    case queuePaste
    case clear
    case undoLastCopy
    case preferences
    case about
    case quit
  }
  
  public var isVisible: Bool = false
  
  internal var historyMenuItems: [HistoryMenuItem] {
    items.compactMap({ $0 as? HistoryMenuItem })
  }
  
  private let search = Search()
  
  private static let subsequentPreviewDelay = 0.2
  private var initialPreviewDelay: Double { Double(UserDefaults.standard.previewDelay) / 1000 }
  private lazy var previewThrottle = Throttler(minimumDelay: initialPreviewDelay)
  private var previewPopover: NSPopover?
  
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
  
  private let historyMenuItemsGroup = 2 // 1 main and 1 alternate
  private var usePopoverAnchor = false
  
  private var maxMenuItems: Int { min(UserDefaults.standard.maxMenuItems, UserDefaults.standard.size) }
  private var maxVisibleItems: Int { maxMenuItems * historyMenuItemsGroup }
  
  private var historyHeader: SearchItemView? { historyHeaderItem?.view as? SearchItemView }
  private var menuWindow: NSWindow? { NSApp.menuWindow }
  
  @IBOutlet weak var queueCopyItem: NSMenuItem?
  @IBOutlet weak var queuePasteItem: NSMenuItem?
  @IBOutlet weak var queueStartItem: NSMenuItem?
  @IBOutlet weak var queueStopItem: NSMenuItem?
  @IBOutlet weak var historyHeaderItem: NSMenuItem?
  @IBOutlet weak var trailingSeparatorItem: NSMenuItem?
  @IBOutlet weak var noteItem: NSMenuItem?
  
//  required init(coder decoder: NSCoder) {
//    super.init(coder: decoder)
//  }
  
  override func awakeFromNib() {
    self.delegate = self
    self.minimumWidth = CGFloat(StatusItemMenu.menuWidth)

    if #unavailable(macOS 14) {
      self.usePopoverAnchor = true
    }
  }
  
  func inject(history: History, clipboard: Clipboard) {
    self.history = history
    self.clipboard = clipboard
  }
  
  func prepareForPopup() {
    rebuildItemsAsNeeded()
    updateItemVisibility()
    updateShortcuts()
  }
  
  func menuWillOpen(_ menu: NSMenu) {
    isVisible = true
    previewThrottle.minimumDelay = initialPreviewDelay
    
    // TODO: restore this if we want to highlight the first history item when menu opens
//    highlight(firstVisibleHistoryMenuItem ?? historyMenuItems.first)
  }

  func menuDidClose(_ menu: NSMenu) {
    isVisible = false
    offloadCurrentPreview()
    
    Maccy.showExpandedMenu = false // revert to showing full menu next time (until option-clicked again)
    
    DispatchQueue.main.async {
      self.historyHeader?.setQuery("", throttle: false)
      self.historyHeader?.queryField.refusesFirstResponder = true
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

      previewThrottle.minimumDelay = StatusItemMenu.subsequentPreviewDelay

      previewPopover?.show(
        relativeTo: boundsOfVisibleMenuItem,
        of: windowContentView,
        preferredEdge: .maxX
      )

      if let popoverWindow = previewPopover?.contentViewController?.view.window {
        if popoverWindow.frame.minX < previewWindow.frame.minX {
          popoverWindow.setFrameOrigin(
            NSPoint(x: popoverWindow.frame.minX - StatusItemMenu.popoverGap, y: popoverWindow.frame.minY)
          )
        } else {
          popoverWindow.setFrameOrigin(
            NSPoint(x: popoverWindow.frame.minX + StatusItemMenu.popoverGap, y: popoverWindow.frame.minY)
          )
        }
      }
    }
  }

  func buildItems() {
    clear()
    
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
      menuItems.forEach(appendMenuItem)
      if usePopoverAnchor {
        appendPopoverAnchor(indexedItem)
      }
    }
  }

  func add(_ item: HistoryItem) {
    let sortedItems = history.all
    guard let insertionIndex = sortedItems.firstIndex(where: { $0 == item }) else {
      return
    }
    guard let historyHeaderItem = historyHeaderItem else {
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
    
    let firstHistoryMenuItemIndex = index(of: historyHeaderItem) + 1
    let historyMenuItemsGroupCount = historyMenuItemsGroup + (usePopoverAnchor ? 1 : 0)
    
    ensureInEventTrackingModeIfVisible {
      var menuItemInsertionIndex = firstHistoryMenuItemIndex + historyMenuItemsGroupCount * insertionIndex
      for menuItem in menuItems {
        self.safeInsertItem(menuItem, at: menuItemInsertionIndex)
        menuItemInsertionIndex += 1
      }
      if self.usePopoverAnchor {
        self.insertPopoverAnchor(indexedItem, menuItemInsertionIndex)
      }
      
      // TODO: figure out why clearRemovedItems is called here
      self.clearRemovedItems()
    }
  }
  
  func clear() {
    clear(indexedItems)
  }
  
  func updateFilter(filter: String) {
    var results = search.search(string: filter, within: indexedItems)
    
    // Strip the results that are longer than visible items.
    if maxMenuItems > 0 && maxMenuItems < results.count {
      results = Array(results[0...maxMenuItems - 1])
    }
    
    // Remove existing menu history items
    guard let historyStartItem = historyHeaderItem, let historyEndItem = trailingSeparatorItem,
          index(of: historyStartItem) < index(of: historyEndItem) else {
      return
    }
    for index in (index(of: historyStartItem) + 1 ..< index(of: historyEndItem)).reversed() {
      safeRemoveItem(at: index)
    }
    
    // Add back matching ones in search results order... if search is empty should be all original items
    for result in results {
      for menuItem in result.object.menuItems {
        menuItem.highlight(result.titleMatches)
        appendMenuItem(menuItem)
      }
      if usePopoverAnchor {
        appendPopoverAnchor(result.object)
      }
    }
    
    // TODO: restore this if we want to highlight the first history item when menu opens
//    highlight(historyMenuItems.first)
  }

  func select() {
    if let item = highlightedItem {
      performActionForItem(at: index(of: item))
    }
  }
  
  // TODO: figure out what this one was for, maybe bring it back: func select(_ searchQuery: String)
  
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
        if self.usePopoverAnchor {
          removePopoverAnchor(indexedItem)
        }
        indexedItem.menuItems.forEach(safeRemoveItem)
        if let removeIndex = indexedItems.firstIndex(of: indexedItem) {
          indexedItems.remove(at: removeIndex)
        }
      }

      history.remove(historyItemToRemove.item)

      rebuildItemsAsNeeded()
      highlight(items[historyItemToRemoveIndex])
    }
  }

  func delete(position: Int) -> String? {
    guard indexedItems.count > position else {
      return nil
    }

    let indexedItem = indexedItems[position]
    let value = indexedItem.value

    if self.usePopoverAnchor {
      removePopoverAnchor(indexedItem)
    }
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
      if self.usePopoverAnchor {
        removePopoverAnchor(indexedItem)
      }
      indexedItem.menuItems.forEach(safeRemoveItem)

      if let removeIndex = indexedItems.firstIndex(of: indexedItem) {
        indexedItems.remove(at: removeIndex)
      }
    }
  }
  
  private func rebuildItemsAsNeeded() {
    let historyMenuItemsCount = historyMenuItems.count
    
    if maxVisibleItems <= 0 {
      let allItemsCount = indexedItems.flatMap({ $0.menuItems }).count
      if historyMenuItemsCount < allItemsCount {
        appendItemsUntilLimit(allItemsCount)
      }
    } else if historyMenuItemsCount < maxVisibleItems {
      appendItemsUntilLimit(historyMenuItemsCount)
    } else { // historyMenuItemsCount >= maxVisibleItems
      removeItemsOverLimit(historyMenuItemsCount)
    }
  }
  
  private func appendMenuItem(_ item: NSMenuItem) {
    guard let historyEndItem = trailingSeparatorItem else { return }
    safeInsertItem(item, at: index(of: historyEndItem))
  }
  
  private func appendPopoverAnchor(_ item: IndexedItem) {
    if let popoverAnchor = item.popoverAnchor {
      guard let historyEndItem = trailingSeparatorItem else { return }
      safeInsertItem(popoverAnchor, at: index(of: historyEndItem))
    }
  }
  
  private func insertPopoverAnchor(_ item: IndexedItem, _ index: Int) {
    if let popoverAnchor = item.popoverAnchor {
      safeInsertItem(popoverAnchor, at: index)
    }
  }
  
  private func removePopoverAnchor(_ item: IndexedItem) {
    if let popoverAnchor = item.popoverAnchor {
      safeRemoveItem(popoverAnchor)
    }
  }
  
  private func removeItemsOverLimit(_ limit: Int) {
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
      menuItems.forEach(safeRemoveItem)
      limit -= menuItems.count
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
      
      menuItems.forEach(appendMenuItem)
      if usePopoverAnchor {
        appendPopoverAnchor(indexedItem)
      }
      limit += menuItems.count
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
      if let historyItem = indexedItem.item, !currentHistoryItems.contains(historyItem) {
        indexedItem.menuItems.forEach(safeRemoveItem)
        if usePopoverAnchor {
          removePopoverAnchor(indexedItem)
        }

        if let removeIndex = indexedItems.firstIndex(of: indexedItem) {
          indexedItems.remove(at: removeIndex)
        }
      }
    }
  }
  
  private func updateShortcuts() {
    queueCopyItem?.setShortcut(for: .queueCopy)
    queuePasteItem?.setShortcut(for: .queuePaste)
    // TODO: maybe have a start stop hotkey
//    if !Maccy.queueModeOn {
//      queueStartItem?.setShortcut(for: .queueStartStop)
//      queueStopItem?.setShortcut(for: nil)
//    } else {
//      queueStartItem?.setShortcut(for: nil)
//      queueStopItem?.setShortcut(for: .queueStartStop)
//    }
  }
  
  private func updateItemVisibility() {
    guard let historyStartItem = historyHeaderItem, let historyEndItem = trailingSeparatorItem else { return }
    
    let showAll = Maccy.showExpandedMenu
    historyStartItem.isHidden = !showAll
    for index in index(of: historyStartItem) + 1 ..< index(of: historyEndItem) {
      guard let menuItem = item(at: index) else { continue }
      menuItem.isHidden = !showAll
      
      // Must clear isAlternate for items that have modifiers when not showing expanded menu, otherwise
      // while menu is up holding that modifier will show them even irrespective of isHidden
      if !menuItem.keyEquivalentModifierMask.isEmpty {
        menuItem.isAlternate = showAll
      }
    }
    
    // if hidden all above, re-show just the items in the current queue
    let count = Maccy.queueSize ?? 0
    if !showAll {
      for historyIndex in 0 ..< count {
        guard count < indexedItems.count else { break }
        for menuitem in indexedItems[historyIndex].menuItems {
          menuitem.isHidden = false
        }
      }
    }
    
    historyEndItem.isHidden = !showAll && count == 0
  }
  
  private func safeInsertItem(_ item: NSMenuItem, at index: Int) {
    guard !items.contains(item), index <= items.count else {
      return
    }

    insertItem(item, at: index)
  }
  
  private func safeRemoveItem(_ item: NSMenuItem) {
    guard items.contains(item) else {
      return
    }

    removeItem(item)
  }
  
  private func safeRemoveItem(at index: Int) {
    guard index <= items.count else {
      return
    }
    
    if let item = item(at: index) {
      if item == trailingSeparatorItem {
        fatalError()
      }
      if item.title == "Clear…" || item.title == "Quit" {
        fatalError()
      }
    }
    
    removeItem(at: index)
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
        return historyHeader
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
