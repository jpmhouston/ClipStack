import Cocoa
import KeyboardShortcuts
import Settings

// swiftlint:disable type_body_length
class Maccy: NSObject {
  static var returnFocusToPreviousApp = true
  
  @objc let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
  var selectedItem: HistoryItem? { (menu.highlightedItem as? HistoryMenuItem)?.item }
  
  private let about = About()
  private let clipboard = Clipboard.shared
  private let history = History()
  private var menu: Menu!
  private var menuController: MenuController!
  
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
//  private var sortByObserver: NSKeyValueObservation? // don't think i need sortBy or the statusItem obsevrers
//  private var statusItemConfigurationObserver: NSKeyValueObservation?
//  private var statusItemVisibilityObserver: NSKeyValueObservation?
  
  override init() {
    UserDefaults.standard.register(defaults: [
      UserDefaults.Keys.imageMaxHeight: UserDefaults.Values.imageMaxHeight,
      UserDefaults.Keys.maxMenuItems: UserDefaults.Values.maxMenuItems,
      UserDefaults.Keys.maxMenuItemLength: UserDefaults.Values.maxMenuItemLength,
      UserDefaults.Keys.previewDelay: UserDefaults.Values.previewDelay
//      UserDefaults.Keys.showInStatusBar: UserDefaults.Values.showInStatusBar // don't think i need showInStatusBar
    ])
    
    super.init()
    initializeObservers()
    disableUnusedGlobalHotkeys()
    
    // TODO: maybe think about what's here in init() vs what is in start(), and if that makes sense
    
    menu = Menu(history: history, clipboard: Clipboard.shared)
    menuController = MenuController(menu, statusItem)
    
    start()
  }
  
  deinit {
    enabledPasteboardTypesObserver?.invalidate()
    ignoreEventsObserver?.invalidate()
    imageHeightObserver?.invalidate()
    maxMenuItemLengthObserver?.invalidate()
//    sortByObserver?.invalidate() // don't think i need sortBy or the statusItem obsevrers
//    statusItemConfigurationObserver?.invalidate()
//    statusItemVisibilityObserver?.invalidate()
  }
  
  func popUp() {
    menuController.popUp()
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
  
  func clearUnpinned(suppressClearAlert: Bool = false) {
    // TODO: maybe rename since none will be pinned? called from app delegate and one other place
    withClearAlert(suppressClearAlert: suppressClearAlert) {
      self.history.clearUnpinned()
      self.menu.clearUnpinned()
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
    clipboard.onNewCopy(updateMenuTitle)
    clipboard.startListening()
    
    populateHeader()
    populateItems()
    populateFooter()
    updateHistoryVisibility()

    updateStatusItemEnabledness()
  }
  
  private func populateHeader() {
    let headerItem = NSMenuItem()
    headerItem.title = "Maccy"
    headerItem.view = MenuHeader().view
    
    menu.addItem(headerItem)
  }
  
  private func populateItems() {
    menu.buildItems()
  }
  
  private func populateFooter() {
    MenuFooter.allCases.map({ $0.menuItem }).forEach({ item in
      item.action = #selector(menuItemAction)
      item.target = self
      menu.addItem(item)
    })
  }
  
  private func updateHistoryVisibility() {
    // TODO: hide history items depending on queue mode
  }
  
  @objc
  private func menuItemAction(_ sender: NSMenuItem) {
    if let tag = MenuFooter(rawValue: sender.tag) {
      switch tag {
      case .about:
        Maccy.returnFocusToPreviousApp = false
        about.openAbout(sender)
        Maccy.returnFocusToPreviousApp = true
      case .clear:
        clearAll()
      case .quit:
        NSApp.terminate(sender)
      case .preferences:
        Maccy.returnFocusToPreviousApp = false
        settingsWindowController.show()
        settingsWindowController.window?.orderFrontRegardless()
        Maccy.returnFocusToPreviousApp = true
      default:
        break
      }
    }
  }
  
  private func clearAll(suppressClearAlert: Bool = false) {
    withClearAlert(suppressClearAlert: suppressClearAlert) {
      self.history.clear()
      self.menu.clearAll()
      self.clipboard.clear()
      // TODO: instead call self.updateMenuTitle() from method turning queue mode on and off
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
    menu.clearAll()
    menu.removeAllItems()
    
    populateHeader()
    populateItems()
    populateFooter()
    updateHistoryVisibility()
  }
  
  private func updateMenuTitle(_ item: HistoryItem? = nil) {
    // TODO: make code here something like
//    guard something_indicating_queue_mode else {
//      statusItem.button?.title = ""
//      return
//    }
//
//    let count = number_of_queued_items
//    
//    statusItem.button?.title = String(count)
    
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
    // TODO: need to init something like queueModeChangeObserver, pasteWueueAdvanceObserver
    
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
    // TODO: remove UserDefaults properties hideFooter hideSearch hideTitle pasteByDefault pinTo removeFormattingByDefault showRecentCopyInMenuBar
    // don't think i need sortBy showInStatusBar, or their observers, or the statusItem.isVisible observer
//    sortByObserver = UserDefaults.standard.observe(\.sortBy, options: .new) { _, _ in
//      self.rebuild()
//    }
//    statusItemConfigurationObserver = UserDefaults.standard.observe(\.showInStatusBar,
//                                                                    options: .new) { _, change in
//      if self.statusItem.isVisible != change.newValue! {
//        self.statusItem.isVisible = change.newValue!
//      }
//    }
//    statusItemVisibilityObserver = observe(\.statusItem.isVisible, options: .new) { _, change in
//      if UserDefaults.standard.showInStatusBar != change.newValue! {
//        UserDefaults.standard.showInStatusBar = change.newValue!
//      }
//    }
  }
  
  private func disableUnusedGlobalHotkeys() {
    // TODO: understand what this does, does the delete hotkey not work?! do our new ones need to be added this?
    // TODO: remove KeyboardShortcuts case pin
    let names: [KeyboardShortcuts.Name] = [.delete]
    names.forEach(KeyboardShortcuts.disable)

    NotificationCenter.default.addObserver(
      forName: Notification.Name("KeyboardShortcuts_shortcutByNameDidChange"),
      object: nil,
      queue: nil
    ) { notification in
      if let name = notification.userInfo?["name"] as? KeyboardShortcuts.Name, names.contains(name) {
        KeyboardShortcuts.disable(name)
      }
    }
  }
}
// swiftlint:enable type_body_length
