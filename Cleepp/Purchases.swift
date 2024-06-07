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
    case prohibited
    case malformedReceipt, invalidReceipt
    case unreachable, unknown
    //case unrecognized, unavailable, noneToRestore
    //case cancelled, declined
  }
  
  typealias ObservationUpdate = Result<UpdateItem, PurchaseError>
  typealias ReceiptResult = Result<Set<Item>, PurchaseError>
  typealias ImmediateResult = Result<Void, PurchaseError>
  
  private var observations: [UUID: (ObservationUpdate) -> Void] = [:]
  
  // can we avoid hardcoding the product id's we expect, be driven entirely by the
  // product details received? should the one(s) that link to purchasing the bonus features
  // be tagged with some substring in the id? for now, any item gives the user the bonus
  //private static let bonusProductIdentifier = "lol.bananameter.batchclip.extras"
  
  var hasBoughtExtras: Bool { boughtItems.contains(.bonus) }
  var boughtItems: Set<Item> = []
  var lastError: PurchaseError? // possibly not needed
  var reviewFunctionCounter = 0

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
    
    refreshReceipt() { [weak self] refreshResult in
      guard let self = self else { return }
      
      switch refreshResult {
      case .success(let items) where items.count > 0:
        callObservers(withUpdate: .success(.restorations(items)))
        
      case .success(_): // does this matching pattern work?
        restorePurchases()
        
//        restorePurchases() { [weak self] restoreResult in
//          guard let self = self else { return }
//          
//          switch restoreResult {
//          case .success(let items):
//            callObservers(withUpdate: .success(.restorations(items))) // oh completeTransactionsCallback does this
//          case .failure(let error):
//            callObservers(withUpdate: .failure(error))
//          }
//        }
        
      default:
        break
      }
    }
    
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
      return .success([])
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
      
    } catch IARError.initializationFailed {
      // catch let error as IARError.initializationFailed(reason) .. can swift let us do this?
      print("Failure validating receipt: validator itself")
      errorValue = .malformedReceipt
      
    } catch IARError.validationFailed {
      // catch let error as IARError.validationFailed(reason)
      print("Failure validating receipt: did not validate")
      errorValue = .invalidReceipt
      
    } catch {
      print("Unknown error during local receipt validation: \(error)") // TODO: either ditch logging these or improve the manner & messages
      errorValue = .unknown
    }
    
    lastError = errorValue
    return .failure(errorValue)
  }
  
  func refreshReceipt(_ completion: @escaping (ReceiptResult)->Void) {
    SwiftyStoreKit.fetchReceipt(forceRefresh: true) { [weak self] fetchResult in
      guard let self = self else { return }
      
      switch fetchResult {
      case .success(let receiptData):
        let validationResult = self.validateReceipt(receiptData)
        completion(validationResult)
        
      case .error(.noReceiptData), .error(.noRemoteData),
           .error(.receiptInvalid(_, .subscriptionExpired)):
        completion(.success([]))
        
      case .error(.networkError(let osError)):
        print("Network failure fetching receipts: \(osError)")
        completion(.failure(.unreachable))
        
      case .error(.receiptInvalid(_, .receiptServerUnavailable)):
        print("Failure fetching receipts: some apple server reported to be down")
        completion(.failure(.unreachable))
        
      case .error(let error):
        print("Failure fetching receipts: \(error)") // TOOD: either ditch logging these or improve the manner & messages
        // perhaps this error case shouldn't be named "unknown", maybe "other"
        completion(.failure(.unknown))
      }
    }
  }
  
  func restorePurchases() { // _ completion: @escaping (ReceiptResult)->Void
    SwiftyStoreKit.restorePurchases(atomically: true) { [weak self] restoreResult in
      guard let self = self else { return }
      
      if restoreResult.restoredPurchases.count > 0 {
        print("Success restoring purchases: \(restoreResult.restoredPurchases)")
        // validation and invoking observers done in completeTransactionsCallback, does that make sense?
        //completion(.success([]))
        
      } else if restoreResult.restoreFailedPurchases.count > 0 {
        print("Failure restoring purchases: \(restoreResult.restoreFailedPurchases)")
        // invoking observers on failure in completeTransactionsCallback too? maybe don't need a completion parameter
        //completion(.failure(.unknown)) // TODO: what error
        
      } else {
        print("Nothing to Restore")
        // if no call to completeTransactionsCallback occurs in this case, invoke observers here?
        //completion(.success([]))
        self.callObservers(withUpdate: .success(.restorations([])))
      }
    }
  }
  
  private func completeTransactionsCallback(withPurchases purchases: [Purchase]) {
    // TODO: consolidate set of successful purchases and failures and make just 1 call to observers
    
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
