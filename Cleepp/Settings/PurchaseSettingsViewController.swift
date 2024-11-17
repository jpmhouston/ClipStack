//
//  PurchaseSettingsViewController.swift
//  Cleepp
//
//  Created by Pierre Houston on 2024-03-10.
//  Copyright © 2024 Bananameter Labs. All rights reserved.
//

import AppKit
import Settings
import os.log

class PurchaseSettingsViewController: NSViewController, SettingsPane {
  
  public let paneIdentifier = Settings.PaneIdentifier.purchase
  public let paneTitle = NSLocalizedString("preferences_purchase", comment: "")
  public let toolbarItemIcon = NSImage(named: .gift)!
  
  override var nibName: NSNib.Name? { "PurchaseSettingsViewController" }
  
  enum State {
    case idle, fetchingProducts, showingProducts, purchasing, restoring
  }
  
  private let purchaseManager: Purchases
  private var productWindowController: PurchaseDetailWindowController?
  
  private var cancelToken: Purchases.ObservationToken?
  private var timeoutTimer: DispatchSourceTimer?
  private var state: State = .idle
  private var showBonusFeaturesPurchased: Bool { purchaseManager.hasBoughtExtras }
  
  private var labelsToStyle: [NSTextField] { [featureLabel1, featureLabel2, featureLabel3, featureLabel4, documentationLabel] }
  private var errorMessageColor: NSColor?
  
  @IBOutlet weak var pleasePurchaseLabel: NSTextField!
  @IBOutlet weak var havePurchasedLabel: NSTextField!
  @IBOutlet weak var featureLabel1: NSTextField!
  @IBOutlet weak var featureLabel2: NSTextField!
  @IBOutlet weak var featureLabel3: NSTextField!
  @IBOutlet weak var featureLabel4: NSTextField!
  @IBOutlet weak var documentationLabel: NSTextField!
  @IBOutlet weak var purchaseButton: NSButton!
  @IBOutlet weak var altPurchaseButton: NSButton!
  @IBOutlet weak var restoreButton: NSButton!
  @IBOutlet weak var progressIndicator: NSProgressIndicator!
  @IBOutlet weak var messageLabel: NSTextField!
  
  // MARK: -
  
  init(purchases: Purchases) {
    purchaseManager = purchases
    super.init(nibName: nil, bundle: nil)
  }
  
  private init() {
    fatalError("init(purchases:) must be used instead of init()")
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  override func viewDidLoad() {
    super.viewDidLoad()
    styleLabels()
  }
  
  override func viewWillAppear() {
    super.viewWillAppear()
    
    updateTitleLabel()
    updatePurchaseButtons()
    clearMessage()
    state = .idle
    
    cancelToken = purchaseManager.addObserver(self, callback: { [weak self] s, update in
      guard let self = self, self == s else {
        return
      }
      self.purchasesUpdated(update)
    })
  }
  
  override func viewWillDisappear() {
    state = .idle
    cancelTimeoutTimer()
    
    if let token = cancelToken {
      purchaseManager.removeObserver(token)
      cancelToken = nil
    }
  }
  
  // MARK: -
  
  func purchasesUpdated(_ update: Purchases.ObservationUpdate) {
    self.progressIndicator.stopAnimation(self)
    
    // TODO: localize all these
    
    switch (update, state) {
    case (.success(.products(let products)), .fetchingProducts):
      cancelTimeoutTimer()
      clearMessage()
      showConfirmationSheet(withProducts: products)
      return
    case (.success(.products(_)), _):
      return
      
    case (.success(.purchases(_)), .purchasing):
      displayMessage("Thank you!")
    case (.success(.purchases(_)), .showingProducts):
      cancelConfirmationSheet()
      fallthrough
    case (.success(.purchases(_)), _):
      displayMessage("Delayed purchase has completed, thank you!")
      
    case (.success(.restorations(_)), .restoring):
      displayMessage("Purchase restored and you've got the bonus features, thank you!")
    case (.success(.restorations(_)), .showingProducts):
      cancelConfirmationSheet()
      fallthrough
    case (.success(.restorations(_)), _):
      displayMessage("Delayed purchase restoration has completed and you've got the bonus features, thank you!")
      
    case (.failure(.cancelled), let s) where s != .idle:
      displayMessage("Cancelled")
    
    case (.failure(.unreachable), .fetchingProducts):
      displayError("Failed to reach network and fetch the purchase details")
    case (.failure(.unreachable), .purchasing):
      displayError("Failed to reach network and complete the purchase")
    case (.failure(.unreachable), .restoring):
      displayError("Failed to reach network and complete the restore")
    case (.failure(_), .fetchingProducts):
      displayError("Failed to fetch the purchase details")
    case (.failure(_), .purchasing):
      displayError("Failed to complete the purchase")
    case (.failure(_), .restoring):
      displayError("Failed to complete the restore")
      
    default:
      break
    }
    
    state = .idle
    cancelTimeoutTimer()
    updateTitleLabel()
    updatePurchaseButtons()
  }
  
  @IBAction
  func showProducts(_ sender: AnyObject) {
    // fetch products, when its done purchasesUpdated shows alert/sheet with product(s) & price(s)
    disablePurchaseButtons()
    do {
      #if DEBUG
      if NSEvent.modifierFlags.contains(.option) {
        try purchaseManager.startFetchingDummyProductDetails()
      } else {
        try purchaseManager.startFetchingProductDetails()
      }
      #else
      try purchaseManager.startFetchingProductDetails()
      #endif
    } catch {
      displayError(error.localizedDescription)
      updatePurchaseButtons()
      return
    }
    
    state = .fetchingProducts
    displayMessage("Fetching product details") // TODO: localize
    startWaitingForCompletion(withTimeout: 10, message: "Retrieval of product details delayed") // TODO: localize
  }
  
  private func showConfirmationSheet(withProducts products: [Purchases.ProductDetail]) {
    guard !products.isEmpty else {
      displayError("Purchases unavailable at the moment, please again another time") // TODO: localize
      updatePurchaseButtons()
      return
    }
    
    clearMessage()
    
    productWindowController = PurchaseDetailWindowController.createFromNib()
    productWindowController?.products = products
    productWindowController?.purchases = purchaseManager.boughtItems
    guard let settingsWindow = view.window, let productWindow = productWindowController?.window else {
      os_log(.default, "failed to instantiate the products detail sheet")
      updatePurchaseButtons()
      return
    }
    
    state = .showingProducts
    
    settingsWindow.beginSheet(productWindow) { [weak self] response in
      guard let self = self else { return }
      
      let product = productWindowController?.chosenProduct
      productWindowController = nil
      
      if response != .cancel, let product = product {
        displayError("Closed sheet with Buy button, \(product.identifier)")
        
        performPurchase(product)
      } else {
        updatePurchaseButtons()
      }
    }
  }
  
  private func cancelConfirmationSheet() {
    guard let settingsWindow = view.window, let productWindow = productWindowController?.window else {
      os_log(.default, "No products detail sheet found to dismiss")
      return
    }
    settingsWindow.endSheet(productWindow)
  }
  
  func performPurchase(_ product: any Purchases.ProductDetail) {
    do {
      try purchaseManager.startPurchase(product)
    } catch {
      displayError("Something went wrong, unable to purchase") // TODO: localize
      updatePurchaseButtons()
      return
    }
    
    state = .purchasing
    displayMessage("Completing purchase") // TODO: localize
    startWaitingForCompletion(withTimeout: 60, message: "Purchase completion delayed") // TODO: localize
  }
  
  @IBAction
  func restorePurchases(_ sender: AnyObject) {
    disablePurchaseButtons()
    do {
      try purchaseManager.startRestore()
    } catch {
      displayError("Something went wrong, unable to restore previous purchases") // TODO: localize
      updatePurchaseButtons()
      return
    }
    
    state = .restoring
    displayMessage("Attempting to restoring purchases") // TODO: localize
    startWaitingForCompletion(withTimeout: 60, message: "Restoration of previous purchases delayed") // TODO: localize
  }
  
  private func startWaitingForCompletion(withTimeout timeout: Double, message: String, asError: Bool = false) {
    progressIndicator.startAnimation(self)

    startTimeoutTimer(withDuration: timeout) { [weak self] in
      guard let self = self else { return }
      
      progressIndicator.stopAnimation(self)
      state = .idle
      updatePurchaseButtons()
      if asError {
        displayError(message)
      } else {
        displayMessage(message)
      }
    }
  }
  
  // MARK: -
  
  private func startTimeoutTimer(withDuration duration: Double, timeout: @escaping () -> Void) {
    if timeoutTimer != nil {
      cancelTimeoutTimer()
    }
    timeoutTimer = DispatchSource.scheduledTimerForRunningOnMainQueue(afterDelay: duration) { [weak self] in
      self?.timeoutTimer = nil // doing this before calling closure supports closure itself calling startTimeoutTimer, fwiw
      timeout()
    }
  }
  
  private func cancelTimeoutTimer() {
    timeoutTimer?.cancel()
    timeoutTimer = nil
  }
  
  private func updateTitleLabel() {
    pleasePurchaseLabel.isHidden = showBonusFeaturesPurchased
    havePurchasedLabel.isHidden = !showBonusFeaturesPurchased
  }
  
  private func disablePurchaseButtons() {
    purchaseButton.isEnabled = false
    altPurchaseButton.isEnabled = false
    restoreButton.isEnabled = false
  }
  
  private func updatePurchaseButtons() {
    purchaseButton.isEnabled = true
    altPurchaseButton.isEnabled = true
    purchaseButton.isHidden = showBonusFeaturesPurchased
    altPurchaseButton.isHidden = !showBonusFeaturesPurchased
    restoreButton.isEnabled = true
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
    
    // assume any link styles needing a default URL want a link to the bonus features section of the website
    for label in labelsToStyle {
      let styled = NSMutableAttributedString(attributedString: label.attributedStringValue)
      let font = label.font ?? NSFont.labelFont(ofSize: NSFont.labelFontSize)
      styled.applySimpleStyles(basedOnFont: font, withLink: Cleepp.homepageBonusDocsURL)
      label.attributedStringValue = styled
    }
  }
  
}
