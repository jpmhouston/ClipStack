import Cocoa
import KeyboardShortcuts
import Settings

// swiftlint:disable type_body_length
class Maccy: NSObject {
  static var returnFocusToPreviousApp = true
  static var queueModeOn = false
  static var queueSize = 0
  
  static var allowExpandedMenu = true
  static var allowUndoCopy = true
  
  @objc let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
  var selectedItem: HistoryItem? { (menu.highlightedItem as? HistoryMenuItem)?.item }
  
  private let about = About()
  private let clipboard = Clipboard.shared
  private let history = History()
  private var menuController: MenuController!
  private var menu: StatusItemMenu!
  
  private var queueHeadIndex: Int? {
    if Maccy.queueSize < 1 {
      nil
    } else {
      Maccy.queueSize - 1
    }
  }
  
  private var clearAlert: NSAlert {
    let alert = NSAlert()
    alert.messageText = NSLocalizedString("clear_alert_message", comment: "")
    alert.informativeText = NSLocalizedString("clear_alert_comment", comment: "")
    alert.addButton(withTitle: NSLocalizedString("clear_alert_confirm", comment: ""))
    alert.addButton(withTitle: NSLocalizedString("clear_alert_cancel", comment: ""))
    alert.showsSuppressionButton = true
    return alert
  }
  
  private lazy var settingsWindowController = SettingsWindowController(
    panes: [
      GeneralSettingsViewController(),
      StorageSettingsViewController(),
      AppearanceSettingsViewController(),
      IgnoreSettingsViewController(),
      AdvancedSettingsViewController()
    ]
  )
  
  // TODO: need new properties that are something like queueModeChangeObserver, pasteWueueAdvanceObserver
  private var enabledPasteboardTypesObserver: NSKeyValueObservation?
  private var ignoreEventsObserver: NSKeyValueObservation?
  private var imageHeightObserver: NSKeyValueObservation?
  private var maxMenuItemLengthObserver: NSKeyValueObservation?
  private var removalObserver: NSKeyValueObservation?
//  private var sortByObserver: NSKeyValueObservation? // don't think i need sortBy or the statusItem obsevrers
//  private var statusItemConfigurationObserver: NSKeyValueObservation?
  
  override init() {
    UserDefaults.standard.register(defaults: [
      UserDefaults.Keys.enabledPasteboardTypes: UserDefaults.Values.enabledPasteboardTypes,
      UserDefaults.Keys.ignoredPasteboardTypes: UserDefaults.Values.ignoredPasteboardTypes,
      UserDefaults.Keys.imageMaxHeight: UserDefaults.Values.imageMaxHeight,
      UserDefaults.Keys.maxMenuItems: UserDefaults.Values.maxMenuItems,
      UserDefaults.Keys.maxMenuItemLength: UserDefaults.Values.maxMenuItemLength,
      UserDefaults.Keys.previewDelay: UserDefaults.Values.previewDelay
    ])
    
    super.init()
    initializeObservers()
    
    guard let nib = NSNib(nibNamed: "Menu", bundle: nil) else { fatalError("menu nib file missing") }
    var nibObjects: NSArray? = NSArray()
    nib.instantiate(withOwner: self, topLevelObjects: &nibObjects)
    guard let nibMenu = nibObjects?.compactMap({ $0 as? StatusItemMenu }).first else { fatalError("menu object missing") }
    
    menu = nibMenu
    menu.inject(history: history, clipboard: Clipboard.shared)
    
    menuController = MenuController(menu, statusItem)
    
    start()
  }
  
  deinit {
    enabledPasteboardTypesObserver?.invalidate()
    ignoreEventsObserver?.invalidate()
    imageHeightObserver?.invalidate()
    maxMenuItemLengthObserver?.invalidate()
    removalObserver?.invalidate()
//    sortByObserver?.invalidate() // don't think i need sortBy or the statusItem obsevrers
//    statusItemConfigurationObserver?.invalidate()
  }
  
  @IBAction
  func queueCopy(_ sender: NSMenuItem) {
    queueCopy()
  }
  
  func queueCopy() {
    if !Maccy.queueModeOn {
      Maccy.queueModeOn = true
    }
    
    // make the frontmost application perform a copy
    // let clipboard object detect this normally and invoke incrementQueue
    clipboard.invokeApplicationCopy()
  }
  
  private func incrementQueue() {
    guard Maccy.queueModeOn else { return }
    
    //let wasEmpty = Maccy.queueSize == 0 // TODO: again use this to skip reloading pasteboard or updating menu?
    Maccy.queueSize += 1
    
    updateMenuTitle()
    menu.updateHeadOfQueue(index: queueHeadIndex)
    
    // revert pasteboard back to first item in the queue
    if let index = queueHeadIndex, index < history.count {
      clipboard.copy(history.all[index])
    }
  }
  
  @IBAction
  func queuePaste(_ sender: NSMenuItem) {
    queuePaste()
  }
  
  func queuePaste() {
    // make the frontmost application perform a paste
    clipboard.invokeApplicationPaste(then: { self.decrementQueue() })
  }
  
  private func decrementQueue() {
    guard Maccy.queueModeOn && Maccy.queueSize > 0 else { return }
    
    Maccy.queueSize -= 1

    if Maccy.queueSize <= 0 {
      Maccy.queueModeOn = false
    } else if let index = queueHeadIndex, index < history.count {
      clipboard.copy(history.all[index]) // reset pasteboard to the latest item copied
    }
    
    updateStatusMenuIcon()
    updateMenuTitle()
    menu.updateHeadOfQueue(index: queueHeadIndex)
  }
  
  @IBAction
  func startQueueMode(_ sender: NSMenuItem) {
    Accessibility.check()
    
    Maccy.queueModeOn = true
    Maccy.queueSize = 0
    
    updateStatusMenuIcon()
    updateMenuTitle()
  }
  
  @IBAction
  func cancelQueueMode(_ sender: NSMenuItem) {
    Maccy.queueModeOn = false
    Maccy.queueSize = 0
    
    menu.updateHeadOfQueue(index: nil)
    updateStatusMenuIcon()
    updateMenuTitle()
    
    // in case pasteboard was left set to an item deeper in the queue, reset to the latest item copied
    if let newestItem = history.first {
      clipboard.copy(newestItem)
    }
  }
  
  @IBAction
  func advanceReplay(_ sender: NSMenuItem) {
    decrementQueue()
  }
  
  @IBAction
  func replayFromHistory(_ sender: NSMenuItem) {
    guard let item = (sender as? HistoryMenuItem)?.item, let index = history.all.firstIndex(of: item) else { return }
    
    Accessibility.check()
    Maccy.queueModeOn = true
    Maccy.queueSize = index + 1
    
    updateStatusMenuIcon()
    updateMenuTitle()
    menu.updateHeadOfQueue(index: index)
  }
  
  @IBAction
  func copyFromHistory(_ sender: NSMenuItem) {
    guard let item = (sender as? HistoryMenuItem)?.item else { return }
    
    clipboard.copy(item)
  }
  
  @IBAction
  func undoLastCopy(_ sender: NSMenuItem) {
    guard let removeItem = history.first else {
      return
    }
    
    history.remove(removeItem)
    _ = menu.delete(position: 0)
    
    if Maccy.queueModeOn && Maccy.queueSize > 0 {
      Maccy.queueSize -= 1
      updateMenuTitle()
    }
    
    // set pasteboard to the previous history item, now first in the history after doing the remove above
    // though if have items queued we don't want to change the pasteboard, it needs to stay the Head item in the queue
    if !Maccy.queueModeOn || Maccy.queueSize == 0 {
    // Normally set pasteboard to the previous history item, now first in the history after doing the
    // delete above. However if have items queued we instead don't want to change the pasteboard at all,
    // it needs to stay set to the front item in the queue.
      if let replaceItem = history.first {
        clipboard.copy(replaceItem)
      } else {
        clipboard.copy("")
      }
    }
  }
  
  @IBAction
  func clear(_ sender: NSMenuItem) {
    clearHistory()
    Maccy.queueModeOn = false
  }
  
  @IBAction
  func showAbout(_ sender: NSMenuItem) {
    Maccy.returnFocusToPreviousApp = false
    about.openAbout(sender)
    Maccy.returnFocusToPreviousApp = true
  }
  
  @IBAction
  func showSettings(_ sender: NSMenuItem) {
    Maccy.returnFocusToPreviousApp = false
    settingsWindowController.show()
    settingsWindowController.window?.orderFrontRegardless()
    Maccy.returnFocusToPreviousApp = true
  }
  
  @IBAction
  func quit(_ sender: NSMenuItem) {
    NSApp.terminate(sender)
  }
  
  func select(position: Int) -> String? {
    return menu.select(position: position)
  }
  
  func delete(position: Int) -> String? {
    return menu.delete(position: position)
  }
  
  func item(at position: Int) -> HistoryItem? {
    return menu.historyItem(at: position)
  }
  
  func clearHistory(suppressClearAlert: Bool = false) {
    withClearAlert(suppressClearAlert: suppressClearAlert) {
      self.history.clear()
      self.menu.clear()
      self.clipboard.clear()
      self.updateMenuTitle()
    }
  }
  
  private func start() {
    statusItem.behavior = .removalAllowed
    statusItem.isVisible = true // UserDefaults.standard.showInStatusBar // don't think i need UserDefaults property showInStatusBar
    
    updateStatusMenuIcon()
    
    clipboard.onNewCopy(history.add)
    clipboard.onNewCopy(menu.add)
    clipboard.onNewCopy({ _ in self.incrementQueue() })
    clipboard.startListening()
    
    populateMenu()

    updateStatusItemEnabledness()
  }
  
  private func populateMenu() {
    menu.buildItems()
  }
  
  private func withClearAlert(suppressClearAlert: Bool, _ closure: @escaping () -> Void) {
    if suppressClearAlert || UserDefaults.standard.suppressClearAlert {
      closure()
    } else {
      Maccy.returnFocusToPreviousApp = false
      let alert = clearAlert
      DispatchQueue.main.async {
        if alert.runModal() == NSApplication.ModalResponse.alertFirstButtonReturn {
          if alert.suppressionButton?.state == .on {
            UserDefaults.standard.suppressClearAlert = true
          }
          closure()
        }
        Maccy.returnFocusToPreviousApp = true
      }
    }
  }
  
  private func rebuild() {
    // TODO: don't think i need this
    menu.clear()
    menu.removeAllItems()
    menu.buildItems()
    if Maccy.queueModeOn {
      menu.updateHeadOfQueue(index: queueHeadIndex)
    }
  }
  
  private func updateMenuTitle() {
    if Maccy.queueModeOn {
      statusItem.button?.title = String(Maccy.queueSize)
    } else {
      statusItem.button?.title = ""
    }
    
    // TODO: remove UserDefaults property showRecentCopyInMenuBar
  }
  
  private func updateStatusMenuIcon() {
    // TODO: add something for changing icon based on queue mode
//    if Maccy.queueModeOn {
//    } else {
//    }
    
    guard let button = statusItem.button else {
      return
    }
    
    button.image = NSImage(named: .clipboard)
    button.imagePosition = .imageRight
    (button.cell as? NSButtonCell)?.highlightsBy = []
  }
  
  private func updateStatusItemEnabledness() {
    statusItem.button?.appearsDisabled = UserDefaults.standard.ignoreEvents ||
      UserDefaults.standard.enabledPasteboardTypes.isEmpty
  }
  
  private func initializeObservers() {
    removalObserver = statusItem.observe(\.isVisible, options: .new) { _, change in
      if change.newValue == false {
        NSApp.terminate(nil)
      }
    }
    
    enabledPasteboardTypesObserver = UserDefaults.standard.observe(\.enabledPasteboardTypes, options: .new) { _, _ in
      self.updateStatusItemEnabledness()
    }
    ignoreEventsObserver = UserDefaults.standard.observe(\.ignoreEvents, options: .new) { _, _ in
      self.updateStatusItemEnabledness()
    }
    imageHeightObserver = UserDefaults.standard.observe(\.imageMaxHeight, options: .new) { _, _ in
      self.menu.resizeImageMenuItems()
    }
    maxMenuItemLengthObserver = UserDefaults.standard.observe(\.maxMenuItemLength, options: .new) { _, _ in
      self.menu.regenerateMenuItemTitles()
      CoreDataManager.shared.saveContext()
    }
  }
  
}
// swiftlint:enable type_body_length
