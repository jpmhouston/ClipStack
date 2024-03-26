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
  private var cancelToken: Purchases.ObservationToken?
  private var state: State = .idle
  #if DEBUG
  private var showBonusFeaturesPurchased = false
  #else
  private var showBonusFeaturesPurchased: Bool { purchases.hasBoughtExtras }
  #endif
  
  private var labelsToStyle: [NSTextField] { [featureLabel1, featureLabel2, featureLabel3, featureLabel4] }
  private var errorMessageColor: NSColor?
  
  @IBOutlet weak var pleasePurchaseLabel: NSTextField!
  @IBOutlet weak var havePurchasedLabel: NSTextField!
  @IBOutlet weak var featureLabel1: NSTextField!
  @IBOutlet weak var featureLabel2: NSTextField!
  @IBOutlet weak var featureLabel3: NSTextField!
  @IBOutlet weak var featureLabel4: NSTextField!
  @IBOutlet weak var purchaseButton: NSButton!
  @IBOutlet weak var restoreButton: NSButton!
  @IBOutlet weak var progressIndicator: NSProgressIndicator!
  @IBOutlet weak var messageLabel: NSTextField!
  
  // MARK: -
  
  override func viewDidLoad() {
    super.viewDidLoad()
    styleLabels()
  }
  
  override func viewWillAppear() {
    super.viewWillAppear()
    
    #if DEBUG
    showBonusFeaturesPurchased = false // TODO: reset state for testing, to be removed
    #endif
    
    updateTitleLabel()
    updatePurchaseButtons()
    clearMessage()
    
    cancelToken = purchases.addObserver(self, callback: { [weak self] s, update in
      guard let self = self, self == s else {
        return
      }
      self.purchasesUpdated(update)
    })
  }
  
  override func viewWillDisappear() {
    cancelTimeoutTimer()
    
    if let token = cancelToken {
      purchases.removeObserver(token)
      cancelToken = nil
    }
  }
  
  // MARK: -
  
  func purchasesUpdated(_ update: Purchases.ObservationUpdate) {
    
  }
  
  @IBAction
  func purchase(_ sender: AnyObject) {
    #if DEBUG
    messageLabel.stringValue = "All features already enabled. Purchases will work in the 1.0 App Store version. Try the other button."
    #endif
    
  }
  
  @IBAction
  func restorePurchases(_ sender: AnyObject) {
    disablePurchaseButtons()
    clearMessage()
    
    progressIndicator.startAnimation(sender)
    Purchases.restore() { [weak self] result in
      guard let self = self else {
        return
      }
      progressIndicator.stopAnimation(self)
      
      #if DEBUG
      showBonusFeaturesPurchased = true
      displayError("For now this just exercises the 2 states of this window. Purchases will work in the 1.0 App Store version.")
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
  
  private func disablePurchaseButtons() {
    purchaseButton.isEnabled = !showBonusFeaturesPurchased
    restoreButton.isEnabled = !showBonusFeaturesPurchased
  }
  
  private func updatePurchaseButtons() {
    purchaseButton.isEnabled = !showBonusFeaturesPurchased
    restoreButton.isEnabled = !showBonusFeaturesPurchased
  }
  
  private func clearMessage() {
    messageLabel.stringValue = ""
  }
  
  private func displayMessage(_ message: String) {
    messageLabel.stringValue = message
    messageLabel.textColor = nil
  }
  
  private func displayError(_ message: String) {
    messageLabel.stringValue = message
    messageLabel.textColor = errorMessageColor
  }
  
  private func styleLabels() {
    errorMessageColor = messageLabel.textColor
    
    for label in labelsToStyle {
      let styled = NSMutableAttributedString(attributedString: label.attributedStringValue)
      styled.applySimpleStyles(basedOnFont: label.font ?? NSFont.labelFont(ofSize: NSFont.labelFontSize))
      label.attributedStringValue = styled
    }
  }
  
}
