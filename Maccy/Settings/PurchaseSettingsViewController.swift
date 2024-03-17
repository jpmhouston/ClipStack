//
//  PurchaseSettingsViewController.swift
//  ClipStack
//
//  Created by Pierre Houston on 2024-03-10.
//  Copyright © 2024 Bananameter Labs. All rights reserved.
//

import AppKit
import Settings

class PurchaseSettingsViewController: NSViewController, SettingsPane {
  
  public let paneIdentifier = Settings.PaneIdentifier.purchase
  public let paneTitle = NSLocalizedString("preferences_purchase", comment: "")
  public let toolbarItemIcon = NSImage(named: .currency)!
  
  override var nibName: NSNib.Name? { "PurchaseSettingsViewController" }
  
  private let purchases = Purchases.shared
  private var token: Purchases.ObservationToken?
  
  @IBOutlet weak var pleasePurchaseLabel: NSTextField!
  @IBOutlet weak var havePurchasedLabel: NSTextField!
  @IBOutlet weak var featureLabel1: NSTextField!
  @IBOutlet weak var featureLabel2: NSTextField!
  @IBOutlet weak var featureLabel3: NSTextField!
  @IBOutlet weak var featureLabel4: NSTextField!
  @IBOutlet weak var purchaseButton: NSButton!
  @IBOutlet weak var restoreButton: NSButton!
  @IBOutlet weak var progressIndicator: NSProgressIndicator!
  @IBOutlet weak var errorLabel: NSTextField!
  
  var labelsToStyle: [NSTextField] { [featureLabel1, featureLabel2, featureLabel3, featureLabel4] }
  
  // MARK: -
  
  override func viewDidLoad() {
    super.viewDidLoad()
    styleLabels()
  }
  
  override func viewWillAppear() {
    // TODO: reset state for testing, to be removed
    purchases.hasBoughtExtras = false
    
    token = purchases.addObserver(self, callback: { [weak self] s, update in
      guard let self = self, self == s else {
        return
      }
      self.purchasesUpdated(update)
    })
    
    super.viewWillAppear()
    updateTitleLabel()
    updatePurchaseButtons()
    clearError()
  }
  
  override func viewWillDisappear() {
    
  }
  
  // MARK: -
  
  func purchasesUpdated(_ update: Purchases.ObservationUpdate) {
    
  }
  
  @IBAction
  func purchase(_ sender: AnyObject) {
    errorLabel.stringValue = "All features already enabled. Purchases will work in the 1.0 App Store version. Try the other button."
    
//    purchaseButton.isEnabled = false
//    restoreButton.isEnabled = false
//    errorLabel.stringValue = ""
//    
//    progressIndicator.startAnimation(sender)
//    Purchase.purchaseExtras() { [weak self] error in
//      guard let self = self else {
//        return
//      }
//      progressIndicator.stopAnimation(self)
//      updatePurchaseButtons()
//      updateTitleLabel()
//      // maybe want something like:
//      switch error {
//      case nil:
//        updateTitleLabel()
//      case .cancelled:
//        break
//      case .networkFailure:
//        displayError("Failed to reach network and complete purchase")
//      default:
//        displayError("Failed to complete purchase")
//      }
//    }
  }
  
  @IBAction
  func restorePurchases(_ sender: AnyObject) {
    purchaseButton.isEnabled = false
    restoreButton.isEnabled = false
    errorLabel.stringValue = ""
    
    progressIndicator.startAnimation(sender)
    Purchases.restore() { [weak self] error in
      guard let self = self else {
        return
      }
      progressIndicator.stopAnimation(self)
      
      // TODO: hardcode success, to be removed
      // its just a dummy error value for now anyway, ignore it and switch to Purchased
      purchases.hasBoughtExtras = true
      errorLabel.stringValue = "For now this just exercises the 2 states of this window. Purchases will work in the 1.0 App Store version."
      
      updatePurchaseButtons()
      updateTitleLabel()
//      // maybe want something like:
//      switch error {
//      case nil:
//        updateTitleLabel()
//      case .cancelled:
//        break
//      case .noneToRestore:
//        displayError("No purchases found for the logged in Mac App Store user")
//      case .networkFailure:
//        displayError("Failed to reach network and restore any purchases")
//      default:
//        displayError("Failed to restore any purchases")
//      }
    }
  }
  
  // MARK: -
  
  private func updateTitleLabel() {
    pleasePurchaseLabel.isHidden = purchases.hasBoughtExtras
    havePurchasedLabel.isHidden = !purchases.hasBoughtExtras
  }
  
  private func updatePurchaseButtons() {
    purchaseButton.isEnabled = !purchases.hasBoughtExtras
    restoreButton.isEnabled = !purchases.hasBoughtExtras
  }
  
  private func clearError() {
    errorLabel.stringValue = ""
  }
  
  private func displayError(_ message: String) {
    errorLabel.stringValue = message
  }
  
  private func styleLabels() {
    for label in labelsToStyle {
      let styled = NSMutableAttributedString(attributedString: label.attributedStringValue)
      styled.applySimpleStyles(basedOnFont: label.font ?? NSFont.labelFont(ofSize: NSFont.labelFontSize))
      label.attributedStringValue = styled
    }
  }
  
}
