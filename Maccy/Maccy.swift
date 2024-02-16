import Cocoa
import KeyboardShortcuts
import Settings

// swiftlint:disable type_body_length
class Maccy: NSObject {
  static var returnFocusToPreviousApp = true
  static var queueSize: Int? = nil
  static var queueModeOn: Bool {
    get { queueSize != nil }
    set { if newValue && queueSize == nil { queueSize = 0 } else if !newValue { queueSize = nil } }
  }

  static var allowExpandedMenu = true
  static var allowSomethingElse = true
  
  @objc let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
  var selectedItem: HistoryItem? { (menu.highlightedItem as? HistoryMenuItem)?.item }
  
  private let about = About()
  private let clipboard = Clipboard.shared
  private let history = History()
  private var menuController: MenuController!
  private var menu: StatusItemMenu!

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
    
    guard let nib = NSNib(nibNamed: "StatusItemMenu", bundle: nil) else { fatalError("menu nib file missing") }
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

  func queueCopy() {
    if !Maccy.queueModeOn {
      Maccy.queueModeOn = true
    }
    
    // TODO: make the frontmost application perform a copy, let onNewCopy find this normally to do the rest
  }
  
  func queuePaste() {
    // TODO: make the frontmost application perform a paste
    
    // Advance queue
    if Maccy.queueModeOn, let priorQueueSize = Maccy.queueSize {
      if priorQueueSize > 1 {
        Maccy.queueSize = priorQueueSize - 1
      } else {
        Maccy.queueModeOn = false
        updateStatusMenuIcon()
        updateMenuTitle()
      }
      menu.updateFrontOfQueue()
    }
  }
  
  func undoLastCopy() {
    // TODO: fill this in
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
    clipboard.onNewCopy(incremenentQueue)
    clipboard.startListening()
    
    populateMenu()

    updateStatusItemEnabledness()
  }
  
  private func populateMenu() {
    menu.buildItems()
  }
  
  @IBAction
  private func menuItemAction(_ sender: NSMenuItem) {
    if let tag = StatusItemMenu.Item(rawValue: sender.tag) {
      switch tag {
      case .queueStart:
        Maccy.queueModeOn = true
        updateStatusMenuIcon()
        updateMenuTitle()
      case .queueStop:
        Maccy.queueModeOn = false
        menu.updateFrontOfQueue()
        updateStatusMenuIcon()
        updateMenuTitle()
      case .queueCopy:
        queueCopy()
      case .queuePaste:
        queuePaste()
      case .undoLastCopy:
        undoLastCopy()
      case .about:
        Maccy.returnFocusToPreviousApp = false
        about.openAbout(sender)
        Maccy.returnFocusToPreviousApp = true
      case .clear:
        Maccy.queueModeOn = false
        clearHistory()
      case .quit:
        NSApp.terminate(sender)
      case .preferences:
        Maccy.returnFocusToPreviousApp = false
        settingsWindowController.show()
        settingsWindowController.window?.orderFrontRegardless()
        Maccy.returnFocusToPreviousApp = true
      }
    }
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
    
    populateMenu()
  }
  
  private func incremenentQueue(_ item: HistoryItem? = nil) {
    if let priorQueueSize = Maccy.queueSize {
      Maccy.queueSize = priorQueueSize + 1
      if priorQueueSize == 0 {
        menu.updateFrontOfQueue()
      }
      updateMenuTitle()
    }
  }
  
  private func updateMenuTitle() {
    if Maccy.queueModeOn {
      statusItem.button?.title = String(Maccy.queueSize ?? 0)
    } else {
      statusItem.button?.title = ""
    }
    
    // TODO: remove UserDefaults property showRecentCopyInMenuBar
  }
  
  private func updateStatusMenuIcon() {
    // TODO: add something for changing icon based on queue mode
    
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
