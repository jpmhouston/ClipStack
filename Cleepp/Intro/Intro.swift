//
//  Intro.swift
//  ClipStack
//
//  Created by Pierre Houston on 2024-03-01.
//  Copyright © 2024 Bananameter Labs. All rights reserved.
//

import AppKit
import SDWebImage
import os.log

extension NSWindow.FrameAutosaveName {
  static let cleeppIntro: NSWindow.FrameAutosaveName = "lol.bananameter.batchclip.intro.FrameAutosaveName"
}

public class IntroWindowController: PagedWindowController {
  @IBOutlet var viewController: IntroViewController!
  
  convenience init() {
    self.init(windowNibName: "Intro")
  }
  
  func openIntro(atPage page: IntroViewController.Pages? = nil, with object: Cleepp) {
    // if already loaded then also check if already onscreen, if so being to the front and that's all
    // (continuing anyway works, except for the restoreWindowPosition() call, until the window is
    // closed there's no cached window position and its reset to the center of the screen below)
    if isWindowLoaded, let window = window, window.isVisible {
      window.orderFrontRegardless()
      return
    }
    
    // accessing window triggers loading from nib, do this before showWindow so we can setup before showing
    guard let window = window, let viewController = viewController else {
      return
    }
    
    viewController.cleepp = object
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
    
    window.collectionBehavior.formUnion(.moveToActiveSpace)
    window.orderFrontRegardless()
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
  @IBOutlet var staticLogoImage: NSImageView?
  @IBOutlet var animatedLogoImage: SDAnimatedImageView?
  @IBOutlet var logoStopButton: NSButton?
  @IBOutlet var logoRestartButton: NSButton?
  @IBOutlet var setupNeededLabel: NSTextField?
  @IBOutlet var openSecurityPanelButton: NSButton?
  @IBOutlet var openSecurityPanelSpinner: NSProgressIndicator?
  @IBOutlet var hasAuthorizationEmoji: NSTextField?
  @IBOutlet var needsAuthorizationEmoji: NSTextField?
  @IBOutlet var hasAuthorizationLabel: NSTextField?
  @IBOutlet var needsAuthorizationLabel: NSTextField?
  @IBOutlet var nextAuthorizationDirectionsLabel: NSTextField?
  @IBOutlet var authorizationVerifiedEmoji: NSTextField?
  @IBOutlet var authorizationDeniedEmoji: NSTextField?
  @IBOutlet var demoImage: NSImageView?
  @IBOutlet var demoCopyBubble: NSView?
  @IBOutlet var demoPasteBubble: NSView?
  @IBOutlet var specialCopyPasteBehaviorLabel: NSTextField?
  @IBOutlet var filledIconLabel: NSTextField?
  @IBOutlet var enteringQueueModeLabel: NSTextField?
  @IBOutlet var inAppPurchageTitle: NSTextField?
  @IBOutlet var inAppPurchageLabel: NSView?
  @IBOutlet var appStorePromoTitle: NSTextField?
  @IBOutlet var appStorePromoLabel: NSView?
  @IBOutlet var openDocsLinkButton: NSButton?
  @IBOutlet var copyDocsLinkButton: NSButton?
  @IBOutlet var sendSupportEmailButton: NSButton?
  @IBOutlet var copySupportEmailButton: NSButton?
  @IBOutlet var openDonationLinkButton: NSButton?
  @IBOutlet var copyDonationLinkButton: NSButton?
  @IBOutlet var openPrivacyPolicyLinkButton: NSButton?
  @IBOutlet var openAppStoreEULALinkButton: NSButton?
  //@IBOutlet var sendL10nEmailButton: NSButton?
  //@IBOutlet var copyL10nEmailButton: NSButton?
  @IBOutlet var aboutGitHubLabel: NSTextField?
  @IBOutlet var appStoreAboutGitHubLabel: NSTextField?
  @IBOutlet var openGitHubLinkButton: NSButton?
  @IBOutlet var copyGitHubLinkButton: NSButton?
  @IBOutlet var openMaccyLinkButton: NSButton?
  @IBOutlet var copyMaccyLinkButton: NSButton?
  
  private var labelsToStyle: [NSTextField] { [specialCopyPasteBehaviorLabel, filledIconLabel, enteringQueueModeLabel].compactMap({$0}) }
  
  private var preAuthorizationPageFirsTime = true
  private var skipSetAuthorizationPage = false
  private var optionKeyEventMonitor: Any?
  private var logoTimer: DispatchSourceTimer?
  private var demoTimer: DispatchSourceTimer?
  private var demoCanceled = false
  var cleepp: Cleepp!
  var startPage: Pages?
  
  enum Pages: Int {
    case welcome = 0, checkAuth, setAuth, demo, aboutMenu, aboutMore, links
  }
  private var visited: Set<Pages> = []
  
  public override func viewDidLoad() {
    styleLabels()
    setupAnimatedLogo()
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
        resetAnimatedLogo()
      }
      if Accessibility.allowed {
        setupNeededLabel?.isHidden = true
      }
      
    case .checkAuth:
      let isAuthorized = Accessibility.allowed
      hasAuthorizationEmoji?.isHidden = !isAuthorized
      needsAuthorizationEmoji?.isHidden = isAuthorized
      hasAuthorizationLabel?.isHidden = !isAuthorized
      needsAuthorizationLabel?.isHidden = isAuthorized
      nextAuthorizationDirectionsLabel?.isHidden = isAuthorized
      openSecurityPanelButton?.isEnabled = !isAuthorized
      customDefaultButtonResult = !isAuthorized ? openSecurityPanelButton : nil
      skipSetAuthorizationPage = isAuthorized
      
    case .setAuth:
      authorizationVerifiedEmoji?.isHidden = true
      authorizationDeniedEmoji?.isHidden = true
      
    case .demo:
      runDemo()
      
    case .links:
      #if FOR_APP_STORE
      inAppPurchageTitle?.isHidden = false
      inAppPurchageLabel?.isHidden = false
      appStorePromoTitle?.isHidden = true
      appStorePromoLabel?.isHidden = true
      openDonationLinkButton?.isHidden = true
      copyDonationLinkButton?.isHidden = true
      openPrivacyPolicyLinkButton?.isHidden = false
      openAppStoreEULALinkButton?.isHidden = false
      aboutGitHubLabel?.isHidden = true
      appStoreAboutGitHubLabel?.isHidden = false
      #else
      inAppPurchageTitle?.isHidden = true
      inAppPurchageLabel?.isHidden = true
      appStorePromoTitle?.isHidden = false
      appStorePromoLabel?.isHidden = false
      openPrivacyPolicyLinkButton?.isHidden = true
      openAppStoreEULALinkButton?.isHidden = true
      aboutGitHubLabel?.isHidden = false
      appStoreAboutGitHubLabel?.isHidden = true
      #endif
      showAltCopyEmailButtons(false)
      setupOptionKeyObserver() { [weak self] event in
        self?.showAltCopyEmailButtons(event.modifierFlags.contains(.option))
      }
      
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
      openSecurityPanelSpinner?.stopAnimation(self)
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
  
  private func setupAnimatedLogo() {
    #if INTRO_ANIMATED_LOGO // app currently has no animated logo
    animatedLogoImage?.autoPlayAnimatedImage = false
    animatedLogoImage?.isHidden = true
    logoStopButton?.isHidden = true
    
    // replace NSImage loaded from the nib with a SDAnimatedImage
    guard let name = animatedLogoImage?.image?.name(), let sdImage = SDAnimatedImage(named: name + ".gif") else {
      logoRestartButton?.isHidden = true
      return
    }
    animatedLogoImage?.image = sdImage
    logoRestartButton?.isHidden = false
    #else
    animatedLogoImage?.isHidden = true
    logoStopButton?.isHidden = true
    logoRestartButton?.isHidden = true
    #endif
  }
  
  private func resetAnimatedLogo() {
    #if INTRO_ANIMATED_LOGO
    stopAnimatedLogo() // show static logo initially
    #endif
  }
  
  private func stopAnimatedLogo() {
    #if INTRO_ANIMATED_LOGO
    cancelLogoTimer()
    animatedLogoImage?.player?.stopPlaying()
    animatedLogoImage?.isHidden = true
    logoStopButton?.isHidden = true
    logoRestartButton?.isHidden = false
    #endif
  }
  
  private func startAnimatedLogo(withDelay useDelay: Bool = false) {
    #if INTRO_ANIMATED_LOGO
    let initialDelay = 2.0
    
    // reset player to the start and setup to stop after a loop completes
    guard let gifPlayer = animatedLogoImage?.player else {
      return
    }
    gifPlayer.seekToFrame(at: 0, loopCount: 0)
    gifPlayer.animationLoopHandler = { [weak self] loop in
      self?.stopAnimatedLogo()
    }
    
    // start with gif hidden, for a few seconds if useDelay is true
    animatedLogoImage?.isHidden = true
    logoStopButton?.isHidden = false
    logoRestartButton?.isHidden = true
    
    if !useDelay {
      animatedLogoImage?.isHidden = false
      gifPlayer.startPlaying()
    } else {
      runOnLogoDelayTimer(withDelay: initialDelay) { [weak self] in
        self?.animatedLogoImage?.isHidden = false
        self?.animatedLogoImage?.player?.startPlaying()
      }
    }
    #endif
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
    openDocsLinkButton?.isHidden = showCopy
    copyDocsLinkButton?.isHidden = !showCopy
    sendSupportEmailButton?.isHidden = showCopy
    copySupportEmailButton?.isHidden = !showCopy
    //sendL10nEmailButton?.isHidden = showCopy  // for now i've removed the translation buttons
    //copyL10nEmailButton?.isHidden = !showCopy  // until i form some l10n plans
    #if !FOR_APP_STORE
    openDonationLinkButton?.isHidden = showCopy
    copyDonationLinkButton?.isHidden = !showCopy
    #endif
    openGitHubLinkButton?.isHidden = showCopy
    copyGitHubLinkButton?.isHidden = !showCopy
    openMaccyLinkButton?.isHidden = showCopy
    copyMaccyLinkButton?.isHidden = !showCopy
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
          demoCopyBubble?.isHidden = true
          demoPasteBubble?.isHidden = true
        }
        if let name = name {
          demoImage?.image = NSImage(named: name)
        } else {
          demoImage?.image = nil
        }
        interval = t
        
      case .copybubble(let show, let t):
        demoCopyBubble?.isHidden = !show
        interval = t
        
      case .pastebubble(let show, let t):
        demoPasteBubble?.isHidden = !show
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
    demoCopyBubble?.isHidden = true
    demoPasteBubble?.isHidden = true
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
    cleepp.showSettings(selectingPane: .general)
  }
  
  @IBAction func openInAppPurchaceSettings(_ sender: AnyObject) {
    cleepp.showSettings(selectingPane: .purchase)
  }
  
  @IBAction func checkAccessibilityAuthorization(_ sender: AnyObject) {
    let isAuthorized = Accessibility.allowed
    authorizationVerifiedEmoji?.isHidden = !isAuthorized
    authorizationDeniedEmoji?.isHidden = isAuthorized
  }
  
  @IBAction func openSettingsAppSecurityPanel(_ sender: AnyObject) {
    let openSecurityPanelSpinnerTime = 1.25
    
    self.openURL(string: Accessibility.openSettingsPaneURL)
    
    // make window controller skip ahead to the next page after a delay
    guard let windowController = (self.view.window?.windowController as? IntroWindowController) else {
      return
    }
    
    openSecurityPanelSpinner?.startAnimation(sender)
    DispatchQueue.main.asyncAfter(deadline: .now() + openSecurityPanelSpinnerTime) { [weak self, weak windowController] in
      guard let self = self, let wc = windowController, wc.isOpen else {
        return
      }
      self.openSecurityPanelSpinner?.stopAnimation(sender)
      
      if wc.isOpen && Pages(rawValue: wc.currentPageNumber) == .checkAuth {
        wc.advance(self)
      }
    }
  }
  
  @IBAction func openCleeppInMacAppStore(_ sender: AnyObject) {
    openURL(string: Cleepp.macAppStoreURL)
  }
  
  @IBAction func openDocumentationWebpage(_ sender: AnyObject) {
    openURL(string: Cleepp.homepageURL)
  }
  
  @IBAction func copyDocumentationWebpage(_ sender: AnyObject) {
    Clipboard.shared.copy(Cleepp.homepageURL, excludeFromHistory: false)
  }
  
  @IBAction func openGitHubWebpage(_ sender: AnyObject) {
    openURL(string: Cleepp.githubURL)
  }
  
  @IBAction func copyGitHubWebpage(_ sender: AnyObject) {
    Clipboard.shared.copy(Cleepp.githubURL, excludeFromHistory: false)
  }
  
  @IBAction func openDonationWebpage(_ sender: AnyObject) {
    openURL(string: Cleepp.donationURL)
  }
  
  @IBAction func copyDonationWebpage(_ sender: AnyObject) {
    Clipboard.shared.copy(Cleepp.donationURL, excludeFromHistory: false)
  }
  
  @IBAction func openPrivacyPolicyWebpage(_ sender: AnyObject) {
    openURL(string: Cleepp.privacyPolicyURL)
  }
  
  @IBAction func openAppStoreEULAWebpage(_ sender: AnyObject) {
    openURL(string: Cleepp.appStoreUserAgreementURL)
  }
  
  @IBAction func openMaccyWebpage(_ sender: AnyObject) {
    openURL(string: Cleepp.maccyURL)
  }
  
  @IBAction func copyMaccyWebpage(_ sender: AnyObject) {
    Clipboard.shared.copy(Cleepp.maccyURL, excludeFromHistory: false)
  }
  
  @IBAction func sendSupportEmail(_ sender: AnyObject) {
    openURL(string: Cleepp.supportEmailURL)
  }
  
  @IBAction func copySupportEmail(_ sender: AnyObject) {
    Clipboard.shared.copy(Cleepp.supportEmailAddress, excludeFromHistory: false)
  }
  
  @IBAction func sendLocalizeVolunteerEmail(_ sender: AnyObject) {
    openURL(string: Cleepp.localizeVolunteerEmailURL)
  }
  
  @IBAction func copyLocalizeVolunteerEmail(_ sender: AnyObject) {
    Clipboard.shared.copy(Cleepp.localizeVolunteerEmailAddress, excludeFromHistory: false)
  }
  
  // MARK: -
  
  private func runOnLogoDelayTimer(withDelay delay: Double, _ action: @escaping () -> Void) {
    if logoTimer != nil {
      cancelLogoTimer()
    }
    logoTimer = DispatchSource.scheduledTimerForRunningOnMainQueue(afterDelay: delay) {
      action()
    }
  }
  
  func cancelLogoTimer() {
    logoTimer?.cancel()
    logoTimer = nil
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
      os_log(.default, "failed to create URL %@", string)
      return
    }
    if !NSWorkspace.shared.open(url) {
      os_log(.default, "failed to open URL %@", string)
    }
  }
  
}
