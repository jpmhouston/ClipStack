import Cocoa

// TODO: replace with a custom window
// so that: 1) intro button can be a real button 2) less cramped 3) can easily close programmatically
// should leave Maccy source unchanged and add a new AboutCleepp.swift/xib

class About {
  private var blurb: NSAttributedString {
    return NSAttributedString(
      string: "Cleepp adds a new mode to the clipboard\nthat lets you copy multiple times from one\nplace then paste them all in order elsewhere.",
      attributes: [NSAttributedString.Key.foregroundColor: NSColor.labelColor]);
  }
  
  private var introLink: NSAttributedString {
    let string = NSMutableAttributedString(string: "More info: Open Intro",
                                           attributes: [NSAttributedString.Key.foregroundColor: NSColor.labelColor])
    string.addAttribute(.link, value: "cleeppapp:intro", range: NSRange(location: 11, length: 10))
    return string
  }
  
  private var forkCredits: NSMutableAttributedString {
      let string = NSMutableAttributedString(string: "Thank you to authors of Maccy which this\napp is a derivative of. Check it out for a\nfull-featured clipboard history manager.",
                                             attributes: [NSAttributedString.Key.foregroundColor: NSColor.labelColor])
      string.addAttribute(.link, value: "https://maccy.app", range: NSRange(location: 24, length: 5))
      return string
  }

  private var links: NSAttributedString {
    let string = NSMutableAttributedString(string: "Website│GitHub│Support",
                                           attributes: [NSAttributedString.Key.foregroundColor: NSColor.labelColor])
    string.addAttribute(.link, value: "http://cleepp.bananameter.lol", range: NSRange(location: 0, length: 7))
    string.addAttribute(.link, value: "https://github.com/jpmhouston/Cleepp", range: NSRange(location: 8, length: 6))
    string.addAttribute(.link, value: "mailto:cleepp@bananameter.lol", range: NSRange(location: 15, length: 7))
    return string
  }

  private var credits: NSAttributedString {
    let credits = NSMutableAttributedString(string: "",
                                            attributes: [NSAttributedString.Key.foregroundColor: NSColor.labelColor])
    credits.append(links)
    credits.append(NSAttributedString(string: "\n\n"))
    credits.append(blurb)
    credits.append(NSAttributedString(string: "\n"))
    credits.append(introLink)
    credits.append(NSAttributedString(string: "\n\n"))
    credits.append(forkCredits)
    credits.setAlignment(.center, range: NSRange(location: 0, length: credits.length))
    return credits
  }

  @objc
  func openAbout() {
    NSApp.activate(ignoringOtherApps: true)
    NSApp.orderFrontStandardAboutPanel(options: [NSApplication.AboutPanelOptionKey.credits: credits])
  }
}
