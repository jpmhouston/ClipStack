import Cocoa
import Settings

class AppearanceSettingsViewController: NSViewController, SettingsPane, NSTextFieldDelegate {
  let paneIdentifier = Settings.PaneIdentifier.appearance
  let paneTitle = NSLocalizedString("preferences_appearance", comment: "")
  let toolbarItemIcon = NSImage(named: .paintpalette)!
  
  override var nibName: NSNib.Name? { "AppearanceSettingsViewController" }
  
  @IBOutlet weak var imageHeightField: NSTextField!
  @IBOutlet weak var imageHeightStepper: NSStepper!
  @IBOutlet weak var numberOfItemsField: NSTextField!
  @IBOutlet weak var numberOfItemsDescription: NSTextField!
  @IBOutlet weak var numberOfItemsExtendedDescription: NSTextField!
  @IBOutlet weak var numberOfItemsAltDescription: NSTextField!
  @IBOutlet weak var numberOfItemsStepper: NSStepper!
  @IBOutlet weak var titleLengthField: NSTextField!
  @IBOutlet weak var titleLengthStepper: NSStepper!
  @IBOutlet weak var previewDelayField: NSTextField!
  @IBOutlet weak var previewDelayStepper: NSStepper!
  @IBOutlet weak var showSpecialSymbolsButton: NSButton!
  @IBOutlet weak var showSearchFieldButton: NSButton!
  
  private let imageHeightMin = 1
  private let imageHeightMax = 200
  private var imageHeightFormatter: NumberFormatter!
  
  private let numberOfItemsMin = CleeppMenu.minNumMenuItems
  private let numberOfItemsMax = 99
  private var numberOfItemsFormatter: NumberFormatter!
  
  private let titleLengthMin = 30
  private let titleLengthMax = 200
  private var titleLengthFormatter: NumberFormatter!
  
  private let previewDelayMin = 200
  private let previewDelayMax = 100_000
  private var previewDelayFormatter: NumberFormatter!
  
  override func viewDidLoad() {
    super.viewDidLoad()
    setImageHeightRange()
    setNumberOfItemsRange()
    setTitleLengthRange()
    setPreviewDelayRange()
  }
  
  override func viewWillAppear() {
    super.viewWillAppear()
    populateImageHeight()
    updateMinNumberOfItems()
    populateNumberOfItems()
    populateTitleLength()
    populatePreviewDelay()
    populateShowSpecialSymbols()
    showSearchOption(Cleepp.allowHistorySearch)
  }
  
  @IBAction func imageHeightFieldChanged(_ sender: NSTextField) {
    UserDefaults.standard.imageMaxHeight = sender.integerValue
    imageHeightStepper.integerValue = sender.integerValue
  }
  
  @IBAction func imageHeightStepperChanged(_ sender: NSStepper) {
    UserDefaults.standard.imageMaxHeight = sender.integerValue
    imageHeightField.integerValue = sender.integerValue
  }
  
  @IBAction func numberOfItemsFieldChanged(_ sender: NSTextField) {
    UserDefaults.standard.maxMenuItems = sender.integerValue
    numberOfItemsStepper.integerValue = sender.integerValue
    showNumberOfItemsDescription(forSimpleMode: !Cleepp.allowDictinctStorageSize, forZeroEntered: sender.integerValue == 0)
  }
  
  @IBAction func numberOfItemsStepperChanged(_ sender: NSStepper) {
    UserDefaults.standard.maxMenuItems = sender.integerValue
    numberOfItemsField.integerValue = sender.integerValue
  }
  
  @IBAction func titleLengthFieldChanged(_ sender: NSTextField) {
    UserDefaults.standard.maxMenuItemLength = sender.integerValue
    titleLengthStepper.integerValue = sender.integerValue
  }
  
  @IBAction func titleLengthStepperChanged(_ sender: NSStepper) {
    UserDefaults.standard.maxMenuItemLength = sender.integerValue
    titleLengthField.integerValue = sender.integerValue
  }
  
  @IBAction func previewDelayFieldChanged(_ sender: NSTextField) {
    UserDefaults.standard.previewDelay = sender.integerValue
    previewDelayStepper.integerValue = sender.integerValue
  }
  
  @IBAction func previewDelayStepperChanged(_ sender: NSStepper) {
    UserDefaults.standard.previewDelay = sender.integerValue
    previewDelayField.integerValue = sender.integerValue
  }
  
  @IBAction func showSpecialSymbolsChanged(_ sender: NSButton) {
    UserDefaults.standard.showSpecialSymbols = (sender.state == .on)
  }
  
  @IBAction func showSearchFieldChanged(_ sender: NSButton) {
    UserDefaults.standard.hideSearch = (sender.state == .off)
  }
  
  private func setImageHeightRange() {
    imageHeightFormatter = NumberFormatter()
    imageHeightFormatter.minimum = imageHeightMin as NSNumber
    imageHeightFormatter.maximum = imageHeightMax as NSNumber
    imageHeightFormatter.maximumFractionDigits = 0
    imageHeightField.formatter = imageHeightFormatter
    imageHeightStepper.minValue = Double(imageHeightMin)
    imageHeightStepper.maxValue = Double(imageHeightMax)
  }
  
  private func setNumberOfItemsRange() {
    numberOfItemsFormatter = NumberFormatter()
    updateMinNumberOfItems()
    numberOfItemsFormatter.maximum = numberOfItemsMax as NSNumber
    numberOfItemsFormatter.maximumFractionDigits = 0
    numberOfItemsField.formatter = numberOfItemsFormatter
    numberOfItemsField.delegate = self
    numberOfItemsStepper.minValue = Double(numberOfItemsMin)
    numberOfItemsStepper.maxValue = Double(numberOfItemsMax)
  }
  
  func updateMinNumberOfItems() {
    if Cleepp.allowDictinctStorageSize {
      numberOfItemsFormatter.minimum = 0 as NSNumber // not numberOfItemsMin, that's enforced in delegate func
    } else {
      numberOfItemsFormatter.minimum = numberOfItemsMin as NSNumber
    }
  }
  
  func control(_ control: NSControl, textShouldEndEditing fieldEditor: NSText) -> Bool {
    guard let textField = control as? NSTextField, textField === numberOfItemsField else {
      return true
    }
    if Cleepp.allowDictinctStorageSize {
      let value = Int(fieldEditor.string) ?? 0
      if value > 0 && value < numberOfItemsMin {
        fieldEditor.string = String(numberOfItemsMin)
      }
    }
    return true
  }
  
  private func showNumberOfItemsDescription(forSimpleMode simpleMode: Bool, forZeroEntered zeroEntered: Bool) {
    numberOfItemsDescription.isHidden = !simpleMode
    numberOfItemsExtendedDescription.isHidden = simpleMode || zeroEntered
    numberOfItemsAltDescription.isHidden = simpleMode || !zeroEntered
  }
  
  private func populateImageHeight() {
    imageHeightField.integerValue =  UserDefaults.standard.imageMaxHeight
    imageHeightStepper.integerValue =  UserDefaults.standard.imageMaxHeight
  }
  
  private func populateNumberOfItems() {
    var value = UserDefaults.standard.maxMenuItems
    // when allowing separate storage setting, also allow 0, otherwise numberOfItemsMin..numberOfItemsMax
    if !Cleepp.allowDictinctStorageSize || value != 0 {
      value = max(value, numberOfItemsMin)
    }
    numberOfItemsField.integerValue = value
    numberOfItemsStepper.integerValue = value
    showNumberOfItemsDescription(forSimpleMode: !Cleepp.allowDictinctStorageSize, forZeroEntered: value == 0)
  }
  
  private func setTitleLengthRange() {
    titleLengthFormatter = NumberFormatter()
    titleLengthFormatter.minimum = titleLengthMin as NSNumber
    titleLengthFormatter.maximum = titleLengthMax as NSNumber
    titleLengthFormatter.maximumFractionDigits = 0
    titleLengthField.formatter = titleLengthFormatter
    titleLengthStepper.minValue = Double(titleLengthMin)
    titleLengthStepper.maxValue = Double(titleLengthMax)
  }
  
  private func populateTitleLength() {
    titleLengthField.integerValue = UserDefaults.standard.maxMenuItemLength
    titleLengthStepper.integerValue = UserDefaults.standard.maxMenuItemLength
  }
  
  private func setPreviewDelayRange() {
    previewDelayFormatter = NumberFormatter()
    previewDelayFormatter.minimum = previewDelayMin as NSNumber
    previewDelayFormatter.maximum = previewDelayMax as NSNumber
    previewDelayFormatter.maximumFractionDigits = 0
    previewDelayField.formatter = previewDelayFormatter
    previewDelayStepper.minValue = Double(previewDelayMin)
    previewDelayStepper.maxValue = Double(previewDelayMax)
  }
  
  private func populatePreviewDelay() {
    previewDelayField.integerValue = UserDefaults.standard.previewDelay
    previewDelayStepper.integerValue = UserDefaults.standard.previewDelay
  }
  
  private func populateShowSpecialSymbols() {
    showSpecialSymbolsButton.state = UserDefaults.standard.showSpecialSymbols ? .on : .off
  }
  
  private func showSearchOption(_ show: Bool) {
    showSearchFieldButton?.isHidden = !show
  }
  
}
