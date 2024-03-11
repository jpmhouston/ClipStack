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
  
  func openIntro(with object: Maccy) {
    // accessing window triggers loading from nib, do this before showWindow so we can setup before showing
    guard let _ = window, let viewController = viewController else {
      return
    }
    useView(viewController.view) // might be redundant, should by ok
    
    viewController.maccy = object
    pageDelegate = viewController
    
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
  @IBOutlet var sendSupportEmailButton: NSButton!
  @IBOutlet var copySupportEmailButton: NSButton!
  @IBOutlet var sendL10nEmailButton: NSButton!
  @IBOutlet var copyL10nEmailButton: NSButton!
  @IBOutlet var inAppPurchageTitle: NSTextField!
  @IBOutlet var inAppPurchageLabel: NSView!

  var labelsToStyle: [NSTextField] { [specialCopyPasteBehaviorLabel].compactMap({$0}) }
  
  private var preAuthorizationPageFirsTime = true
  private var skipSetAuthorizationPage = false
  private var optionKeyEventMonitor: Any?
  private var demoTimer: DispatchSourceTimer?
  private var demoCanceled = false
  var maccy: Maccy!
  
  enum Pages: Int {
    case welcome = 0, checkAuth, setAuth, demo, aboutMenu, aboutMore, links
  }
  private var visited: Set<Pages> = []
  
  public override func viewDidLoad() {
    styleLabels()
  }
  
  deinit {
    teardownOptionKeyObserver()
    cancelDemo()
  }
  
  // MARK: -
  
  func willOpen() {
    visited.removeAll()
    openSecurityPanelSpinner.stopAnimation(self)
  }
  
  func willClose() {
    teardownOptionKeyObserver()
    cancelDemo()
    
    // if leaving with accessibility now authorized then don't auto-open again
    if Accessibility.allowed {
      UserDefaults.standard.completedIntro = true
    }
  }
  
  func willShowPage(_ number: Int) {
    teardownOptionKeyObserver()
    cancelDemo()
    
    guard let page = Pages(rawValue: number) else {
      return
    }
    
    switch page {
    case .checkAuth:
      let isAuthorized = Accessibility.allowed
      hasAuthorizationEmoji.isHidden = !isAuthorized
      needsAuthorizationEmoji.isHidden = isAuthorized
      hasAuthorizationLabel.isHidden = !isAuthorized
      needsAuthorizationLabel.isHidden = isAuthorized
      nextAuthorizationDirectionsLabel.isHidden = isAuthorized
      openSecurityPanelButton.isEnabled = !isAuthorized
      if !visited.contains(page) {
        skipSetAuthorizationPage = isAuthorized
      }
      openSecurityPanelSpinner.stopAnimation(self)
      
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
//      #if !FOR_APP_STORE // TODO: uncomment this so non-appstore builds don't get these items
//      inAppPurchageTitle.isHidden = true
//      inAppPurchageLabel.isHidden = true
//      #endif
      
    default:
      break
    }
    
    visited.insert(page)
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
    sendL10nEmailButton.isHidden = showCopy
    copyL10nEmailButton.isHidden = !showCopy
  }
  
  private func runDemo() {
    // swift bug? using these causes build errors "Undefined symbol: unsafeMutableAddressor of demoCopyDelay" etc
    // when they were used in default values of enum case arguments :( decided to just use literals for all
    let startInterval: Float = 2.5
    let normalFrameInterval: Float = 2.0
    let cursorMoveFrameInterval: Float = 1.0
    let swapFrameInterval: Float = 2.5
    let copyBalloonTime: Float = 0.75
    let prePasteBalloonTime: Float = 0.25
    let postPasteBalloonTime: Float = 0.5
    let endHoldInterval: Float = 5.0
    let repeatTransitionInterval: Float = 1.0

    enum Frame {
      case img(_ name: String?, keepBubble: Bool = false, _ interval: Float)
      case copybubble(show: Bool = true, _ interval: Float)
      case pastebubble(show: Bool = true, _ interval: Float)
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
      let interval: Float
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
      runOnDemoTimer(afterInterval: interval) { [weak self] in
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
    // If this cancel is too late and callback within runDemo runs anyhow, it will stop safelu because
    // either a) self not nil but demoCanceled flag will cause abort, or b) self nil and closure aborts.
    // When called from deinit it must be that all strong references to self are gone so its again
    // in the timer or the async dispatch in the timerFor.. method below, so will have case b). A-ok.
    demoCanceled = true
    cancelDemoTimer()
  }
  
  // MARK: -
  
  @IBAction func openGeneralSettings(_ sender: AnyObject) {
    maccy.showSettings(selectingPane: .general)
  }
  
  @IBAction func openInAppPurchaceSettings(_ sender: AnyObject) {
    maccy.showSettings(selectingPane: .general) // TODO: add in-app-purchase pane
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
    DispatchQueue.main.asyncAfter(deadline: .now() + openSecurityPanelSpinnerTime) { [weak self] in
      guard let self = self else {
        return
      }
      self.openSecurityPanelSpinner.stopAnimation(sender)
      
      if windowController.isOpen && Pages(rawValue: windowController.currentPageNumber) == .checkAuth {
        windowController.advance(self)
      }
    }
  }
  
  @IBAction func openDocumentationWebpage(_ sender: AnyObject) {
    openURL(string: About.homepageURL)
  }
  
  @IBAction func openMaccyWebpage(_ sender: AnyObject) {
    openURL(string: About.maccyURL)
  }
  
  @IBAction func openGitHubWebpage(_ sender: AnyObject) {
    openURL(string: About.githubURL)
  }
  
  @IBAction func sendSupportEmail(_ sender: AnyObject) {
    openURL(string: About.supportEmailURL)
  }
  
  @IBAction func sendLocalizeVolunteerEmail(_ sender: AnyObject) {
    openURL(string: About.localizeVolunteerEmailURL)
  }
  
  @IBAction func copySupportEmail(_ sender: AnyObject) {
    maccy.copy(string: About.supportEmailURL, excludedFromHistory: false)
  }
  
  @IBAction func copyLocalizeVolunteerEmail(_ sender: AnyObject) {
    maccy.copy(string: About.localizeVolunteerEmailURL, excludedFromHistory: false)
  }
  
  // MARK: -
  
  private func runOnDemoTimer(afterInterval interval: Float, _ action: @escaping () -> Void) {
    if demoTimer != nil {
      cancelDemoTimer()
    }
    demoTimer = timerForRunningOnMainQueueAfterDelay(interval) { [weak self] in
      self?.demoTimer = nil // doing this before calling closure supports closure itself calling runOnDemoTimer
      action()
    }
  }
  
  private func cancelDemoTimer() {
    demoTimer?.cancel()
    demoTimer = nil
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
  
  private func openURL(string: String) {
    guard let url = URL(string: string) else {
      // TODO: log url failure
      return
    }
    NSWorkspace.shared.open(url)
  }
  
}

extension NSMutableAttributedString {
  func applySimpleStyles(basedOnFont baseFont: NSFont) {
    // currently the only styling supported is bold & italics, indicated by markdown-like ** and _
    let boldMarker = "**"
    let italicsMarker = "_"
    
    let fontMgr = NSFontManager()
    let boldFont = fontMgr.convert(baseFont, toHaveTrait: .boldFontMask)
    let italicsFont = fontMgr.convert(baseFont, toHaveTrait: .italicFontMask)
    
    var scanLocation = 0
    while true {
      if let range = range(delimitedBy: boldMarker, at: scanLocation, removingDelimiters: true) {
        let boldicizedFont: NSFont
        if let existingFont = fontAttributes(in: range)[NSAttributedString.Key.font] as? NSFont {
          boldicizedFont = fontMgr.convert(existingFont, toHaveTrait: .boldFontMask)
        } else {
          boldicizedFont = boldFont
        }
        addAttribute(NSAttributedString.Key.font, value: boldicizedFont, range: range)
        scanLocation = range.location + range.length
      } else {
        break
      }
    }
    
    scanLocation = 0
    while true {
      if let range = range(delimitedBy: italicsMarker, at: scanLocation, removingDelimiters: true) {
        let italicizedFont: NSFont
        if let existingFont = fontAttributes(in: range)[NSAttributedString.Key.font] as? NSFont {
          italicizedFont = fontMgr.convert(existingFont, toHaveTrait: .italicFontMask)
        } else {
          italicizedFont = italicsFont
        }
        addAttribute(NSAttributedString.Key.font, value: italicizedFont, range: range)
        scanLocation = range.location + range.length
      } else {
        break
      }
    }
  }
  
  func range(delimitedBy delimiter1: String, and delimiter2: String? = nil, at location: Int, removingDelimiters remove: Bool) -> NSRange? {
    let startDelimiter = delimiter1
    let endDelimiter = delimiter2 ?? delimiter1
    
    let stringLength = length
    if location >= stringLength {
      return nil
    }
    
    let entireRange = NSRange(location: location, length: stringLength - location)
    let startDelimiterRange = (string as NSString).range(of: startDelimiter, options: [], range: entireRange)
    if startDelimiterRange.location == NSNotFound {
      return nil
    }
    
    var delimitedLocation = startDelimiterRange.location + startDelimiterRange.length
    if delimitedLocation >= stringLength {
      return nil
    }
    
    let remainingRange = NSRange(location: delimitedLocation, length: stringLength - delimitedLocation)
    let endDelimiterRange = (string as NSString).range(of: endDelimiter, options: [], range: remainingRange)
    if endDelimiterRange.location == NSNotFound {
      return nil
    }
    
    let delimitedLength = endDelimiterRange.location - delimitedLocation
    
    if remove {
      // important to remove in this order, in removed start first then the afterwared the end range will be wrong
      deleteCharacters(in: endDelimiterRange)
      deleteCharacters(in: startDelimiterRange)
      delimitedLocation -= startDelimiterRange.length
    }
    
    return NSRange(location: delimitedLocation, length: delimitedLength)
  }
}
