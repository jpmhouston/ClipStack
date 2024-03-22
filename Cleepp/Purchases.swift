//
//  Purchase.swift
//  ClipStack
//
//  Created by Pierre Houston on 2024-03-10.
//  Copyright © 2024 Bananameter Labs. All rights reserved.
//

import AppKit
import StoreKit
#if FOR_APP_STORE
import SwiftyStoreKit
import TPInAppReceipt
#endif

enum PurchaseItem {
  case bonus
}
enum PurchaseError: Error, CaseIterable {
  case unavailable, prohibited
  case malformedReceipt, invalidReceipt
  case unrecognized
  case cancelled, declined, noneToRestore, unreachable
  case unknown
}

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
  typealias ObservationUpdate = Result<PurchaseItem, PurchaseError>
  typealias ReceiptResult = Result<Set<PurchaseItem>, PurchaseError>
  typealias PurchaseResult = Result<Void, PurchaseError>
  private var observations: [UUID: (ObservationUpdate) -> Void] = [:]
  
  #if FOR_APP_STORE
  private var receiptValidator: AppleReceiptValidator
  
  private static let bonusProductIdentifier = "lol.bananameter.cleepp.extras"
  private static var sharedSecret: String {
    "banana" // how do we have a shared secret, and safely commit it to sourcecode?
  }
  #endif
  
  static let shared = Purchases()
  
  var hasBoughtExtras: Bool { boughtItems.contains(.bonus) }
  var boughtItems: Set<PurchaseItem> = []
  var lastError: PurchaseError?

  // MARK: -
  
  override init() {
    #if FOR_APP_STORE
    #if DEBUG
    receiptValidator = AppleReceiptValidator(service: .sandbox, sharedSecret: Purchases.sharedSecret)
    #else
    receiptValidator = AppleReceiptValidator(service: .production, sharedSecret: Purchases.sharedSecret)
    #endif
    #endif // FOR_APP_STORE
    
    super.init()
  }
  
//  override init() {
//    super.init()
//    SKPaymentQueue.default().add(self)
//  }
  
//  func addObserver(_ observer: PurchaseObserver) {
//    let id = ObjectIdentifier(observer)
//    observations[id] = Observation(observer: observer)
//  }
//  func removeObserver(_ observer: PurchaseObserver) {
//    let id = ObjectIdentifier(observer)
//    observations.removeValue(forKey: id)
//  }
//  var observers: [PurchaseObserver] {
//    // while fetching weakly held observers, also remove observations whose observers are gone
//    let verifyObservations = observations // is making this copy necessary? original modified within map below
//    return verifyObservations.compactMap { (id, observation) in
//      if let observer = observation.observer {
//        return observer
//      } else {
//        observations.removeValue(forKey: id)
//        return nil
//      }
//    }
//  }
  
  @discardableResult
  func start<T: AnyObject>(withObserver observer: T, callback: @escaping (T, ObservationUpdate) -> Void) -> ObservationToken {
    let token = addObserver(observer, callback: callback)
    start()
    return token
  }
  
  func start() {
    #if BONUS_FEATUES_ON
    boughtItems.insert(.bonus)
    callObservers(withUpdate: .success(.bonus))
    #elseif !FOR_APP_STORE
    callObservers(withUpdate: .failure(.prohibited))
    #else
    
    SwiftyStoreKit.completeTransactions(atomically: false, completion: completeTransactionsAtLaunchCallback)
    
    if case .success(let items) = checkReceipt() {
      for item in items {
        callObservers(withUpdate: .success(item))
      }
    }
    
    #endif // FOR_APP_STORE
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
  
  // MARK: -
  
  func buyExtras() -> PurchaseResult {
    #if FOR_APP_STORE
    guard SKPaymentQueue.canMakePayments() else {
      return .failure(.prohibited)
    }
    // ...
    return .success(())
    #else
    return .failure(.prohibited)
    #endif
  }
  
  func restore() -> ReceiptResult {
    #if FOR_APP_STORE
    guard SKPaymentQueue.canMakePayments() else {
      return .failure(.prohibited)
    }
    
    switch checkReceipt() {
    case .success(let items):
      if items.contains(.bonus) {
        return .success(items)
      }
    case .failure(_):
      // ignore this error and proceed to try refreshing/restoring
      break
    }
    
    //refreshReceipt() {
    //  if ... {
    //    restorePurchases()
    //  }
    //}
    
    return .success([])
    #else
    return .failure(.prohibited)
    #endif
  }
  
  // remove all of these:
//  static var errorSampler: PurchaseError = .cancelled
//  static func nextError() {
//    let curr = PurchaseError.allCases.firstIndex(of: Self.errorSampler) ?? 0
//    let next = (curr + 1) % PurchaseError.allCases.count
//    Self.errorSampler = PurchaseError.allCases[next]
//  }
  
  static func buyExtras(callback: @escaping (_ error: PurchaseError?) -> Void) {
    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
      //if Self.errorSampler == .noneToRestore { Self.nextError() }
      callback(nil)
      //Self.nextError()
    }
  }
  
  static func restore(callback: @escaping (_ error: PurchaseError?) -> Void) {
    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
      callback(nil)
      //Self.nextError()
    }
  }
  
  static func verify(callback: @escaping (_ updated: Bool) -> Void) {
    DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
      callback(true)
    }
  }
  
  func callObservers(withUpdate update: ObservationUpdate) {
    observations.values.forEach { closure in
      closure(update)
    }
  }
  
  // MARK: -
  
  #if FOR_APP_STORE
  
  @discardableResult
  private func checkReceipt() -> ReceiptResult {
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
      
      if receipt.containsPurchase(ofProductIdentifier: Self.bonusProductIdentifier) {
        boughtItems.insert(.bonus)
      }
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
          // TODO: finished this. probably pass in a completion closure and call it here
          break
        case .failure(_ /*let error*/):
          // TODO: finished this
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
      if results.restoreFailedPurchases.count > 0 {
        print("Restore Failed: \(results.restoreFailedPurchases)")
        // TODO: finished this. probably pass in a completion closure and call it here
      } else if results.restoredPurchases.count > 0 {
        print("Restore Success: \(results.restoredPurchases)")
        // TODO: finished this
      } else {
        print("Nothing to Restore")
        // TODO: finished this
      }
    }
  }
  
  private func completeTransactionsAtLaunchCallback(withPurchases purchases: [Purchase]) {
    for purchase in purchases {
      switch purchase.transaction.transactionState {
      case .purchased, .restored:
        if purchase.needsFinishTransaction {
          SwiftyStoreKit.finishTransaction(purchase.transaction)
        }
        
        SwiftyStoreKit.verifyReceipt(using: receiptValidator, forceRefresh: false) { [weak self] result in
          switch result {
          case .success(let receipt):
            print("Verify receipt success: \(receipt)")
            if purchase.productId == Self.bonusProductIdentifier {
              self?.boughtItems.insert(.bonus)
              self?.callObservers(withUpdate: .success(.bonus))
              self?.lastError = nil
            } else {
              self?.callObservers(withUpdate: .failure(.unrecognized))
              self?.lastError = .unrecognized
            }
            
          case .error(let error):
            print("Verify receipt failed: \(error)")
            self?.callObservers(withUpdate: .failure(.invalidReceipt))
            self?.lastError = .invalidReceipt
          }
        }
        
      case .failed:
        print("Purchase failed: \(purchase.productId), \(purchase.transaction.transactionIdentifier ?? "unknown transaction")")
        callObservers(withUpdate: .failure(.unknown))
        lastError = .unknown
        
      case .purchasing, .deferred:
        break
      @unknown default:
        break
      }
    }
  }
  
  #endif // FOR_APP_STORE
  
}
