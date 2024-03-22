import Cocoa
import KeyboardShortcuts
import Settings

#if CLEEPP
typealias Cleepp = Maccy
#endif

// swiftlint:disable type_body_length
class Maccy: NSObject, NSMenuItemValidation {
  static var returnFocusToPreviousApp = true
  static var isQueueModeOn = false
  static var queueSize = 0
  static var busy = false
  
  static var allowExpandedHistory = true
  static var allowFullyExpandedHistory = false
  static var allowHistorySearch = false
  static var allowReplayFromHistory = false
  static var allowPasteMultiple = false
  static var allowUndoCopy = false
  static var allowDictinctStorageSize: Bool { Self.allowFullyExpandedHistory || Self.allowHistorySearch }

  @objc let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
  var selectedItem: HistoryItem? { (menu.highlightedItem as? HistoryMenuItem)?.item }

  private let statusItemTitleMaxLength = 20

  internal let about = About()
  internal let clipboard = Clipboard.shared
  internal let history = History()
  internal var menu: Menu!
  private var menuController: MenuController!

#if CLEEPP
  private let purchases = Purchases.shared
// TODO: enable this once intro added
//  private var intro = IntroWindowController()
  
  internal var queueHeadIndex: Int? {
    if Self.queueSize < 1 {
      nil
    } else {
      Self.queueSize - 1
    }
  }
  internal var permitEmptyQueueMode = false // affects behavior when deleting history items
  internal var iconBlinkTimer: DispatchSourceTimer?

  private var numberQueuedAlert: NSAlert {
    let alert = NSAlert()
    alert.messageText = NSLocalizedString("number_alert_message", comment: "")
    alert.informativeText = NSLocalizedString("number_alert_comment", comment: "")
      .replacingOccurrences(of: "{number}", with: String(Self.queueSize))
    alert.addButton(withTitle: NSLocalizedString("number_alert_confirm", comment: ""))
    alert.addButton(withTitle: NSLocalizedString("number_alert_cancel", comment: ""))
    let field = RangedIntegerTextField(acceptingRange: 1...Self.queueSize, permittingEmpty: true,
                                       frame: NSRect(x: 0, y: 0, width: 200, height: 24)) { valid in
      alert.buttons[0].isEnabled = valid
    }
    field.placeholderString = String(Self.queueSize)
    alert.accessoryView = field
    alert.window.initialFirstResponder = field
    return alert
  }
#endif

  private var clearAlert: NSAlert {
    let alert = NSAlert()
    alert.messageText = NSLocalizedString("clear_alert_message", comment: "")
    alert.informativeText = NSLocalizedString("clear_alert_comment", comment: "")
    alert.addButton(withTitle: NSLocalizedString("clear_alert_confirm", comment: ""))
    alert.addButton(withTitle: NSLocalizedString("clear_alert_cancel", comment: ""))
    alert.showsSuppressionButton = true
    return alert
  }

#if CLEEPP
  // omits the pins panel, app store build gets the purchase panel
  #if FOR_APP_STORE
  internal lazy var settingsWindowController = SettingsWindowController(
    panes: [
      GeneralSettingsViewController(),
      PurchaseSettingsViewController(),
      StorageSettingsViewController(),
      AppearanceSettingsViewController(),
      IgnoreSettingsViewController(),
      AdvancedSettingsViewController()
    ]
  )
  #else
  internal lazy var settingsWindowController = SettingsWindowController(
    panes: [
      GeneralSettingsViewController(),
      StorageSettingsViewController(),
      AppearanceSettingsViewController(),
      IgnoreSettingsViewController(),
      AdvancedSettingsViewController()
    ]
  )
  #endif
#else
  internal lazy var settingsWindowController = SettingsWindowController(
    panes: [
      GeneralSettingsViewController(),
      StorageSettingsViewController(),
      AppearanceSettingsViewController(),
      PinsSettingsViewController(),
      IgnoreSettingsViewController(),
      AdvancedSettingsViewController()
    ]
  )
#endif

  private var clipboardCheckIntervalObserver: NSKeyValueObservation?
  private var enabledPasteboardTypesObserver: NSKeyValueObservation?
  private var ignoreEventsObserver: NSKeyValueObservation?
  private var imageHeightObserver: NSKeyValueObservation?
  private var hideFooterObserver: NSKeyValueObservation?
  private var hideSearchObserver: NSKeyValueObservation?
  private var hideTitleObserver: NSKeyValueObservation?
  private var maxMenuItemLengthObserver: NSKeyValueObservation?
  private var pasteByDefaultObserver: NSKeyValueObservation?
  private var pinToObserver: NSKeyValueObservation?
  private var removeFormattingByDefaultObserver: NSKeyValueObservation?
  private var sortByObserver: NSKeyValueObservation?
  private var showSpecialSymbolsObserver: NSKeyValueObservation?
  private var showRecentCopyInMenuBarObserver: NSKeyValueObservation?
  private var statusItemConfigurationObserver: NSKeyValueObservation?
  private var statusItemVisibilityObserver: NSKeyValueObservation?
  private var statusItemChangeObserver: NSKeyValueObservation?

  override init() {
    UserDefaults.standard.register(defaults: [
      UserDefaults.Keys.clipboardCheckInterval: UserDefaults.Values.clipboardCheckInterval,
      UserDefaults.Keys.imageMaxHeight: UserDefaults.Values.imageMaxHeight,
      UserDefaults.Keys.maxMenuItems: UserDefaults.Values.maxMenuItems,
      UserDefaults.Keys.maxMenuItemLength: UserDefaults.Values.maxMenuItemLength,
      UserDefaults.Keys.previewDelay: UserDefaults.Values.previewDelay,
      UserDefaults.Keys.showInStatusBar: UserDefaults.Values.showInStatusBar,
      UserDefaults.Keys.showSpecialSymbols: UserDefaults.Values.showSpecialSymbols
    ])
    #if CLEEPP
    // cleepp doesn't populate these in its app delegates's migration method,
    // maybe should go in Clipboard.init instead though
    UserDefaults.standard.register(defaults: [
      UserDefaults.Keys.enabledPasteboardTypes: UserDefaults.Values.enabledPasteboardTypes,
      UserDefaults.Keys.ignoredPasteboardTypes: UserDefaults.Values.ignoredPasteboardTypes,
    ])
    #endif

    super.init()
    initializeObservers()

    #if CLEEPP
    purchases.start(withObserver: self) { [weak self] _, update in
      self?.purchasesUpdated(update)
    }
    #endif

    #if !CLEEPP
    disableUnusedGlobalHotkeys()
    #endif

    #if CLEEPP
    menu = CleeppMenu.load(withHistory: history, owner: self) // its not clear why history is not a shared instance
    #else
    menu = Menu(history: history, clipboard: Clipboard.shared)
    #endif

    menuController = MenuController(menu, statusItem)
    start()
  }

  deinit {
    clipboardCheckIntervalObserver?.invalidate()
    enabledPasteboardTypesObserver?.invalidate()
    ignoreEventsObserver?.invalidate()
    hideFooterObserver?.invalidate()
    hideSearchObserver?.invalidate()
    hideTitleObserver?.invalidate()
    maxMenuItemLengthObserver?.invalidate()
    pasteByDefaultObserver?.invalidate()
    pinToObserver?.invalidate()
    removeFormattingByDefaultObserver?.invalidate()
    sortByObserver?.invalidate()
    showRecentCopyInMenuBarObserver?.invalidate()
    showSpecialSymbolsObserver?.invalidate()
    statusItemConfigurationObserver?.invalidate()
    statusItemVisibilityObserver?.invalidate()
    statusItemChangeObserver?.invalidate()
    
    //cancelIconBlinkTimer()
    //purchases.finish()
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
    #if CLEEPP
    clearAll(suppressClearAlert: suppressClearAlert)
    #else
    withClearAlert(suppressClearAlert: suppressClearAlert) {
      self.history.clearUnpinned()
      self.menu.clearUnpinned()
      self.clipboard.clear()
      self.updateMenuTitle()
    }
    #endif
  }

  private func start() {
    statusItem.behavior = .removalAllowed
    #if CLEEPP
    statusItem.isVisible = true
    #else
    statusItem.isVisible = UserDefaults.standard.showInStatusBar
    #endif

    #if CLEEPP
    setupStatusMenuIcon()
    #else
    updateStatusMenuIcon(UserDefaults.standard.menuIcon)
    #endif

    clipboard.onNewCopy(history.add)
    clipboard.onNewCopy(menu.add)
    #if CLEEPP
    clipboard.onNewCopy({ _ in self.incrementQueue() })
    #else
    clipboard.onNewCopy(updateMenuTitle)
    #endif
    clipboard.start()

    #if CLEEPP
    menu.buildItems()
    #else
    populateHeader()
    populateItems()
    populateFooter()
    #endif

    updateStatusItemEnabledness()
    
    #if CLEEPP
    // TODO: enable this once intro added
//    if !UserDefaults.standard.completedIntro {
//      showIntro(self)
//    else if !Accessibility.allowed {
//      showIntroAtPersmissionPage(self)
//    }
    #endif
  }

  func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
    #if CLEEPP
    if Self.busy {
      return false
    } else {
      return menu.validationShouldEnable(item: menuItem)
    }
    #else
    return true
    #endif
  }

#if CLEEPP
  private func purchasesUpdated(_ update: Purchases.ObservationUpdate) {
    setFeatureFlags(givenPurchase: purchases.hasBoughtExtras)
  }
  
  private func setFeatureFlags(givenPurchase hasPurchased: Bool) {
    Self.allowFullyExpandedHistory = hasPurchased
    Self.allowHistorySearch = hasPurchased
    Self.allowReplayFromHistory = hasPurchased
    Self.allowPasteMultiple = hasPurchased
    Self.allowUndoCopy = hasPurchased
  }
  
  // Non-history items in the cleepp menu are defined in a nib file instead of programmatically
  // (the best code is no code), action methods for those items now live in this class, defined
  // in a class extension. Also history menu item subclasses no longer exist, actions for those
  // are also defined in the extension, and other "business logic" for the queueing feature.
#else
  private func populateHeader() {
    let headerItem = NSMenuItem()
    headerItem.title = "Maccy"
    headerItem.view = MenuHeader().view

    menu.addItem(headerItem)
  }

  private func populateItems() {
    menu.buildItems()
    menu.updateUnpinnedItemsVisibility()
    updateMenuTitle()
  }

  private func populateFooter() {
    MenuFooter.allCases.map({ $0.menuItem }).forEach({ item in
      item.action = #selector(menuItemAction)
      item.target = self
      menu.addItem(item)
    })
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
        clearUnpinned()
      case .clearAll:
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
#endif

  private func clearAll(suppressClearAlert: Bool = false) {
    withClearAlert(suppressClearAlert: suppressClearAlert) {
      self.history.clear()
      self.menu.clearAll()
      self.clipboard.clear()
      #if CLEEPP
      Self.queueSize = 0
      self.updateStatusMenuIcon()
      #endif
      self.updateMenuTitle()
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

#if CLEEPP
  internal func withNumberToPasteAlert(_ closure: @escaping (Int) -> Void) {
    let alert = numberQueuedAlert
    guard let field = alert.accessoryView as? RangedIntegerTextField else {
      return
    }
    Self.returnFocusToPreviousApp = false
    DispatchQueue.main.async {
      if alert.runModal() == NSApplication.ModalResponse.alertFirstButtonReturn {
        alert.window.orderOut(nil) // i think withClearAlert above should call this too
        let number = Int(field.stringValue) ?? Self.queueSize
        closure(number)
      }
      Self.returnFocusToPreviousApp = true
    }
  }
#endif

  private func rebuild() {
    menu.clearAll()

    #if CLEEPP
    menu.buildItems()
    if Self.isQueueModeOn {
      menu.updateHeadOfQueue(index: queueHeadIndex)
    }
    #else
    menu.removeAllItems()
    populateHeader()
    populateItems()
    populateFooter()
    #endif
  }

  internal func updateMenuTitle(_ item: HistoryItem? = nil) {
    #if CLEEPP
    if Self.isQueueModeOn {
      statusItem.button?.title = String(Self.queueSize) + "  "
    } else {
      statusItem.button?.title = ""
    }
    #else
    guard UserDefaults.standard.showRecentCopyInMenuBar else {
      statusItem.button?.title = ""
      return
    }

    var title = ""
    if let item = item {
      title = HistoryMenuItem(item: item, clipboard: clipboard).title
    } else if let item = menu.firstUnpinnedHistoryMenuItem {
      title = item.title
    }

    statusItem.button?.title = String(title.prefix(statusItemTitleMaxLength))
    #endif
  }

#if CLEEPP
  // reimplemetned this method in a class extension
#else
  private func updateStatusMenuIcon(_ newIcon: String) {
    guard let button = statusItem.button else {
      return
    }

    switch newIcon {
    case "scissors":
      button.image = NSImage(named: .scissors)
    case "paperclip":
      button.image = NSImage(named: .paperclip)
    case "clipboard":
      button.image = NSImage(named: .clipboard)
    default:
      button.image = NSImage(named: .maccyStatusBar)
    }
    button.imagePosition = .imageRight
    (button.cell as? NSButtonCell)?.highlightsBy = []
  }
#endif

  private func updateStatusItemEnabledness() {
    statusItem.button?.appearsDisabled = UserDefaults.standard.ignoreEvents ||
      UserDefaults.standard.enabledPasteboardTypes.isEmpty
  }

  // swiftlint:disable function_body_length
  private func initializeObservers() {
    clipboardCheckIntervalObserver = UserDefaults.standard.observe(\.clipboardCheckInterval, options: .new) { _, _ in
      self.clipboard.restart()
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
    #if CLEEPP
    statusItemVisibilityObserver = statusItem.observe(\.isVisible, options: .new) { _, change in
      if change.newValue == false {
        NSApp.terminate(nil)
      }
    }
    // might also want to keep showSpecialSymbolsObserver
    #else
    hideFooterObserver = UserDefaults.standard.observe(\.hideFooter, options: .new) { _, _ in
      self.rebuild()
    }
    hideSearchObserver = UserDefaults.standard.observe(\.hideSearch, options: .new) { _, _ in
      self.rebuild()
    }
    hideTitleObserver = UserDefaults.standard.observe(\.hideTitle, options: .new) { _, _ in
      self.rebuild()
    }
    pasteByDefaultObserver = UserDefaults.standard.observe(\.pasteByDefault, options: .new) { _, _ in
      self.rebuild()
    }
    pinToObserver = UserDefaults.standard.observe(\.pinTo, options: .new) { _, _ in
      self.rebuild()
    }
    removeFormattingByDefaultObserver = UserDefaults.standard.observe(\.removeFormattingByDefault,
                                                                      options: .new) { _, _ in
      self.rebuild()
    }
    sortByObserver = UserDefaults.standard.observe(\.sortBy, options: .new) { _, _ in
      self.rebuild()
    }
    showSpecialSymbolsObserver = UserDefaults.standard.observe(\.showSpecialSymbols, options: .new) { _, _ in
      self.menu.regenerateMenuItemTitles()
      CoreDataManager.shared.saveContext()
    }
    showRecentCopyInMenuBarObserver = UserDefaults.standard.observe(\.showRecentCopyInMenuBar,
                                                                    options: .new) { _, _ in
      self.updateMenuTitle()
    }
    statusItemConfigurationObserver = UserDefaults.standard.observe(\.showInStatusBar,
                                                                    options: .new) { _, change in
      if self.statusItem.isVisible != change.newValue! {
        self.statusItem.isVisible = change.newValue!
      }
    }
    statusItemVisibilityObserver = observe(\.statusItem.isVisible, options: .new) { _, change in
      if UserDefaults.standard.showInStatusBar != change.newValue! {
        UserDefaults.standard.showInStatusBar = change.newValue!
      }
    }
    statusItemChangeObserver = UserDefaults.standard.observe(\.menuIcon, options: .new) { _, change in
      self.updateStatusMenuIcon(change.newValue!)
    }
    #endif
  }
  // swiftlint:enable function_body_length

  private func disableUnusedGlobalHotkeys() {
    let names: [KeyboardShortcuts.Name] = [.delete, .pin]
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
