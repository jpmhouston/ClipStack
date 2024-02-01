import Cocoa
import KeyboardShortcuts
import LaunchAtLogin
import Settings

class GeneralSettingsViewController: NSViewController, SettingsPane {
  public let paneIdentifier = Settings.PaneIdentifier.general
  public let paneTitle = NSLocalizedString("preferences_general", comment: "")
  public let toolbarItemIcon = NSImage(named: .gearshape)!

  override var nibName: NSNib.Name? { "GeneralSettingsViewController" }

  private let copyHotkeyRecorder = KeyboardShortcuts.RecorderCocoa(for: .queueCopy)
  private let pasteHotkeyRecorder = KeyboardShortcuts.RecorderCocoa(for: .queuePaste)

  @IBOutlet weak var copyHotkeyContainerView: NSView!
  @IBOutlet weak var pasteHotkeyContainerView: NSView!
  @IBOutlet weak var launchAtLoginButton: NSButton!
  @IBOutlet weak var searchModeButton: NSPopUpButton!
  @IBOutlet weak var checkForUpdatesOptionRow: NSGridRow!
  @IBOutlet weak var checkForUpdatesButtonRow: NSGridRow!

  override func viewDidLoad() {
    super.viewDidLoad()
    copyHotkeyContainerView.addSubview(copyHotkeyRecorder)
    pasteHotkeyContainerView.addSubview(pasteHotkeyRecorder)
    if true { // TODO: how to build for app store vs. github release
      hideSparkleUpdateRows()
    }
  }

  override func viewWillAppear() {
    super.viewWillAppear()
    populateLaunchAtLogin()
    populateSearchMode()
  }

  @IBAction func launchAtLoginChanged(_ sender: NSButton) {
    LaunchAtLogin.isEnabled = (sender.state == .on)
  }

  @IBAction func searchModeChanged(_ sender: NSPopUpButton) {
    switch sender.selectedTag() {
    case 3:
      UserDefaults.standard.searchMode = Search.Mode.mixed.rawValue
    case 2:
      UserDefaults.standard.searchMode = Search.Mode.regexp.rawValue
    case 1:
      UserDefaults.standard.searchMode = Search.Mode.fuzzy.rawValue
    default:
      UserDefaults.standard.searchMode = Search.Mode.exact.rawValue
    }
  }

  private func populateLaunchAtLogin() {
    launchAtLoginButton.state = LaunchAtLogin.isEnabled ? .on : .off
  }

  private func populateSearchMode() {
    switch Search.Mode(rawValue: UserDefaults.standard.searchMode) {
    case .mixed:
      searchModeButton.selectItem(withTag: 3)
    case .regexp:
      searchModeButton.selectItem(withTag: 2)
    case .fuzzy:
      searchModeButton.selectItem(withTag: 1)
    default:
      searchModeButton.selectItem(withTag: 0)
    }
  }

  private func hideSparkleUpdateRows() {
    checkForUpdatesOptionRow?.isHidden = true
    checkForUpdatesButtonRow?.isHidden = true
  }
  
}
