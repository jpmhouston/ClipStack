import Cocoa
import Settings

class StorageSettingsViewController: NSViewController, SettingsPane {
  let paneIdentifier = Settings.PaneIdentifier.storage
  let paneTitle = NSLocalizedString("preferences_storage", comment: "")
  let toolbarItemIcon = NSImage(named: .externaldrive)!

  let sizeMin = CleeppMenu.minNumMenuItems
  let sizeMax = 999

  override var nibName: NSNib.Name? { "StorageSettingsViewController" }

  @IBOutlet weak var sizeTextField: NSTextField!
  @IBOutlet weak var sizeStepper: NSStepper!
  @IBOutlet weak var sizeLabel: NSTextField!
  @IBOutlet weak var sizeControls: NSView!
  @IBOutlet weak var sizeSeparator: NSView!
  @IBOutlet weak var storeFilesButton: NSButton!
  @IBOutlet weak var storeImagesButton: NSButton!
  @IBOutlet weak var storeTextButton: NSButton!

  private var sizeFormatter: NumberFormatter!

  override func viewDidLoad() {
    super.viewDidLoad()
    setMinAndMaxSize()
  }

  override func viewWillAppear() {
    super.viewWillAppear()
    populateSize()
    populateStoredTypes()
    enableSizeOptions(Cleepp.allowDictinctStorageSize) // hide for simplicity when moot
  }

  @IBAction func sizeFieldChanged(_ sender: NSTextField) {
    UserDefaults.standard.size = sender.integerValue
    sizeStepper.integerValue = sender.integerValue
  }

  @IBAction func sizeStepperChanged(_ sender: NSStepper) {
    UserDefaults.standard.size = sender.integerValue
    sizeTextField.integerValue = sender.integerValue
  }

  @IBAction func storeFilesChanged(_ sender: NSButton) {
    let types: Set = [NSPasteboard.PasteboardType.fileURL]
    sender.state == .on ? addEnabledTypes(types) : removeEnabledTypes(types)
  }

  @IBAction func storeImagesChanged(_ sender: NSButton) {
    let types: Set = [NSPasteboard.PasteboardType.tiff, NSPasteboard.PasteboardType.png]
    sender.state == .on ? addEnabledTypes(types) : removeEnabledTypes(types)
  }

  @IBAction func storeTextChanged(_ sender: NSButton) {
    let types: Set = [
      NSPasteboard.PasteboardType.html,
      NSPasteboard.PasteboardType.rtf,
      NSPasteboard.PasteboardType.string
    ]
    sender.state == .on ? addEnabledTypes(types) : removeEnabledTypes(types)
  }

  private func setMinAndMaxSize() {
    let effectiveMin = max(sizeMin, UserDefaults.standard.maxMenuItems)
    sizeFormatter = NumberFormatter()
    sizeFormatter.minimum = effectiveMin as NSNumber
    sizeFormatter.maximum = sizeMax as NSNumber
    sizeFormatter.maximumFractionDigits = 0
    sizeTextField.formatter = sizeFormatter
    sizeStepper.minValue = Double(effectiveMin)
    sizeStepper.maxValue = Double(sizeMax)
  }

  private func enableSizeOptions(_ enable: Bool) {
    sizeLabel.isHidden = !enable
    sizeTextField.isHidden = !enable
    sizeStepper.isHidden = !enable
    sizeSeparator.isHidden = !enable
  }

  private func populateSize() {
    let effectiveSize = max(UserDefaults.standard.size, UserDefaults.standard.maxMenuItems)
    sizeTextField.integerValue = effectiveSize
    sizeStepper.integerValue = effectiveSize
  }

  private func populateStoredTypes() {
    let types = UserDefaults.standard.enabledPasteboardTypes
    storeFilesButton.state = types.contains(.fileURL) ? .on : .off
    storeImagesButton.state = types.isSuperset(of: [.tiff, .png]) ? .on : .off
    storeTextButton.state = types.contains(.string) ? .on : .off
  }

  private func addEnabledTypes(_ types: Set<NSPasteboard.PasteboardType>) {
    UserDefaults.standard.enabledPasteboardTypes = UserDefaults.standard.enabledPasteboardTypes.union(types)
  }

  private func removeEnabledTypes(_ types: Set<NSPasteboard.PasteboardType>) {
    UserDefaults.standard.enabledPasteboardTypes = UserDefaults.standard.enabledPasteboardTypes.subtracting(types)
  }
}
