//
//  Purchase.swift
//  ClipStack
//
//  Created by Pierre Houston on 2024-03-10.
//  Copyright © 2024 Bananameter Labs. All rights reserved.
//

import AppKit
import StoreKit
import SwiftyStoreKit
import TPInAppReceipt

class Purchases: NSObject {
  // observer scheme described in https://www.swiftbysundell.com/articles/observers-in-swift-part-2/
  class ObservationToken {
      private let cancellationClosure: () -> Void
      init(cancellationClosure: @escaping () -> Void) {
          self.cancellationClosure = cancellationClosure
      }
      func cancel() {
          cancellationClosure()
      }
  }
  
  enum Item {
    case bonus
  }
  
  struct ProductDetail {
    var identifier: String
    var localizedDescription: String
    var localizedPrice: String
  }
  
  enum UpdateItem {
    case purchases(Set<Item>)
    case restorations(Set<Item>)
    case products([ProductDetail])
  }
  
  enum PurchaseError: Error, CaseIterable {
    case unavailable, prohibited
    case malformedReceipt, invalidReceipt
    //case unrecognized
    case cancelled, declined, noneToRestore, unreachable
    case unknown
  }
  
  typealias ObservationUpdate = Result<UpdateItem, PurchaseError>
  typealias ReceiptResult = Result<Set<Item>, PurchaseError>
  typealias ImmediateResult = Result<Void, PurchaseError>
  
  static let shared = Purchases()
  private var observations: [UUID: (ObservationUpdate) -> Void] = [:]
  
  // can we avoid hardcoding the product id's we expect, be driven entirely by the
  // product details received? should the one(s) that link to purchasing the bonus features
  // be tagged with some substring in the id? for now, any item gives the user the bonus
  //private static let bonusProductIdentifier = "lol.bananameter.cleepp.extras"
  
  var hasBoughtExtras: Bool { boughtItems.contains(.bonus) }
  var boughtItems: Set<Item> = []
  var lastError: PurchaseError? // possibly not needed

  // MARK: -
  
  @discardableResult
  func start<T: AnyObject>(withObserver observer: T, callback: @escaping (T, ObservationUpdate) -> Void) -> ObservationToken {
    let token = addObserver(observer, callback: callback)
    start()
    return token
  }
  
  func start() {
    SwiftyStoreKit.completeTransactions(atomically: true, completion: completeTransactionsCallback)
    
    switch checkLocalReceipt() {
    case .success(let items):
      callObservers(withUpdate: .success(.purchases(items)))
    case .failure(let err):
      callObservers(withUpdate: .failure(err))
    }
  }
  
  func finish(andRemoveObserver token: ObservationToken? = nil) {
    if let token = token {
      token.cancel()
    }
    // anything needed to cleanup use of swiftystorekit?
  }
  
  @discardableResult
  func addObserver<T: AnyObject>(_ observer: T, callback: @escaping (T, ObservationUpdate) -> Void) -> ObservationToken {
    let id = UUID()
    observations[id] = { [weak self, weak observer] update in
      guard let observer = observer else {
        self?.observations.removeValue(forKey: id)
        return
      }
      callback(observer, update)
    }
    return ObservationToken { [weak self] in
        self?.observations.removeValue(forKey: id)
    }
  }
  
  func removeObserver(_ token: ObservationToken) {
    token.cancel()
  }
  
  func askForReview() {
    // TODO: count times entering this function, only ask the Nth time
    AppStoreReview.ask()
  }
  
  // MARK: -
  
  func startFetchingProductDetails() throws {
    guard SKPaymentQueue.canMakePayments() else {
      throw PurchaseError.prohibited
    }
    
    // temp test code:
    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
      self?.callObservers(withUpdate: .success(.products([
        ProductDetail(identifier: "lol.bananameeter.cleepp.bonusfeatures", localizedDescription: "Bonus Features", localizedPrice: "$3.99")
      ])))
    }
  }
  
  func startPurchase(_ identifer: String) throws {
    guard SKPaymentQueue.canMakePayments() else {
      throw PurchaseError.prohibited
    }
    
    // temp test code:
    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
      self?.boughtItems.insert(.bonus)
      self?.callObservers(withUpdate: .success(.purchases([.bonus])))
    }
  }
  
  func startRestore() throws {
    guard SKPaymentQueue.canMakePayments() else {
      throw PurchaseError.prohibited
    }
    
    // temp test code:
    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
      self?.boughtItems.insert(.bonus)
      self?.callObservers(withUpdate: .success(.restorations([.bonus])))
    }
    
    // probably don't bother redoing checkLocalReceipt() here, it was done at launch
    // and we always want to hit apple's servers to guarantee we're in sync
//    switch checkLocalReceipt() {
//    case .success(let items):
//      if items.contains(.bonus) {
//        //return .success(items)
//      }
//    case .failure(_):
//      // ignore this error and proceed to try refreshing/restoring
//      break
//    }
    
    //refreshReceipt() {
    //  if ... {
    //    restorePurchases() {
    //
    //    }
    //  }
    //}
  }
  
  func callObservers(withUpdate update: ObservationUpdate) {
    observations.values.forEach { closure in
      closure(update)
    }
  }
  
  // MARK: -
  
  @discardableResult
  private func checkLocalReceipt() -> ReceiptResult {
    boughtItems = []
    guard let receiptData = SwiftyStoreKit.localReceiptData else {
      return .failure(.unavailable)
    }
    return validateReceipt(receiptData)
  }
  
  func validateReceipt(_ receiptData: Data) -> ReceiptResult {
    let errorValue: PurchaseError
    do {
      let receipt = try InAppReceipt(receiptData: receiptData)
      try receipt.validate()
      // instead of comparing against a well-known product id, any purchase gets the user the bonus
      boughtItems.insert(.bonus)
      return .success([.bonus])
      
    } catch IARError.initializationFailed { // let error as IARError.initializationFailed(let reason) .. doesn't work :(
      print("Receipt validation failed during initialization") // \(error)")
      errorValue = .malformedReceipt
    } catch IARError.validationFailed { // let error as IARError.validationFailed(let reason)
      print("Receipt validation unsuccessful") // \(error)")
      errorValue = .invalidReceipt
    } catch {
      print("Unknown error during local receipt validation: \(error)")
      errorValue = .unknown
    }
    lastError = errorValue
    return .failure(errorValue)
  }
  
  func refreshReceipt() {
    SwiftyStoreKit.fetchReceipt(forceRefresh: true) { [weak self] result in
      switch result {
      case .success(let receiptData):
        switch self?.validateReceipt(receiptData) {
        case .success(_ /*let items*/):
          // TODO: finish this, probably pass in a completion closure and call it here
          break
        case .failure(_ /*let error*/):
          // TODO: finish this
          break
        case nil:
          break
        }
        
      case .error(let error):
        print("Fetch receipt failed: \(error)")
      }
    }
  }
  
  func restorePurchases() {
    SwiftyStoreKit.restorePurchases(atomically: true) { results in
      if results.restoredPurchases.count > 0 {
        print("Restore Success: \(results.restoredPurchases)")
        // TODO: finish this, probably pass in a completion closure and call it here
        
      } else if results.restoreFailedPurchases.count > 0 {
        print("Restore Failed: \(results.restoreFailedPurchases)")
        // TODO: finish this
      } else {
        print("Nothing to Restore")
        // TODO: finish this
      }
    }
  }
  
  private func completeTransactionsCallback(withPurchases purchases: [Purchase]) {
    // TODO: probably should consolidate set of successful purchases with and failures and make just 1 call to observers
    // and make ObservationUpdate value be an enum: transactions([Purchase]), products([ProductDetails])
    
    for purchase in purchases {
      switch purchase.transaction.transactionState {
      case .purchased:
        // when should we validate purchase receipts??
        
        // instead of comparing against a well-known product id, any purchase gets the user the bonus
        boughtItems.insert(.bonus)
        callObservers(withUpdate: .success(.purchases([.bonus])))
        lastError = nil
        
        if purchase.needsFinishTransaction {
          SwiftyStoreKit.finishTransaction(purchase.transaction)
        }
        
      case .restored:
        boughtItems.insert(.bonus)
        callObservers(withUpdate: .success(.restorations([.bonus])))
        lastError = nil
        
        if purchase.needsFinishTransaction {
          SwiftyStoreKit.finishTransaction(purchase.transaction)
        }
        
      case .failed:
        print("Purchase failed: \(purchase.productId), \(purchase.transaction.transactionIdentifier ?? "unknown transaction")")
        callObservers(withUpdate: .failure(.unknown))
        lastError = .unknown
        
      case .purchasing, .deferred:
        // TODO: look into these cases and see if we need to do anything
        break
      @unknown default:
        break
      }
    }
  }
  
}
