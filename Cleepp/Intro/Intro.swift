//
//  Intro.swift
//  ClipStack
//
//  Created by Pierre Houston on 2024-03-01.
//  Copyright © 2024 Bananameter Labs. All rights reserved.
//

import AppKit

extension NSWindow.FrameAutosaveName {
  static let cleeppIntro: NSWindow.FrameAutosaveName = "lol.bananameter.cleepp.intro.FrameAutosaveName"
}

public class IntroWindowController: PagedWindowController {
  @IBOutlet var viewController: IntroViewController!
  
  convenience init() {
    self.init(windowNibName: "Intro")
  }
  
  func openIntro(atPage page: IntroViewController.Pages? = nil, with object: Maccy) {
    // accessing window triggers loading from nib, do this before showWindow so we can setup before showing
    guard let _ = window, let viewController = viewController else {
      return
    }
    
    viewController.maccy = object
    viewController.startPage = page
    
    // these might be redundant, ok to do either way
    pageDelegate = viewController
    useView(viewController.view)
    
    reset()
    
    showWindow(self)
    restoreWindowPosition()
    #if compiler(>=5.9) && canImport(AppKit)
    if #available(macOS 14, *) {
      NSApp.activate()
    } else {
      NSApp.activate(ignoringOtherApps: true)
    }
    #else
    NSApp.activate(ignoringOtherApps: true)
    #endif
    
    window?.orderFrontRegardless()
  }
  
  private func restoreWindowPosition() {
    guard let window else {
      return
    }
    
    window.center()
    window.setFrameUsingName(.cleeppIntro)
    window.setFrameAutosaveName(.cleeppIntro)
  }
  
}


public class IntroViewController: NSViewController, PagedWindowControllerDelegate {
  @IBOutlet var staticLogoImage: NSImageView!
  @IBOutlet var animatedLogoImage: NSImageView!
  @IBOutlet var logoStopButton: NSButton!
  @IBOutlet var logoRestartButton: NSButton!
  @IBOutlet var setupNeededLabel: NSTextField!
  @IBOutlet var openSecurityPanelButton: NSButton!
  @IBOutlet var openSecurityPanelSpinner: NSProgressIndicator!
  @IBOutlet var hasAuthorizationEmoji: NSTextField!
  @IBOutlet var needsAuthorizationEmoji: NSTextField!
  @IBOutlet var hasAuthorizationLabel: NSTextField!
  @IBOutlet var needsAuthorizationLabel: NSTextField!
  @IBOutlet var nextAuthorizationDirectionsLabel: NSTextField!
  @IBOutlet var authorizationVerifiedEmoji: NSTextField!
  @IBOutlet var authorizationDeniedEmoji: NSTextField!
  @IBOutlet var demoImage: NSImageView!
  @IBOutlet var demoCopyBubble: NSView!
  @IBOutlet var demoPasteBubble: NSView!
  @IBOutlet var specialCopyPasteBehaviorLabel: NSTextField!
  @IBOutlet var filledIconLabel: NSTextField!
  @IBOutlet var enteringQueueModeLabel: NSTextField!
  @IBOutlet var sendSupportEmailButton: NSButton!
  @IBOutlet var copySupportEmailButton: NSButton!
  @IBOutlet var sendL10nEmailButton: NSButton!
  @IBOutlet var copyL10nEmailButton: NSButton!
  @IBOutlet var inAppPurchageTitle: NSTextField!
  @IBOutlet var inAppPurchageLabel: NSView!
  
  private var labelsToStyle: [NSTextField] { [specialCopyPasteBehaviorLabel, filledIconLabel, enteringQueueModeLabel].compactMap({$0}) }
  
  private var preAuthorizationPageFirsTime = true
  private var skipSetAuthorizationPage = false
  private var optionKeyEventMonitor: Any?
  private var logoPollTimer: DispatchSourceTimer?
  private let logoPollInterval = 0.5
  private var demoTimer: DispatchSourceTimer?
  private var demoCanceled = false
  var maccy: Maccy!
  var startPage: Pages?
  
  enum Pages: Int {
    case welcome = 0, checkAuth, setAuth, demo, aboutMenu, aboutMore, links
  }
  private var visited: Set<Pages> = []
  
  public override func viewDidLoad() {
    styleLabels()
    limitAnimatedLogoLooping()
    makeAnimatedGifWorkOnSomeOSVersions()
  }
  
  deinit {
    teardownOptionKeyObserver()
    cancelDemo()
  }
  
  // MARK: -
  
  func willOpen() -> Int {
    return startPage?.rawValue ?? Pages.welcome.rawValue
  }
  
  func willClose() {
    visited.removeAll()
    
    // if leaving with accessibility now authorized then don't auto-open again
    // thought about requiring that the user visit every page, but decided against it
    if Accessibility.allowed {
      UserDefaults.standard.completedIntro = true
    }
  }
  
  func willShowPage(_ number: Int) -> NSButton? {
    guard let page = Pages(rawValue: number) else {
      return nil
    }
    
    var customDefaultButtonResult: NSButton? = nil
    
    switch page {
    case .welcome:
      if !visited.contains(page) {
        startAnimatedLogo(withDelay: true)
      } else {
        animatedLogoImage.isHidden = true // show only static logo behind
      }
      if Accessibility.allowed {
        setupNeededLabel.isHidden = true
      }
      
    case .checkAuth:
      let isAuthorized = Accessibility.allowed
      hasAuthorizationEmoji.isHidden = !isAuthorized
      needsAuthorizationEmoji.isHidden = isAuthorized
      hasAuthorizationLabel.isHidden = !isAuthorized
      needsAuthorizationLabel.isHidden = isAuthorized
      nextAuthorizationDirectionsLabel.isHidden = isAuthorized
      openSecurityPanelButton.isEnabled = !isAuthorized
      customDefaultButtonResult = !isAuthorized ? openSecurityPanelButton : nil
      skipSetAuthorizationPage = isAuthorized
      
    case .setAuth:
      authorizationVerifiedEmoji.isHidden = true
      authorizationDeniedEmoji.isHidden = true
      
    case .demo:
      runDemo()
      
    case .links:
      showAltCopyEmailButtons(false)
      setupOptionKeyObserver() { [weak self] event in
        self?.showAltCopyEmailButtons(event.modifierFlags.contains(.option))
      }
      #if !FOR_APP_STORE
      inAppPurchageTitle.isHidden = true
      inAppPurchageLabel.isHidden = true
      #endif
      
    default:
      break
    }
    
    visited.insert(page)
    return customDefaultButtonResult
  }
  
  func shouldLeavePage(_ number: Int) -> Bool {
    guard let page = Pages(rawValue: number) else {
      return true
    }
    
    switch page {
    case .welcome:
      stopAnimatedLogo()
    case .checkAuth:
      openSecurityPanelSpinner.stopAnimation(self)
    case .demo:
      cancelDemo()
    case .links:
      teardownOptionKeyObserver()
    default:
      break
    }
    
    return true
  }
  
  func shouldSkipPage(_ number: Int) -> Bool {
    return skipSetAuthorizationPage && Pages(rawValue: number) == .setAuth
  }
  
  // MARK: -
  
  private func styleLabels() {
    for label in labelsToStyle {
      let styled = NSMutableAttributedString(attributedString: label.attributedStringValue)
      styled.applySimpleStyles(basedOnFont: label.font ?? NSFont.labelFont(ofSize: NSFont.labelFontSize))
      label.attributedStringValue = styled
    }
  }
  
  private var animatedLogoImageRep: NSBitmapImageRep? {
    guard let imageReps = animatedLogoImage.image?.representations else {
      return nil
    }
    for r in imageReps {
      if let imageRep = r as? NSBitmapImageRep,
         let frames = imageRep.value(forProperty: .frameCount) as? NSNumber,
         frames.intValue > 0
      {
        return imageRep
      }
    }
    return nil
  }
  
  private func limitAnimatedLogoLooping() {
    animatedLogoImageRep?.setProperty(.loopCount, withValue: NSNumber(1))
  }
  
  private func makeAnimatedGifWorkOnSomeOSVersions() {
    animatedLogoImage.imageScaling = .scaleNone
    animatedLogoImage.canDrawSubviewsIntoLayer = true
    if let gifSuperview = animatedLogoImage.superview {
      gifSuperview.wantsLayer = true
    }
  }
  
  private func stopAnimatedLogo() {
    cancelLogoPollTimer()
    animatedLogoImage.animates = false
    animatedLogoImage.isHidden = true
    logoStopButton.isHidden = true
    logoRestartButton.isHidden = false
  }
  
  private func startAnimatedLogo(withDelay useDelay: Bool = false) {
    let initialDelay = 2.5
    let pollInterval = 0.5
    
    // start with gif hidden, for a few seconds if useDelay is true
    animatedLogoImage.animates = false // so we can set it to true again below and reset it
    animatedLogoImage.isHidden = true
    logoStopButton.isHidden = false
    logoRestartButton.isHidden = true
    
    // poll to spot when animation ends, and when it does restore the static logo & swap the stop/play buttons
    if let imageRep = animatedLogoImageRep,
       let numFrames = (imageRep.value(forProperty: .frameCount) as? NSNumber)?.intValue,
       numFrames > 0
    {
      runOnLogoPollTimer(withDelay: useDelay ? initialDelay : 0.0, interval: pollInterval) { [weak self] in
        guard let self = self else {
          return false
        }
        if self.animatedLogoImage.isHidden {
          self.animatedLogoImage.isHidden = false // make gif visible if not, ie. on first time in
          self.animatedLogoImage.animates = true // reset it so it plays from the beginning
        }
        guard let current = (imageRep.value(forProperty: .currentFrame) as? NSNumber)?.intValue else {
          return false
        }
        if current >= numFrames - 1 {
          self.animatedLogoImage.isHidden = true
          self.logoStopButton.isHidden = true
          self.logoRestartButton.isHidden = false
          return false
        }
        return true
      }
    }
  }
  
  private func setupOptionKeyObserver(_ observe: @escaping (NSEvent) -> Void) {
    if let previousMonitor = optionKeyEventMonitor {
      NSEvent.removeMonitor(previousMonitor)
    }
    optionKeyEventMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { event in
      observe(event)
      return event
    }
  }
  
  private func teardownOptionKeyObserver() {
    if let eventMonitor = optionKeyEventMonitor {
      NSEvent.removeMonitor(eventMonitor)
      optionKeyEventMonitor = nil
    }
  }
  
  private func showAltCopyEmailButtons(_ showCopy: Bool) {
    sendSupportEmailButton.isHidden = showCopy
    copySupportEmailButton.isHidden = !showCopy
    sendL10nEmailButton.isHidden = true // showCopy  // for now hide the translation buttons
    copyL10nEmailButton.isHidden = true // !showCopy  // until i form some l10n plans
  }
  
  private func runDemo() {
    let startInterval: Double = 2.5
    let normalFrameInterval: Double = 2.0
    let cursorMoveFrameInterval: Double = 1.0
    let swapFrameInterval: Double = 2.5
    let copyBalloonTime: Double = 0.75
    let prePasteBalloonTime: Double = 0.25
    let postPasteBalloonTime: Double = 0.5
    let endHoldInterval: Double = 5.0
    let repeatTransitionInterval: Double = 1.0

    enum Frame {
      case img(_ name: String?, keepBubble: Bool = false, _ interval: Double)
      case copybubble(show: Bool = true, _ interval: Double)
      case pastebubble(show: Bool = true, _ interval: Double)
    }
    let frames: [Frame] = [
      .img("introDemo1", startInterval),
      .img("introDemo2", copyBalloonTime), .copybubble(normalFrameInterval - copyBalloonTime),
      .img("introDemo3", copyBalloonTime), .copybubble(normalFrameInterval - copyBalloonTime),
      .img("introDemo4", copyBalloonTime), .copybubble(normalFrameInterval - copyBalloonTime),
      .img("introDemo5", swapFrameInterval), .pastebubble(prePasteBalloonTime),
      .img("introDemo6", keepBubble:true, postPasteBalloonTime), .pastebubble(show:false, normalFrameInterval - postPasteBalloonTime),
      .img("introDemo7", cursorMoveFrameInterval - prePasteBalloonTime), .pastebubble(prePasteBalloonTime),
      .img("introDemo8", keepBubble:true, postPasteBalloonTime), .pastebubble(show:false, normalFrameInterval - postPasteBalloonTime),
      .img("introDemo9", cursorMoveFrameInterval - prePasteBalloonTime), .pastebubble(prePasteBalloonTime),
      .img("introDemo10", keepBubble:true, postPasteBalloonTime), .pastebubble(show:false, endHoldInterval - postPasteBalloonTime),
      .img(nil, repeatTransitionInterval)
    ]
    
    // sanity check frames array not empty here so no need to check anywhere below
    guard frames.count > 0 else {
      return
    }
    
    func showFrame(_ index: Int) {
      let interval: Double
      switch frames[index] {
      case .img(let name, let keepBubble, let t):
        if !keepBubble {
          demoCopyBubble.isHidden = true
          demoPasteBubble.isHidden = true
        }
        if let name = name {
          demoImage.image = NSImage(named: name)
        } else {
          demoImage.image = nil
        }
        interval = t
        
      case .copybubble(let show, let t):
        demoCopyBubble.isHidden = !show
        interval = t
        
      case .pastebubble(let show, let t):
        demoPasteBubble.isHidden = !show
        interval = t
      }
      
      guard !self.demoCanceled else {
        return
      }
      runOnDemoTimer(afterDelay: interval) { [weak self] in
        guard let self = self, !self.demoCanceled else {
          return
        }
        if index + 1 < frames.count {
          showFrame(index + 1)
        } else {
          showFrame(0)
        }
      }
    }
    
    // kick off perpetual sequence
    demoCopyBubble.isHidden = true
    demoPasteBubble.isHidden = true
    demoCanceled = false
    showFrame(0)
  }
  
  private func cancelDemo() {
    // If this func is called from the main thread, the runDemo sequence must be now blocked by the timer.
    // If this cancel is too late and callback within runDemo runs anyhow, it will stop safely because
    // either a) self not nil but demoCanceled flag will cause abort, or b) self=nil and closure aborts.
    // When called from deinit it must be that all strong references to self are gone so it's again
    // in the timer or the async dispatch in the timerFor.. method below, so will have case b). A-ok.
    demoCanceled = true
    cancelDemoTimer()
  }
  
  // MARK: -
  
  @IBAction func stopLogoAnimation(_ sender: AnyObject) {
    stopAnimatedLogo()
  }
  
  @IBAction func restartLogoAnimation(_ sender: AnyObject) {
    startAnimatedLogo()
  }

  @IBAction func openGeneralSettings(_ sender: AnyObject) {
    maccy.showSettings(selectingPane: .general)
  }
  
  @IBAction func openInAppPurchaceSettings(_ sender: AnyObject) {
    maccy.showSettings(selectingPane: .purchase)
  }
  
  @IBAction func checkAccessibilityAuthorization(_ sender: AnyObject) {
    let isAuthorized = Accessibility.allowed
    authorizationVerifiedEmoji.isHidden = !isAuthorized
    authorizationDeniedEmoji.isHidden = isAuthorized
  }
  
  @IBAction func openSettingsAppSecurityPanel(_ sender: AnyObject) {
    let openSecurityPanelSpinnerTime = 1.25
    
    self.openURL(string: Accessibility.openSettingsPaneURL)
    
    // make window controller skip ahead to the next page after a delay
    guard let windowController = (self.view.window?.windowController as? IntroWindowController) else {
      return
    }
    
    openSecurityPanelSpinner.startAnimation(sender)
    DispatchQueue.main.asyncAfter(deadline: .now() + openSecurityPanelSpinnerTime) { [weak self, weak windowController] in
      guard let self = self, let wc = windowController, wc.isOpen else {
        return
      }
      self.openSecurityPanelSpinner.stopAnimation(sender)
      
      if wc.isOpen && Pages(rawValue: wc.currentPageNumber) == .checkAuth {
        wc.advance(self)
      }
    }
  }
  
  @IBAction func openDocumentationWebpage(_ sender: AnyObject) {
    openURL(string: Cleepp.homepageURL)
  }
  
  @IBAction func openMaccyWebpage(_ sender: AnyObject) {
    openURL(string: Cleepp.maccyURL)
  }
  
  @IBAction func openGitHubWebpage(_ sender: AnyObject) {
    openURL(string: Cleepp.githubURL)
  }
  
  @IBAction func sendSupportEmail(_ sender: AnyObject) {
    openURL(string: Cleepp.supportEmailURL)
  }
  
  @IBAction func sendLocalizeVolunteerEmail(_ sender: AnyObject) {
    openURL(string: Cleepp.localizeVolunteerEmailURL)
  }
  
  @IBAction func copySupportEmail(_ sender: AnyObject) {
    maccy.copy(string: Cleepp.supportEmailAddress, excludedFromHistory: false)
  }
  
  @IBAction func copyLocalizeVolunteerEmail(_ sender: AnyObject) {
    maccy.copy(string: Cleepp.localizeVolunteerEmailAddress, excludedFromHistory: false)
  }
  
  // MARK: -
  
  private func runOnLogoPollTimer(withDelay delay: Double, interval: Double, _ action: @escaping () -> Bool) {
    if logoPollTimer != nil {
      cancelLogoPollTimer()
    }
    logoPollTimer = DispatchSource.scheduledTimerForRunningOnMainQueueRepeated(afterDelay: delay, interval: interval) { [weak self] in
      if !action() {
        self?.logoPollTimer = nil
        return false
      }
      return true
    }
  }
  
  private func cancelLogoPollTimer() {
    logoPollTimer?.cancel()
    logoPollTimer = nil
  }
  
  private func runOnDemoTimer(afterDelay delay: Double, _ action: @escaping () -> Void) {
    if demoTimer != nil {
      cancelDemoTimer()
    }
    demoTimer = DispatchSource.scheduledTimerForRunningOnMainQueue(afterDelay: delay) { [weak self] in
      self?.demoTimer = nil // doing this before calling closure supports closure itself calling runOnDemoTimer
      action()
    }
  }
  
  private func cancelDemoTimer() {
    demoTimer?.cancel()
    demoTimer = nil
  }
  
  private func openURL(string: String) {
    guard let url = URL(string: string) else {
      // TODO: log url failure
      return
    }
    NSWorkspace.shared.open(url)
  }
  
}
