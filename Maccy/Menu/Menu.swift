// swiftlint:disable file_length
import AppKit

// Custom menu supporting "search-as-you-type" based on https://github.com/mikekazakov/MGKMenuWithFilter.
// swiftlint:disable type_body_length
class StatusItemMenu: NSMenu, NSMenuDelegate {
  static let menuWidth = 300
  static let popoverGap = 5.0
  
  internal var isVisible: Bool = false
  internal var history: History!
  
  class IndexedItem: NSObject {
    var value: String
    var title: String { item?.title ?? "" }
    var item: HistoryItem?
    var menuItems: [HistoryMenuItem]
    
    init(value: String, item: HistoryItem?, menuItems: [HistoryMenuItem]) {
      self.value = value
      self.item = item
      self.menuItems = menuItems
    }
  }
  
  private var indexedItems: [IndexedItem] = []
  private var headOfQueueIndexedItem: IndexedItem?
  
  internal var historyMenuItems: [HistoryMenuItem] {
    items.compactMap({ ($0 as? HistoryMenuItem)?.onlyIfNotIn([topAnchorItem].compactMap({ $0 })) })
  }
  
  private var historyMenuItemsGroupCount: Int { usePopoverAnchors ? 3 : 2 } // 1 main, 1 alternate, 1 popover anchor
  private var maxMenuItems: Int {
    if !Maccy.allowDictinctStorageSize {
      UserDefaults.standard.maxMenuItems
    } else if showsFullExpansion {
      max(UserDefaults.standard.maxMenuItems, UserDefaults.standard.size)
    } else {
      min(UserDefaults.standard.maxMenuItems, UserDefaults.standard.size)
    }
  }
  
  private var usePopoverAnchors = false
  private var showsExpandedMenu = false
  private var showsFullExpansion = false
  private var isFiltered = false
  private var ignoreNextHighlight = false

  private static let subsequentPreviewDelay = 0.2
  private var initialPreviewDelay: Double { Double(UserDefaults.standard.previewDelay) / 1000 }
  private lazy var previewThrottle = Throttler(minimumDelay: initialPreviewDelay)
  
  private var historyHeader: SearchItemView? { historyHeaderItem?.view as? SearchItemView }
  private let search = Search()
  private var lastHighlightedItem: HistoryMenuItem?
  private var topAnchorItem: HistoryMenuItem?
  private var previewPopover: NSPopover?
  private var protoCopyItem: HistoryMenuItem?
  private var protoReplayItem: HistoryMenuItem?
  private var protoAnchorItem: HistoryMenuItem?
  private var menuWindow: NSWindow? { NSApp.menuWindow }
  
  @IBOutlet weak var queueCopyItem: NSMenuItem?
  @IBOutlet weak var queuePasteItem: NSMenuItem?
  @IBOutlet weak var queueStartItem: NSMenuItem?
  @IBOutlet weak var queueStopItem: NSMenuItem?
  @IBOutlet weak var advanceItem: NSMenuItem?
  @IBOutlet weak var noteItem: NSMenuItem?
  @IBOutlet weak var historyHeaderItem: NSMenuItem?
  @IBOutlet weak var prototypeCopyItem: NSMenuItem?
  @IBOutlet weak var prototypeReplayItem: NSMenuItem?
  @IBOutlet weak var prototypeAnchorItem: NSMenuItem?
  @IBOutlet weak var trailingSeparatorItem: NSMenuItem?
  @IBOutlet weak var deleteItem: NSMenuItem?
  @IBOutlet weak var clearItem: NSMenuItem?
  
  // MARK: -
  
  static func load(owner: Any) -> StatusItemMenu? {
    // somewhat unconventional, perhaps in part because most of this code belongs in a controller class?
    // we already have a MenuController however its used for some other things
    // although since there's no such thing as a NSMenuController would have to do custom loading from nib anyway :shrug:
    guard let nib = NSNib(nibNamed: "Menu", bundle: nil) else {
      return nil
    }
    var nibObjects: NSArray? = NSArray()
    nib.instantiate(withOwner: owner, topLevelObjects: &nibObjects)
    return nibObjects?.compactMap({ $0 as? StatusItemMenu }).first
  }
  
  override func awakeFromNib() {
    self.delegate = self
    self.minimumWidth = CGFloat(Self.menuWidth)
    
    // save aside the prototype history menu items and remove them from the menu
    if let prototypeCopyItem = prototypeCopyItem as? HistoryMenuItem {
      protoCopyItem = prototypeCopyItem
      removeItem(prototypeCopyItem)
    }
    if let prototypeReplayItem = prototypeReplayItem as? HistoryMenuItem {
      protoReplayItem = prototypeReplayItem
      removeItem(prototypeReplayItem)
    }
    if let prototypeAnchorItem = prototypeAnchorItem as? HistoryMenuItem {
      protoAnchorItem = prototypeAnchorItem
      removeItem(prototypeAnchorItem)
    }
    
    if #unavailable(macOS 14) {
      self.usePopoverAnchors = true
    }
    // for now exercise using popover anchors even on macOS 14
    //self.usePopoverAnchors = true // TODO: remove this
  }
  
  func inject(history: History) {
    self.history = history
  }
  
  func prepareForPopup() {
    rebuildItemsAsNeeded()
    updateShortcuts()
    updateItemVisibility()
  }
  
  func menuWillOpen(_ menu: NSMenu) {
    isVisible = true
    previewThrottle.minimumDelay = initialPreviewDelay
    
    // showsExpandedMenu flag set by call to enableExpandedMenu() before the menu is opened
    // switch it back off if either not allowed or if history blank (pointless, plus it looks weird)
    if showsExpandedMenu && (!Maccy.allowExpandedHistory || historyMenuItems.isEmpty) {
      showsExpandedMenu = false
    }
    if showsExpandedMenu {
      historyHeader?.queryField.becomeFirstResponder()
    }
  }
  
  func menuDidClose(_ menu: NSMenu) {
    isVisible = false
    offloadCurrentPreview()
    
    enableExpandedMenu(false) // revert to showing small menu next time, without history,
    
    DispatchQueue.main.async {
      self.historyHeader?.setQuery("", throttle: false)
      self.historyHeader?.queryField.refusesFirstResponder = true
    }
    isFiltered = false
  }

  func menu(_ menu: NSMenu, willHighlight item: NSMenuItem?) {
    offloadCurrentPreview()

    if item == nil {
      ignoreNextHighlight = true // after being called with nil item ignore the next call
      return
    } else if ignoreNextHighlight {
      ignoreNextHighlight = false // after getting that following call, back to normal
      return
    } else  {
      enableDelete(forHighlightedItem: item)
      lastHighlightedItem = item as? HistoryMenuItem
    }

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

      previewThrottle.minimumDelay = Self.subsequentPreviewDelay

      previewPopover?.show(
        relativeTo: boundsOfVisibleMenuItem,
        of: windowContentView,
        preferredEdge: .maxX
      )

      if let popoverWindow = previewPopover?.contentViewController?.view.window {
        if popoverWindow.frame.minX < previewWindow.frame.minX {
          popoverWindow.setFrameOrigin(
            NSPoint(x: popoverWindow.frame.minX - Self.popoverGap, y: popoverWindow.frame.minY)
          )
        } else {
          popoverWindow.setFrameOrigin(
            NSPoint(x: popoverWindow.frame.minX + Self.popoverGap, y: popoverWindow.frame.minY)
          )
        }
      }
    }
  }
  
  // MARK: -

  func buildItems() {
    clear() // wipes indexedItems as well as history menu items
    
    if usePopoverAnchors {
      insertTopAnchorItem()
    }

    let historyItems = history.all
    
    for item in historyItems {
      let menuItems = buildMenuItemAlternates(item)
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
    }
  }
  
  func add(_ item: HistoryItem) {
    let sortedItems = history.all
    guard let insertionIndex = sortedItems.firstIndex(where: { $0 == item }) else {
      return
    }
    guard let zerothHistoryHeaderItem = topAnchorItem ?? historyHeaderItem else {
      return
    }
    
    let menuItems = buildMenuItemAlternates(item)
    guard let menuItem = menuItems.first else {
      return
    }
    let indexedItem = IndexedItem(
      value: menuItem.value,
      item: item,
      menuItems: menuItems
    )
    indexedItems.insert(indexedItem, at: insertionIndex)
    
    let firstHistoryMenuItemIndex = index(of: zerothHistoryHeaderItem) + 1
    let menuItemInsertionIndex = firstHistoryMenuItemIndex + self.historyMenuItemsGroupCount * insertionIndex

    ensureInEventTrackingModeIfVisible {
      var index = menuItemInsertionIndex
      for menuItem in menuItems {
        self.safeInsertItem(menuItem, at: index)
        index += 1
      }
      
      // i wish there was an explanation why clearRemovedItems should be called here
      self.clearRemovedItems()
    }
  }
  
  func clear() {
    clear(indexedItems)
    clearAllHistoryMenuItems()
    headOfQueueIndexedItem = nil
  }
  
  func updateHeadOfQueue(index: Int?) {
    headOfQueueIndexedItem?.menuItems.forEach { $0.isHeadOfQueue = false }
    
    if let index = index, index >= 0, index < indexedItems.count {
      headOfQueueIndexedItem = indexedItems[index]
      headOfQueueIndexedItem?.menuItems.forEach { $0.isHeadOfQueue = true }
    }
  }
  
  func updateFilter(filter: String) {
    var results = search.search(string: filter, within: indexedItems)
    
    // Strip the results that are longer than visible items.
    if maxMenuItems > 0 && maxMenuItems < results.count {
      results = Array(results[0...maxMenuItems - 1])
    }
    
    // Remove existing menu history items
    guard let zerothHistoryHeaderItem = topAnchorItem ?? historyHeaderItem,
          let trailingSeparatorItem = trailingSeparatorItem else {
      return
    }
    assert(index(of: zerothHistoryHeaderItem) < index(of: trailingSeparatorItem))
    
    for index in (index(of: zerothHistoryHeaderItem) + 1 ..< index(of: trailingSeparatorItem)).reversed() {
      safeRemoveItem(at: index)
    }
    
    // Add back matching ones in search results order... if search is empty should be all original items
    for result in results {
      for menuItem in result.object.menuItems {
        menuItem.highlight(result.titleMatches)
        appendMenuItem(menuItem)
      }
    }
    
    isFiltered = results.count < indexedItems.count
    
    highlight(historyMenuItems.first)
  }
  
  func select() {
    if let item = highlightedItem {
      performActionForItem(at: index(of: item))
    }
  }
  
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
  
  func highlightedMenuItem() -> HistoryMenuItem? {
    guard let menuItem = highlightedItem, let historyMenuItem = menuItem as? HistoryMenuItem else {
      return nil
    }
    let menuIndex = index(of: historyMenuItem)
    
    // When deleting mulitple items by holding the removal keys
    // we sometimes get into a race condition with menu updating indices.
    // https://github.com/p0deje/Maccy/issues/628
    guard menuIndex != -1 else {
      return nil
    }
    
    return historyMenuItem
  }
  
  func delete(position: Int) -> String? {
    guard indexedItems.count > position else {
      return nil
    }
    
    let indexedItem = indexedItems[position]
    let value = indexedItem.value
    
    // check if this menu item is highlighted
    var rehighlightMenuIndex: Int? = nil
    if let historyMenuItem = highlightedItem as? HistoryMenuItem, historyMenuItem.item == indexedItem {
      rehighlightMenuIndex = index(of: historyMenuItem)
    }
    
    // remove menu items, history item, this class's indexing item
    indexedItem.menuItems.forEach(safeRemoveItem)
    history.remove(indexedItem.item)
    indexedItems.remove(at: position)
    
    if indexedItem == headOfQueueIndexedItem {
      headOfQueueIndexedItem = nil
    }
    
    // if deleted item was highlighted, highlight next one in the menu now at the same index
    if let menuIndex = rehighlightMenuIndex {
      highlight(items[menuIndex])
    }
    return value
  }
  
  func deleteHighlightedItem() {
    guard let item = lastHighlightedItem,
          let index = indexedItems.firstIndex(where: { $0.menuItems.contains(item) }) else {
      return
    }
    _ = delete(position: index)
  }
  
  private func enableDelete(forHighlightedItem item: NSMenuItem?) {
    guard let item = item else {
      return
    }
    
    var enable = false
    if let historyMenuItem = item as? HistoryMenuItem {
      enable = canDeleteHistoryMenuItem(historyMenuItem)
    } else {
      enable = false
    }
    deleteItem?.isEnabled = enable
  }
  
  func canDeleteHistoryMenuItem(_ item: HistoryMenuItem) -> Bool {
    // currently all history menu items can be deleted
    return true
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
  
  func performQueueModeToggle() {
    if Maccy.isQueueModeOn {
      guard let queueStopItem = queueStopItem else { return }
      performActionForItem(at: index(of: queueStopItem))
    } else {
      guard let queueStartItem = queueStartItem else { return }
      performActionForItem(at: index(of: queueStartItem))
    }
  }
  
  func enableExpandedMenu(_ enable: Bool, full: Bool = false) {
    showsExpandedMenu = enable // gets set back to false in menuDidClose
    showsFullExpansion = enable && full
  }
  
  // MARK: -
  
  private func insertTopAnchorItem() {
    // need an anchor item above all the history items because they're like fenceposts
    // (see "the fencepost problem") cannot use the saarch header item like Maccy because it can be hidden
    guard let protoAnchorItem = protoAnchorItem, let historyHeaderItem = historyHeaderItem else {
      return
    }
    let anchorItem = protoAnchorItem.copy() as! HistoryMenuItem
    
    let index = index(of: historyHeaderItem) + 1
    insertItem(anchorItem, at: index)
    
    topAnchorItem = anchorItem
  }
  
  private func updateShortcuts() {
    queueCopyItem?.setShortcut(for: .queueCopy)
    queuePasteItem?.setShortcut(for: .queuePaste)
    // might have a start stop hotkey at some point, something like:
    //if !Maccy.queueModeOn {
    //  queueStartItem?.setShortcut(for: .queueStartStop)
    //  queueStopItem?.setShortcut(for: nil)
    //} else {
    //  queueStartItem?.setShortcut(for: nil)
    //  queueStopItem?.setShortcut(for: .queueStartStop)
    //}
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
    // we need to highlight a near-the-top menu item to force menu redrawing
    // (was ...need to highlight the filter menu item)
    // when it has more items that can fit into the screen height
    // and scrolling items are added to the top and bottom of menu
    perform(highlightItemSelector, with: historyMenuItems.first)
    if let item = itemToHighlight, !item.isHighlighted, items.contains(item) {
      perform(highlightItemSelector, with: item)
    } else {
      // Unhighlight current item.
      perform(highlightItemSelector, with: nil)
    }
  }
  
  private func clear(_ itemsToClear: [IndexedItem]) {
    for indexedItem in itemsToClear {
      indexedItem.menuItems.forEach(safeRemoveItem)

      if let removeIndex = indexedItems.firstIndex(of: indexedItem) {
        indexedItems.remove(at: removeIndex)
      }
    }
    
    if let item = headOfQueueIndexedItem, itemsToClear.contains(item) {
      headOfQueueIndexedItem = nil
    }
  }
  
  private func appendMenuItem(_ item: NSMenuItem) {
    guard let historyEndItem = trailingSeparatorItem else { return }
    safeInsertItem(item, at: index(of: historyEndItem))
  }
  
  private func rebuildItemsAsNeeded() {
    let availableHistoryCount = indexedItems.count
    let presentItemsCount = historyMenuItems.count / historyMenuItemsGroupCount
    
    let maxItems = if Maccy.isQueueModeOn { max(maxMenuItems, Maccy.queueSize) } else { maxMenuItems }
    
    if (maxItems <= 0 || maxItems > availableHistoryCount) && presentItemsCount < availableHistoryCount {
      appendItemsUntilLimit(availableHistoryCount)
    } else if presentItemsCount < maxItems {
      appendItemsUntilLimit(maxItems)
    } else if presentItemsCount > maxItems {
      removeItemsOverLimit(maxItems)
    }
  }
  
  private func removeItemsOverLimit(_ limit: Int) {
    var count = historyMenuItems.count / historyMenuItemsGroupCount
    for indexedItem in indexedItems.reversed() {
      if count <= limit {
        return
      }
      
      // if menu doesn't contains this item, skip it
      let menuItems = indexedItem.menuItems.filter({ historyMenuItems.contains($0) })
      if menuItems.isEmpty {
        continue
      }
      
      menuItems.forEach(safeRemoveItem)
      count -= 1
    }
  }
  
  private func appendItemsUntilLimit(_ limit: Int) {
    var count = historyMenuItems.count / historyMenuItemsGroupCount
    for indexedItem in indexedItems {
      if count >= limit {
        return
      }
      
      // if menu contains this item already, skip it
      let menuItems = indexedItem.menuItems.filter({ !historyMenuItems.contains($0) })
      if menuItems.isEmpty {
        continue
      }
      
      menuItems.forEach(appendMenuItem)
      if indexedItem == headOfQueueIndexedItem {
        menuItems.forEach { $0.isHeadOfQueue = true }
      }
      count += 1
    }
  }
  
  private func buildMenuItemAlternates(_ item: HistoryItem) -> [HistoryMenuItem] {
    // (including the preview item) making the HistoryMenuItem subclasses unnecessary,
    guard let protoCopyItem = protoCopyItem, let protoReplayItem = protoReplayItem else {
      return []
    }
    
    var menuItems = [
      (protoCopyItem.copy() as! HistoryMenuItem).configured(withItem: item),
      (protoReplayItem.copy() as! HistoryMenuItem).configured(withItem: item)
    ]
    menuItems.sort(by: { !$0.isAlternate && $1.isAlternate })
    
    if usePopoverAnchors {
      guard let protoAnchorItem = protoAnchorItem else {
        return []
      }
      menuItems.append(protoAnchorItem.copy() as! HistoryMenuItem)
    }
    
    assert(menuItems.count == historyMenuItemsGroupCount)
    
    return menuItems
  }
  
  private func clearRemovedItems() {
    let currentHistoryItems = history.all
    for indexedItem in indexedItems {
      if let historyItem = indexedItem.item, !currentHistoryItems.contains(historyItem) {
        indexedItem.menuItems.forEach(safeRemoveItem)
        
        if let removeIndex = indexedItems.firstIndex(of: indexedItem) {
          indexedItems.remove(at: removeIndex)
        }
        
        if let item = headOfQueueIndexedItem, item == indexedItem {
          headOfQueueIndexedItem = nil
        }
      }
    }
  }
  
  private func clearAllHistoryMenuItems() {
    guard let zerothHistoryHeaderItem = topAnchorItem ?? historyHeaderItem,
          let trailingSeparatorItem = trailingSeparatorItem else {
      return
    }
    assert(index(of: zerothHistoryHeaderItem) < index(of: trailingSeparatorItem))
    
    for index in (index(of: zerothHistoryHeaderItem) + 1 ..< index(of: trailingSeparatorItem)).reversed() {
      safeRemoveItem(at: index)
    }
    assert(historyMenuItems.isEmpty)
  }
  
  private func updateItemVisibility() {
    guard let historyHeaderItem = historyHeaderItem, let trailingSeparatorItem = trailingSeparatorItem else {
      return
    }
    
    // Switch visibility of start vs stop menu item
    queueStartItem?.isHidden = Maccy.isQueueModeOn
    queueStopItem?.isHidden = !Maccy.isQueueModeOn
    
    let gotQueueItems = Maccy.isQueueModeOn && Maccy.queueSize > 0
    advanceItem?.isAlternate = gotQueueItems // as alternate to queueStopItem can be shown, hidden when not alternate
    
    deleteItem?.isHidden = !showsExpandedMenu
    clearItem?.isAlternate = showsExpandedMenu // as alternate to deleteItem can be shown, hidden when not alternate
    
    // Visiblity of the history header and trailing separator
    // (the expanded menu means the search header and all of the history items)
    historyHeaderItem.isHidden = !showsExpandedMenu || UserDefaults.standard.hideSearch
    trailingSeparatorItem.isHidden = !showsExpandedMenu && !gotQueueItems
    
    // Show or hide the desired history items
    let zerothHistoryHeaderItem = topAnchorItem ?? historyHeaderItem
    let firstHistoryMenuItemIndex = index(of: zerothHistoryHeaderItem) + 1
    let endHistoryMenuItemIndex = index(of: trailingSeparatorItem)
    var remainingHistoryMenuItemIndex = firstHistoryMenuItemIndex
    
    // First queue items to always show when not filtering by a search term
    if gotQueueItems && !isFiltered {
      let endQueuedItemIndex = remainingHistoryMenuItemIndex + historyMenuItemsGroupCount * Maccy.queueSize
      
      for index in firstHistoryMenuItemIndex ..< endQueuedItemIndex {
        guard let menuItem = item(at: index) else { break }
        menuItem.isHidden = false
        if !menuItem.keyEquivalentModifierMask.isEmpty { // see the isAlternate comment below
          menuItem.isAlternate = true
        }
      }
      
      remainingHistoryMenuItemIndex = endQueuedItemIndex
    }
    
    // Remaining history items hidden unless showing the expanded menu
    for index in remainingHistoryMenuItemIndex  ..< endHistoryMenuItemIndex {
      guard let menuItem = item(at: index) else { continue }
      menuItem.isHidden = !showsExpandedMenu
      
      // must clear isAlternate for items that have modifiers when not showing expanded menu, otherwise
      // while menu is up holding that modifier will show them even irrespective of isHidden
      if !menuItem.keyEquivalentModifierMask.isEmpty {
        menuItem.isAlternate = showsExpandedMenu
      }
    }
  }
  
  private func safeInsertItem(_ item: NSMenuItem, at index: Int) {
    guard !items.contains(item), index <= items.count else {
      return
    }

    sanityCheckIndexIsHistoryItemIndex(index, forInserting: true)
    
    insertItem(item, at: index)
  }
  
  private func safeRemoveItem(_ item: NSMenuItem) {
    guard items.contains(item) else {
      return
    }
    
    sanityCheckIndexIsHistoryItemIndex(index(of: item))
    
    removeItem(item)
  }
  
  private func safeRemoveItem(at index: Int) {
    guard index <= items.count else {
      return
    }
    
    sanityCheckIndexIsHistoryItemIndex(index)
    
    removeItem(at: index)
  }
  
  private func sanityCheckIndexIsHistoryItemIndex(_ i: Int, forInserting inserting: Bool = false) {
    if item(at: i) != nil, let historyHeaderItem, let trailingSeparatorItem {
      if i <= index(of: topAnchorItem ?? historyHeaderItem) {
        fatalError()
      }
      if i > index(of: trailingSeparatorItem) {
        fatalError()
      }
      if !inserting && i == index(of: trailingSeparatorItem) {
        fatalError()
      }
    }
  }
  
  private func offloadCurrentPreview() {
    previewThrottle.cancel()
    previewPopover?.close()
    previewPopover = nil
  }

  private func boundsOfMenuItem(_ item: NSMenuItem, _ windowContentView: NSView) -> NSRect? {
    if !usePopoverAnchors {
      let windowRectInScreenCoordinates = windowContentView.accessibilityFrame()
      let menuItemRectInScreenCoordinates = item.accessibilityFrame()
      return NSRect(
        origin: NSPoint(
          x: menuItemRectInScreenCoordinates.origin.x - windowRectInScreenCoordinates.origin.x,
          y: menuItemRectInScreenCoordinates.origin.y - windowRectInScreenCoordinates.origin.y),
        size: menuItemRectInScreenCoordinates.size
      )
    } else {
      // assumes the last of a group of history items is the anchor
      guard let topAnchorView = topAnchorItem?.view, let item = item as? HistoryMenuItem,
            let itemIndex = indexedItems.firstIndex(where: { $0.menuItems.contains(item) }) else {
        return nil
      }
      let indexedItem = indexedItems[itemIndex]
      guard let previewView = indexedItem.menuItems.last?.view else {
        return nil
      }
      
      var precedingView = topAnchorView
      for index in (0..<itemIndex).reversed() {
        // Check if anchor for this item is visible (it may be hidden by the search filter)
        if let view = indexedItems[index].menuItems.last?.view, view.window != nil {
          precedingView = view
          break
        }
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
