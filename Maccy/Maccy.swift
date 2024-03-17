import Cocoa
import KeyboardShortcuts
import Settings
import Symbols

// swiftlint:disable type_body_length
class Maccy: NSObject, NSMenuItemValidation {
  static var returnFocusToPreviousApp = true
  static var isQueueModeOn = false
  static var queueSize = 0
  static var busy = false
  
  static var allowExpandedHistory = true
  static var allowFullyExpandedHistory = true
  static var allowHistorySearch = true
  static var allowReplayFromHistory = true
  static var allowPasteMultiple = true
  static var allowUndoCopy = true
  static var allowDictinctStorageSize: Bool { Self.allowFullyExpandedHistory || Self.allowHistorySearch }
  
  @objc let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
  var selectedItem: HistoryItem? { (menu.highlightedItem as? HistoryMenuItem)?.item }
  
  private let about = About()
  private let clipboard = Clipboard.shared
  private let purchases = Purchases.shared
  private let history = History()
  private var intro = IntroWindowController()
  private var menuController: MenuController!
  private var menu: StatusItemMenu!
  
  private var queueHeadIndex: Int? {
    if Self.queueSize < 1 {
      nil
    } else {
      Self.queueSize - 1
    }
  }
  private var permitEmptyQueueMode = false // affects behavior when deleting history items
  
  private var clearAlert: NSAlert {
    let alert = NSAlert()
    alert.messageText = NSLocalizedString("clear_alert_message", comment: "")
    alert.informativeText = NSLocalizedString("clear_alert_comment", comment: "")
    alert.addButton(withTitle: NSLocalizedString("clear_alert_confirm", comment: ""))
    alert.addButton(withTitle: NSLocalizedString("clear_alert_cancel", comment: ""))
    alert.showsSuppressionButton = true
    return alert
  }
  
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

  private lazy var settingsWindowController = SettingsWindowController(
    panes: [
      GeneralSettingsViewController(),
      //#if FOR_APP_STORE // TODO: uncomment this to restore conditional
      PurchaseSettingsViewController(),
      //#endif
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
  
  private let pasteMultipleDelaySeconds: Float = 0.333
  private var pasteMultipleDelay: DispatchTimeInterval { .milliseconds(Int(pasteMultipleDelaySeconds * 1000)) }
  private let iconBlinkIntervalSeconds: Float = 0.75
  private var iconBlinkTimer: DispatchSourceTimer?
  
  enum QueueChangeDirection {
    case none, increment, decrement
  }
  enum SymbolTransition {
    case replace
    case blink(transitionIcon: NSImage.Name)
  }
  
  // MARK: -
  
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
    
    purchases.start(withObserver: self) { [weak self] s, update in
      guard let self = self, self == s else {
        return
      }
      purchasesUpdated(update)
    }
    
    guard let nibMenu = StatusItemMenu.load(owner: self) else { fatalError("menu object missing") }
    menu = nibMenu
    menu.inject(history: history)
    
    menuController = MenuController(menu, statusItem)
    
    start()
  }
  
  deinit {
    cancelIconBlinkTimer()
    
    enabledPasteboardTypesObserver?.invalidate()
    ignoreEventsObserver?.invalidate()
    imageHeightObserver?.invalidate()
    maxMenuItemLengthObserver?.invalidate()
    removalObserver?.invalidate()
    
    purchases.finish()
  }
  
  func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
    if Self.busy {
      return false
    } else {
      return menu.validationShouldEnable(item: menuItem)
    }
  }
  
  // MARK: -
  
  @IBAction
  func startQueueMode(_ sender: AnyObject) {
    menu.cancelTrackingWithoutAnimation() // do this before any alerts appear
    guard Accessibility.check() else {
      return
    }
    
    Self.isQueueModeOn = true
    Self.queueSize = 0
    permitEmptyQueueMode = true
    
    updateStatusMenuIcon()
    updateMenuTitle()
  }
  
  @IBAction
  func queuedCopy(_ sender: AnyObject) {
    queuedCopy()
  }
  
  func queuedCopy() {
    if !Self.isQueueModeOn {
      Self.isQueueModeOn = true
      permitEmptyQueueMode = false
    }
    
    Self.busy = true
    
    // make the frontmost application perform a copy
    // let clipboard object detect this normally and invoke incrementQueue
    clipboard.invokeApplicationCopy() {
      Self.busy = false
    }
  }
  
  private func incrementQueue() {
    guard Self.isQueueModeOn else {
      return
    }
    
    Self.queueSize += 1
    
    updateStatusMenuIcon(.increment)
    updateMenuTitle()
    menu.updateHeadOfQueue(index: queueHeadIndex)
    
    // revert pasteboard back to first item in the queue (don't have to when queueSize is now 1)
    if let index = queueHeadIndex, index > 0 && index < history.count {
      clipboard.copy(history.all[index])
    }
  }
  
  @IBAction
  func queuedPaste(_ sender: AnyObject) {
    queuedPaste()
  }
  
  func queuedPaste() {
    Self.busy = true
    
    // make the frontmost application perform a paste
    clipboard.invokeApplicationPaste() {
      self.decrementQueue()
      
      Self.busy = false
    }
  }
  
  private func decrementQueue(withIconUpdates updateIcon: Bool = true) {
    guard Self.isQueueModeOn && Self.queueSize > 0 else {
      return
    }
    
    Self.queueSize -= 1

    if Self.queueSize <= 0 {
      Self.isQueueModeOn = false
    } else if let index = queueHeadIndex, index < history.count {
      clipboard.copy(history.all[index]) // reset pasteboard to the latest item copied
    }
    
    if updateIcon {
      updateStatusMenuIcon(.decrement)
    }
    updateMenuTitle()
    menu.updateHeadOfQueue(index: queueHeadIndex)
    
    #if FOR_APP_STORE
    if !Self.isQueueModeOn {
      AppStoreReview.ask()
    }
    #endif
  }
  
  @IBAction
  func queuedPasteMultiple(_ sender: AnyObject) {
    menu.cancelTrackingWithoutAnimation() // do this before any alerts appear
    withNumberToPasteAlert() { number in
      // Tricky! See MenuController for how `withFocus` normally uses NSApp.hide
      // after making the menu open, except when returnFocusToPreviousApp false.
      // `withNumberToPasteAlert` must set that flag to false to run the alert
      // and so at this moment our app has not been hidden.
      // `invokeApplicationPaste` internally does a dispatch async around
      // controlling the frontmost app so it does so only after the `withFocus`
      // closure does NSApp.hide as it exits.
      // Because this runs after withFocus has already exited without doing
      // NSApp.hide (since withNumberToPasteAlert sets returnFocusToPreviousApp
      // to false), and we want to immediately control the app now, must do the
      // NSApp.hide ourselves here.
      NSApp.hide(self)
      
      self.queuedPasteMultiple(number)
    }
  }
  
  @IBAction
  func queuedPasteAll(_ sender: AnyObject) {
    queuedPasteMultiple(Self.queueSize)
  }
  
  private func queuedPasteMultiple(_ count: Int) {
    guard count >= 1 && count <= Self.queueSize else {
      return
    }
    if count == 1 {
      queuedPaste()
    } else {
      Self.busy = true
      
      setStatusMenuIcon(to: .cleepMenuIconListMinus)
      queuedPasteMultipleIteration(count)
    }
  }
  
  private func queuedPasteMultipleIteration(_ count: Int) {
    // make the frontmost application perform a paste again & again until count decrements to 0
    if count > 0 {
      clipboard.invokeApplicationPaste() {
        self.decrementQueue(withIconUpdates: false)
        DispatchQueue.main.asyncAfter(deadline: .now() + self.pasteMultipleDelay) {
          self.queuedPasteMultipleIteration(count - 1)
        }
      }
    } else {
      updateStatusMenuIcon()
      
      Self.busy = false
    }
  }
  
  func copy(string: String, excludedFromHistory: Bool) {
    clipboard.copy(string, excludeFromHistory: excludedFromHistory)
  }
  
  @IBAction
  func cancelQueueMode(_ sender: AnyObject) {
    Self.isQueueModeOn = false
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
    menu.cancelTrackingWithoutAnimation() // do this before any alerts appear
    guard Accessibility.check() else {
      return
    }
    
    guard let item = (sender as? HistoryMenuItem)?.item, let index = history.all.firstIndex(of: item) else {
      return
    }
    
    Self.isQueueModeOn = true
    Self.queueSize = index + 1
    permitEmptyQueueMode = false
    
    updateStatusMenuIcon()
    updateMenuTitle()
    menu.updateHeadOfQueue(index: index)
  }
  
  @IBAction
  func copyFromHistory(_ sender: AnyObject) {
    guard let item = (sender as? HistoryMenuItem)?.item else {
      return
    }
    
    clipboard.copy(item)
  }
  
  @IBAction
  func deleteHistoryItem(_ sender: AnyObject) {
    guard let item = (sender as? HistoryMenuItem)?.item, let index = history.all.firstIndex(of: item) else {
      return
    }
    
    menu.delete(position: index)
    
    if Self.isQueueModeOn, let headIndex = queueHeadIndex, index <= headIndex {
      Self.queueSize -= 1
      if !permitEmptyQueueMode && Self.queueSize == 0 {
        Self.isQueueModeOn = false
      }
      
      updateStatusMenuIcon(.decrement)
      updateMenuTitle()
      // menu updates the head of queue item itself when deleting
    }
  }
  
  @IBAction
  func deleteHighlightedHistoryItem(_ sender: AnyObject) {
    guard let deletedIndex = menu.deleteHighlightedItem() else {
      return
    }
    
    if Self.isQueueModeOn && deletedIndex < Self.queueSize {
      Self.queueSize -= 1
      if !permitEmptyQueueMode && Self.queueSize == 0 {
        Self.isQueueModeOn = false
      }
      
      updateStatusMenuIcon(.decrement)
      updateMenuTitle()
      // menu updates the head of queue item itself when deleting
    }
  }
  
  @IBAction
  func clear(_ sender: AnyObject) {
    clearHistory()
    if !permitEmptyQueueMode {
      Self.isQueueModeOn = false
    }
  }
  
  @IBAction
  func undoLastCopy(_ sender: AnyObject) {
    guard let removeItem = history.first else {
      return
    }
    
    history.remove(removeItem)
    menu.delete(position: 0)
    
    if Self.isQueueModeOn && Self.queueSize > 0 {
      Self.queueSize -= 1
      if !permitEmptyQueueMode && Self.queueSize == 0 {
        Self.isQueueModeOn = false
      }
      
      updateStatusMenuIcon(.decrement)
      updateMenuTitle()
      menu.updateHeadOfQueue(index: queueHeadIndex)
    }
    
    // Normally set pasteboard to the previous history item, now first in the history after doing the
    // delete above. However if have items queued we instead don't want to change the pasteboard at all,
    // it needs to stay set to the front item in the queue.
    if !Self.isQueueModeOn || Self.queueSize == 0 {
      if let replaceItem = history.first {
        clipboard.copy(replaceItem)
      } else {
        clipboard.copy("")
      }
    }
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
    intro.openIntro(with: self)
    Self.returnFocusToPreviousApp = true
  }
  
  @IBAction
  func showSettings(_ sender: AnyObject) {
    showSettings(selectingPane: .general)
  }
  
  func showSettings(selectingPane pane: Settings.PaneIdentifier) {
    Self.returnFocusToPreviousApp = false
    settingsWindowController.show(pane: pane)
    settingsWindowController.window?.orderFrontRegardless()
    Self.returnFocusToPreviousApp = true
  }
  
  @IBAction
  func quit(_ sender: AnyObject) {
    NSApp.terminate(sender)
  }
  
  // MARK: -
  
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
    menu.cancelTrackingWithoutAnimation() // do this before any alerts appear
    withClearAlert(suppressClearAlert: suppressClearAlert) {
      self.history.clear()
      self.menu.clear()
      self.clipboard.clear()
      Self.queueSize = 0
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
    
    if !Accessibility.allowed && !UserDefaults.standard.completedIntro {
      showIntro(self)
    }
  }
  
  private func purchasesUpdated(_ update: Purchases.ObservationUpdate) {
    if case .success(_) = update {
      setFeatureFlags(givenPurchase: purchases.hasBoughtExtras)
    }
  }
  
  private func setFeatureFlags(givenPurchase hasPurchased: Bool) {
    Self.allowFullyExpandedHistory = hasPurchased
    Self.allowHistorySearch = hasPurchased
    Self.allowReplayFromHistory = hasPurchased
    Self.allowPasteMultiple = hasPurchased
    Self.allowUndoCopy = hasPurchased
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
  
  private func withNumberToPasteAlert(_ closure: @escaping (Int) -> Void) {
    let alert = numberQueuedAlert
    guard let field = alert.accessoryView as? RangedIntegerTextField else {
      return
    }
    Self.returnFocusToPreviousApp = false
    DispatchQueue.main.async {
      if alert.runModal() == NSApplication.ModalResponse.alertFirstButtonReturn {
        //alert.window.orderOut(nil)
        let number = Int(field.stringValue) ?? Self.queueSize
        closure(number)
      }
      Self.returnFocusToPreviousApp = true
    }
  }
  
  private func rebuild() {
    // TODO: don't think i need this
    menu.clear()
    menu.buildItems()
    if Self.isQueueModeOn {
      menu.updateHeadOfQueue(index: queueHeadIndex)
    }
  }
  
  // MARK: -
  // TODO: perhaps move title logic into its own obj
  
  private func updateMenuTitle() {
    if Self.isQueueModeOn {
      statusItem.button?.title = String(Self.queueSize) + "  "
    } else {
      statusItem.button?.title = ""
    }
  }
  
  private func setupStatusMenuIcon() {
    guard let button = statusItem.button else {
      return
    }
    
    button.image = NSImage(named: .cleepMenuIcon)
    button.imagePosition = .imageRight
    (button.cell as? NSButtonCell)?.highlightsBy = []
  }
  
  private func setStatusMenuIcon(to name: NSImage.Name) {
    guard let iconImage = NSImage(named: name) else {
      return
    }
    statusItem.button?.image = iconImage
  }
  
  private func updateStatusMenuIcon(_ direction: QueueChangeDirection = .none) {
    let icon: NSImage.Name
    var transition = SymbolTransition.replace
    if !Self.isQueueModeOn {
      icon = .cleepMenuIcon
      if direction == .decrement {
        transition = .blink(transitionIcon: .cleepMenuIconListMinus)
      }
    } else {
      if Self.queueSize == 0 {
        icon = .cleepMenuIconFill
      } else {
        icon = .cleepMenuIconList
      }
      if direction == .decrement {
        transition = .blink(transitionIcon: .cleepMenuIconListMinus)
      } else if direction == .increment && Self.queueSize == 1 {
        transition = .blink(transitionIcon: .cleepMenuIconFillPlus)
      } else if direction == .increment && Self.queueSize > 1 {
        transition = .blink(transitionIcon: .cleepMenuIconListPlus)
      }
    }
    
    guard let iconImage = NSImage(named: icon) else {
      return
    }
    
    if case .blink(let transitionIcon) = transition, let transitionImage = NSImage(named: transitionIcon) {
      // first show transition symbol, then blink to the final symbol
      statusItem.button?.image = transitionImage
      runOnIconBlinkTimer(afterInterval: iconBlinkIntervalSeconds) { [weak self] in
        self?.statusItem.button?.image = iconImage
      }
    } else {
      statusItem.button?.image = iconImage
    }
  }
  
  private func runOnIconBlinkTimer(afterInterval interval: Float, _ action: @escaping () -> Void) {
    if iconBlinkTimer != nil {
      cancelIconBlinkTimer()
    }
    iconBlinkTimer = timerForRunningOnMainQueueAfterDelay(interval) { [weak self] in
      self?.iconBlinkTimer = nil // doing this before calling closure supports closure itself calling runOnIconBlinkTimer, fwiw
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
