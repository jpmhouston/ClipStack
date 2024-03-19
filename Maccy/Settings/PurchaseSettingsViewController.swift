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
  #if DEBUG
  private var showBonusFeaturesPurchased = false
  #else
  private var showBonusFeaturesPurchased: Bool { purchases.hasBoughtExtras }
  #endif
  
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
    #if DEBUG
    showBonusFeaturesPurchased = false // TODO: reset state for testing, to be removed
    #endif
    
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
    #if DEBUG
    errorLabel.stringValue = "All features already enabled. Purchases will work in the 1.0 App Store version. Try the other button."
    #endif
    
//    purchaseButton.isEnabled = false
//    restoreButton.isEnabled = false
//    errorLabel.stringValue = ""
//    
//    progressIndicator.startAnimation(sender)
//    Purchase.purchaseExtras() { [weak self] result in
//      guard let self = self else {
//        return
//      }
//      progressIndicator.stopAnimation(self)
//
//      // maybe want something like:
//      updateTitleLabel()
//      updatePurchaseButtons()
//      switch result {
//      case .failure(.cancelled):
//        break
//      case .failure(.networkFailure):
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
    Purchases.restore() { [weak self] result in
      guard let self = self else {
        return
      }
      progressIndicator.stopAnimation(self)
      
      #if DEBUG
      showBonusFeaturesPurchased = true
      errorLabel.stringValue = "For now this just exercises the 2 states of this window. Purchases will work in the 1.0 App Store version."
      updatePurchaseButtons()
      updateTitleLabel()
      #endif
      
//      // maybe want something like:
//      updateTitleLabel()
//      updatePurchaseButtons()
//      switch result {
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
    pleasePurchaseLabel.isHidden = showBonusFeaturesPurchased
    havePurchasedLabel.isHidden = !showBonusFeaturesPurchased
  }
  
  private func updatePurchaseButtons() {
    purchaseButton.isEnabled = !showBonusFeaturesPurchased
    restoreButton.isEnabled = !showBonusFeaturesPurchased
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
