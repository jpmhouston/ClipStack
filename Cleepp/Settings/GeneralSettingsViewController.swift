import Cocoa
import KeyboardShortcuts
import LaunchAtLogin
import Settings
#if ALLOW_SPARKLE_UPDATES
import Sparkle
#endif

class GeneralSettingsViewController: NSViewController, SettingsPane {
  public let paneIdentifier = Settings.PaneIdentifier.general
  public let paneTitle = NSLocalizedString("preferences_general", comment: "")
  public let toolbarItemIcon = NSImage(named: .gearshape)!

  override var nibName: NSNib.Name? { "GeneralSettingsViewController" }

  private let copyHotkeyRecorder = KeyboardShortcuts.RecorderCocoa(for: .queuedCopy)
  private let pasteHotkeyRecorder = KeyboardShortcuts.RecorderCocoa(for: .queuedPaste)

  #if ALLOW_SPARKLE_UPDATES
  private let sparkleUpdateController = SPUStandardUpdaterController(updaterDelegate:nil, userDriverDelegate:nil)
  #endif
  
  @IBOutlet weak var copyHotkeyContainerView: NSView!
  @IBOutlet weak var pasteHotkeyContainerView: NSView!
  @IBOutlet weak var launchAtLoginButton: NSButton!
  @IBOutlet weak var automaticUpdatesButton: NSButton!
  @IBOutlet weak var searchModeSeparator: NSView!
  @IBOutlet weak var searchModeLabel: NSTextField!
  @IBOutlet weak var searchModeButton: NSPopUpButton!
  @IBOutlet weak var checkForUpdatesOptionRow: NSGridRow!
  @IBOutlet weak var checkForUpdatesButtonRow: NSGridRow!

  override func viewDidLoad() {
    super.viewDidLoad()
    copyHotkeyContainerView.addSubview(copyHotkeyRecorder)
    pasteHotkeyContainerView.addSubview(pasteHotkeyRecorder)
    
    #if !ALLOW_SPARKLE_UPDATES
    hideSparkleUpdateRows()
    #endif
  }

  override func viewWillAppear() {
    super.viewWillAppear()
    populateLaunchAtLogin()
    populateSparkleAutomaticUpdates()
    populateSearchMode()
    showSearchOption(Cleepp.allowHistorySearch)
  }

  @IBAction func sparkleAutomaticUpdatesChanged(_ sender: NSButton) {
    #if ALLOW_SPARKLE_UPDATES
    sparkleUpdateController.updater.automaticallyChecksForUpdates = (sender.state == .on)
    #endif
  }
  
  private func populateSparkleAutomaticUpdates() {
    #if ALLOW_SPARKLE_UPDATES
    automaticUpdatesButton.state = sparkleUpdateController.updater.automaticallyChecksForUpdates ? .on : .off
    #endif
  }
  
  @IBAction func sparkleUpdateCheck(_ sender: NSButton) {
    #if ALLOW_SPARKLE_UPDATES
    sparkleUpdateController.checkForUpdates(sender)
    #endif
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

  private func showSearchOption(_ show: Bool) {
    searchModeSeparator.isHidden = !show
    searchModeLabel.isHidden = !show
    searchModeButton.isHidden = !show
  }

  private func hideSparkleUpdateRows() {
    checkForUpdatesOptionRow.isHidden = true
    checkForUpdatesButtonRow.isHidden = true
  }
  
}
