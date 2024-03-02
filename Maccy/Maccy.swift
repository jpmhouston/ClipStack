import Cocoa
import KeyboardShortcuts
import Settings
import Symbols

// swiftlint:disable type_body_length
class Maccy: NSObject {
  static var returnFocusToPreviousApp = true
  static var queueModeOn = false
  static var queueSize = 0
  
  static var allowExtraHistoryFeatures = true
  static var allowUndoCopy = true
  
  @objc let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
  var selectedItem: HistoryItem? { (menu.highlightedItem as? HistoryMenuItem)?.item }
  
  private let about = About()
  private let clipboard = Clipboard.shared
  private let history = History()
  private var intro: IntroWindowController!
  private var menuController: MenuController!
  private var menu: StatusItemMenu!
  
  private var queueHeadIndex: Int? {
    if Self.queueSize < 1 {
      nil
    } else {
      Self.queueSize - 1
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
  
  private var enabledPasteboardTypesObserver: NSKeyValueObservation?
  private var ignoreEventsObserver: NSKeyValueObservation?
  private var imageHeightObserver: NSKeyValueObservation?
  private var maxMenuItemLengthObserver: NSKeyValueObservation?
  private var removalObserver: NSKeyValueObservation?
  
  private let accessibilityDesc = NSLocalizedString("menu_accessibility_description", comment: "")
  private let iconBlinkIntervalSeconds: Float = 0.75
  private var iconBlinkTimer: DispatchSourceTimer?
  
  enum QueueChangeDirection {
    case none, increment, decrement
  }
  enum SymbolTransition {
    case replace
    case blink(transitionSymbol: String)
  }
  
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
    
    guard let nibMenu = StatusItemMenu.load(owner: self) else { fatalError("menu object missing") }
    menu = nibMenu
    menu.inject(history: history, clipboard: Clipboard.shared)
    
    menuController = MenuController(menu, statusItem)
    
    guard let nibIntro = IntroWindowController.load(owner: self) else { fatalError("intro object missing") }
    intro = nibIntro
    
    start()
  }
  
  deinit {
    cancelIconBlinkTimer()
    
    enabledPasteboardTypesObserver?.invalidate()
    ignoreEventsObserver?.invalidate()
    imageHeightObserver?.invalidate()
    maxMenuItemLengthObserver?.invalidate()
    removalObserver?.invalidate()
  }
  
  @IBAction
  func startQueueMode(_ sender: AnyObject) {
    Accessibility.check()
    
    Self.queueModeOn = true
    Self.queueSize = 0
    
    updateStatusMenuIcon(.increment)
    updateMenuTitle()
  }
  
  @IBAction
  func queueCopy(_ sender: AnyObject) {
    queueCopy()
  }
  
  func queueCopy() {
    if !Self.queueModeOn {
      Self.queueModeOn = true
    }
    
    // make the frontmost application perform a copy
    // let clipboard object detect this normally and invoke incrementQueue
    clipboard.invokeApplicationCopy()
  }
  
  private func incrementQueue() {
    guard Self.queueModeOn else { return }
    
    //let wasEmpty = Self.queueSize == 0 // TODO: restore my logic to skip reloading pasteboard or updating menu?
    Self.queueSize += 1
    
    updateStatusMenuIcon(.increment)
    updateMenuTitle()
    menu.updateHeadOfQueue(index: queueHeadIndex)
    
    // revert pasteboard back to first item in the queue
    if let index = queueHeadIndex, index < history.count {
      clipboard.copy(history.all[index])
    }
  }
  
  @IBAction
  func queuePaste(_ sender: AnyObject) {
    queuePaste()
  }
  
  func queuePaste() {
    // make the frontmost application perform a paste
    clipboard.invokeApplicationPaste(then: { self.decrementQueue() })
  }
  
  private func decrementQueue() {
    guard Self.queueModeOn && Self.queueSize > 0 else { return }
    
    Self.queueSize -= 1

    if Self.queueSize <= 0 {
      Self.queueModeOn = false
    } else if let index = queueHeadIndex, index < history.count {
      clipboard.copy(history.all[index]) // reset pasteboard to the latest item copied
    }
    
    updateStatusMenuIcon(.decrement)
    updateMenuTitle()
    menu.updateHeadOfQueue(index: queueHeadIndex)
    
    #if FOR_APP_STORE
    if !Self.queueModeOn {
      AppStoreReview.ask()
    }
    #endif
  }
  
  @IBAction
  func cancelQueueMode(_ sender: AnyObject) {
    Self.queueModeOn = false
    Self.queueSize = 0
    
    menu.updateHeadOfQueue(index: nil)
    updateStatusMenuIcon()
    updateMenuTitle()
    
    // in case pasteboard was left set to an item deeper in the queue, reset to the latest item copied
    if let newestItem = history.first {
      clipboard.copy(newestItem)
    }
  }
  
  @IBAction
  func advanceReplay(_ sender: AnyObject) {
    decrementQueue()
  }
  
  @IBAction
  func replayFromHistory(_ sender: AnyObject) {
    guard let item = (sender as? HistoryMenuItem)?.item, let index = history.all.firstIndex(of: item) else { return }
    
    Accessibility.check()
    Self.queueModeOn = true
    Self.queueSize = index + 1
    
    updateStatusMenuIcon(.increment)
    updateMenuTitle()
    menu.updateHeadOfQueue(index: index)
  }
  
  @IBAction
  func copyFromHistory(_ sender: AnyObject) {
    guard let item = (sender as? HistoryMenuItem)?.item else { return }
    
    clipboard.copy(item)
  }
  
  @IBAction
  func undoLastCopy(_ sender: AnyObject) {
    guard let removeItem = history.first else {
      return
    }
    
    history.remove(removeItem)
    _ = menu.delete(position: 0)
    
    if Self.queueModeOn && Self.queueSize > 0 {
      Self.queueSize -= 1
      updateStatusMenuIcon(.decrement)
      updateMenuTitle()
    }
    
    // Normally set pasteboard to the previous history item, now first in the history after doing the
    // delete above. However if have items queued we instead don't want to change the pasteboard at all,
    // it needs to stay set to the front item in the queue.
    if !Self.queueModeOn || Self.queueSize == 0 {
      if let replaceItem = history.first {
        clipboard.copy(replaceItem)
      } else {
        clipboard.copy("")
      }
    }
  }
  
  @IBAction
  func clear(_ sender: AnyObject) {
    clearHistory()
    Self.queueModeOn = false
  }
  
  @IBAction
  func showAbout(_ sender: AnyObject) {
    Self.returnFocusToPreviousApp = false
    about.openAbout()
    Self.returnFocusToPreviousApp = true
  }
  
  @IBAction
  func showIntro(_ sender: AnyObject) {
    Self.returnFocusToPreviousApp = false
    intro.openIntro()
    Self.returnFocusToPreviousApp = true
  }
  
  @IBAction
  func showSettings(_ sender: AnyObject) {
    Self.returnFocusToPreviousApp = false
    settingsWindowController.show()
    settingsWindowController.window?.orderFrontRegardless()
    Self.returnFocusToPreviousApp = true
  }
  
  @IBAction
  func quit(_ sender: AnyObject) {
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
      self.updateStatusMenuIcon()
      self.updateMenuTitle()
    }
  }
  
  private func start() {
    statusItem.behavior = .removalAllowed
    statusItem.isVisible = true // UserDefaults.standard.showInStatusBar // don't think i need UserDefaults property showInStatusBar
    
    setupStatusMenuIcon()
    
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
      Self.returnFocusToPreviousApp = false
      let alert = clearAlert
      DispatchQueue.main.async {
        if alert.runModal() == NSApplication.ModalResponse.alertFirstButtonReturn {
          if alert.suppressionButton?.state == .on {
            UserDefaults.standard.suppressClearAlert = true
          }
          closure()
        }
        Self.returnFocusToPreviousApp = true
      }
    }
  }
  
  private func rebuild() {
    // TODO: don't think i need this
    menu.clear()
    menu.removeAllItems()
    menu.buildItems()
    if Self.queueModeOn {
      menu.updateHeadOfQueue(index: queueHeadIndex)
    }
  }
  
  // TODO: perhaps move title logic into its own obj
  
  private func updateMenuTitle() {
    if Self.queueModeOn {
      statusItem.button?.title = String(Self.queueSize) + "  "
    } else {
      statusItem.button?.title = ""
    }
    
    // TODO: remove UserDefaults property showRecentCopyInMenuBar
  }
  
  @available(macOS 11.0, *)
  private func getSymbolImage(named name: String) -> NSImage? {
    var image = NSImage(systemSymbolName: name, accessibilityDescription: accessibilityDesc)
    if image == nil {
      image = NSImage(named: name)
      image?.accessibilityDescription = accessibilityDesc
    }
    return image?.withSymbolConfiguration(NSImage.SymbolConfiguration(textStyle: .body, scale: .large))
  }
  
  @available(macOS 13.0, *)
  private func exerciseAllSymbolIcons() {
    let symbolNames = ["clipboard.fill", "clipboard.fill", "list.clipboard.fill", "custom.list.clipboard.fill.badge.plus", "custom.list.clipboard.fill.badge.minus", "clipboard"]
    func showSymbol(_ index: Int) {
      guard index < symbolNames.count else {
        //runOnIconBlinkTimer { showSymbol(0) } // to loop endlessly
        return
      }
      let symbolImage = getSymbolImage(named: symbolNames[index])
      if symbolImage != nil {
        print("✅ " + symbolNames[index])
      } else {
        print("❌ " + symbolNames[index])
      }
      statusItem.button?.image = symbolImage
      runOnIconBlinkTimer {
        showSymbol(index + 1)
      }
    }
    showSymbol(0)
  }
  
  private func setupStatusMenuIcon() {
    // the system clipboard symbol requires SF Symbols 4 in macOS 13 Ventura
    var symbolImage: NSImage?
    if #available(macOS 13.0, *) {
      symbolImage = getSymbolImage(named: "clipboard")
      
      #if USE_SYMBOL_EFFECTS
      // aborted idea b/c view is deprecated, and anyhow it doesn't work without subclassing the imageview to handle mouse events & more
      if let symbolImage = symbolImage {
        statusItem.view = NSImageView(image: image)
        return
      }
      #endif
    }
    
    guard let button = statusItem.button else {
      return
    }
    
    button.image = symbolImage ?? NSImage(named: .clipboard)
    button.imagePosition = .imageRight
    (button.cell as? NSButtonCell)?.highlightsBy = []
    
    //if #available(macOS 13.0, *) {
    //  exerciseAllSymbolIcons()
    //}
  }
  
  private func updateStatusMenuIcon(_ direction: QueueChangeDirection = .none) {
    // the system clipboard symbol requires SF Symbols 4 in macOS 13 Ventura
    guard #available(macOS 13.0, *) else {
      return
    }
    
    let symbol: String
    var transition = SymbolTransition.replace
    if !Self.queueModeOn {
      symbol = "clipboard"
      if direction == .decrement {
        transition = .blink(transitionSymbol: "custom.list.clipboard.fill.badge.minus")
      }
    } else if Self.queueSize <= 0 {
      symbol = "clipboard.fill"
      if direction == .decrement {
        transition = .blink(transitionSymbol: "custom.list.clipboard.fill.badge.minus")
      }
    } else {
      symbol = "list.clipboard.fill"
      if direction == .increment {
        transition = .blink(transitionSymbol: "custom.list.clipboard.fill.badge.plus")
      } else if direction == .decrement {
        transition = .blink(transitionSymbol: "custom.list.clipboard.fill.badge.minus")
      }
    }
    
    guard let symbolImage = getSymbolImage(named: symbol) else {
      return
    }
    
    #if USE_SYMBOL_EFFECTS
    // aborted idea b/c view is deprecated, and anyhow it doesn't work without subclassing the imageview to handle mouse events & more
    guard let titleView = statusItem.view as? NSImageView else {
      return
    }
    
    // effects on symbols requires macOS 14 Sonoma
    if #available(macOS 14.0, *) {
      func transitionToSymbolImage() {
        switch direction {
        case .increment:
          titleView.setSymbolImage(symbolImage, contentTransition: .replace.upUp)
        case .decrement:
          titleView.setSymbolImage(symbolImage, contentTransition: .replace.downUp)
        default:
          titleView.image = symbolImage
        }
      }
      if case .blink(let transitionSymbol) = transition, let transitionImage = getSymbolImage(named: transitionSymbol) {
        // bounce into transition symbol then later switch to
        titleView.image = transitionImage
        titleView.addSymbolEffect(.bounce)
        runOnIconBlinkTimer {
          transitionToSymbolImage()
        }
      } else {
        transitionToSymbolImage()
      }
    } else {
      titleView.image = symbolImage
    }
    return
    #endif
    
    if case .blink(let transitionSymbol) = transition, let transitionImage = getSymbolImage(named: transitionSymbol) {
      // first show transition symbol, then blink to the final symbol
      statusItem.button?.image = transitionImage
      runOnIconBlinkTimer {
        self.statusItem.button?.image = symbolImage
      }
    } else {
      statusItem.button?.image = symbolImage
    }
  }
  
  private func runOnIconBlinkTimer(_ action: @escaping () -> Void) {
    if iconBlinkTimer != nil { cancelIconBlinkTimer() }
    iconBlinkTimer = timerForRunningOnMainQueueAfterDelay(iconBlinkIntervalSeconds) { [weak self] in
      guard let self = self else { return }
      self.iconBlinkTimer = nil // doing this before calling closure supports closure itself calling runOnIconBlinkTimer, fwiw
      action()
    }
  }
  
  private func cancelIconBlinkTimer() {
    iconBlinkTimer?.cancel()
    iconBlinkTimer = nil
  }
  
  private func timerForRunningOnMainQueueAfterDelay(_ seconds: Float, _ action: @escaping () -> Void) -> DispatchSourceTimer {
    let timer = DispatchSource.makeTimerSource()
    timer.schedule(wallDeadline: .now() + .milliseconds(Int(seconds * 1000)))
    timer.setEventHandler {
      DispatchQueue.main.async {
        action()
      }
    }
    timer.resume()
    return timer
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
