import Cocoa

// TODO: replace with a custom window
// so that: 1) intro button can be a real button 2) less cramped 3) can easily close programmatically

class About {
  
  private var blurb: NSAttributedString {
    return NSAttributedString(
      string: "Batch Clipboard adds a new clipboard mode\nthat lets you copy multiple times from one\nplace then paste them somewhere else in order.",
      attributes: [.foregroundColor: NSColor.labelColor]);
  }
  
  private var links: NSAttributedString {
    let string = NSMutableAttributedString(string: "Website│GitHub│Support",
                                           attributes: [.foregroundColor: NSColor.labelColor])
    string.addAttribute(.link, value: Cleepp.homepageURL, range: NSRange(location: 0, length: 7))
    string.addAttribute(.link, value: Cleepp.githubURL, range: NSRange(location: 8, length: 6))
    string.addAttribute(.link, value: Cleepp.supportEmailURL, range: NSRange(location: 15, length: 7))
    return string
  }
  
  private var introLink: NSAttributedString {
    let string = NSMutableAttributedString(string: "More information: Show Intro",
                                           attributes: [.foregroundColor: NSColor.labelColor])
    string.addAttribute(.link, value: Cleepp.showIntroInAppURL, range: NSRange(location: 18, length: 10))
    return string
  }
  
  private var creditsLink: NSMutableAttributedString {
    let string = NSMutableAttributedString(string: "Credits and licenses: Show Licenses",
                                           attributes: [.foregroundColor: NSColor.labelColor])
    string.addAttribute(.link, value: Cleepp.showLicensesInAppURL, range: NSRange(location: 22, length: 13))
    return string
  }
  
  private var newLine: NSAttributedString {
    return NSAttributedString(string: "\n")
  }
  
  private var shortSpacingLine: NSAttributedString {
    let spacingStyle = NSMutableParagraphStyle()
    spacingStyle.maximumLineHeight = 8
    return NSAttributedString(string: "\n", attributes: [.paragraphStyle: spacingStyle])
  }
  
  private var credits: NSAttributedString {
    let credits = NSMutableAttributedString(string: "", attributes: [.foregroundColor: NSColor.labelColor])
    credits.append(blurb)
    credits.append(newLine)
    credits.append(shortSpacingLine)
    credits.append(links)
    credits.append(newLine)
    credits.append(shortSpacingLine)
    credits.append(introLink)
    credits.append(newLine)
    credits.append(shortSpacingLine)
    credits.append(creditsLink)
    credits.setAlignment(.center, range: NSRange(location: 0, length: credits.length))
    return credits
  }
  
  private var version: String {
    let infoPlistVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    #if FOR_APP_STORE
    return infoPlistVersion + " for Mac App Store"
    #else
    return infoPlistVersion + " non-App Store build"
    #endif
  }
  
  @objc
  func openAbout() {
    NSApp.activate(ignoringOtherApps: true)
    NSApp.orderFrontStandardAboutPanel(options: [.credits: credits, .applicationVersion: version])
  }
}
