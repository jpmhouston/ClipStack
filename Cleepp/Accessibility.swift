import AppKit

struct Accessibility {
  private static var alert: NSAlert {
    let alert = NSAlert()
    alert.alertStyle = .warning
    alert.messageText = NSLocalizedString("accessibility_alert_message", comment: "")
    alert.addButton(withTitle: NSLocalizedString("accessibility_alert_deny", comment: ""))
    alert.addButton(withTitle: NSLocalizedString("accessibility_alert_open", comment: ""))
    alert.addButton(withTitle: NSLocalizedString("accessibility_alert_show_intro", comment: ""))
    alert.icon = NSImage(named: "NSSecurity")

    var locationName = NSLocalizedString("system_settings_name", comment: "")
    var paneName = NSLocalizedString("system_settings_pane", comment: "")
    if #unavailable(macOS 13) {
      locationName = NSLocalizedString("system_preferences_name", comment: "")
      paneName = NSLocalizedString("system_preferences_pane", comment: "")
    }

    alert.informativeText = NSLocalizedString("accessibility_alert_comment", comment: "")
      .replacingOccurrences(of: "{settings}", with: locationName)
      .replacingOccurrences(of: "{pane}", with: paneName)

    return alert
  }

  static var allowed: Bool { AXIsProcessTrustedWithOptions(nil) }
  static let openSettingsPaneURL =
    "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"

  static func check() -> Bool {
    if allowed {
      return true
    }

    Maccy.returnFocusToPreviousApp = false
    // Show accessibility window async to allow menu to close.
    DispatchQueue.main.async {
      switch alert.runModal() {
      case NSApplication.ModalResponse.alertSecondButtonReturn:
        openSecurityPanel()
      case NSApplication.ModalResponse.alertThirdButtonReturn:
        openIntro()
      default:
        break
      }
      Maccy.returnFocusToPreviousApp = true
    }

    return false
  }
  
  static func openSecurityPanel() {
    guard let url = URL(string: openSettingsPaneURL) else {
      // TODO: log url failure
      return
    }
    NSWorkspace.shared.open(url)
  }
  
  static func openIntro() {
    guard let url = URL(string: About.showIntroInAppURL) else {
      // TODO: log url failure
      return
    }
    NSWorkspace.shared.open(url)
  }
}
