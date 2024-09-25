//
//  Purchase.swift
//  ClipStack
//
//  Created by Pierre Houston on 2024-03-10.
//  Copyright © 2024 Bananameter Labs. All rights reserved.
//

import AppKit
import StoreKit
import Flare
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
    // !!!
    // or call something like completeTransactionsCallback below? either with the full result or just the successful transaction
    Flare.shared.addTransactionObserver { transactionResult in
        switch transactionResult {
        case let .success(transaction):
            print("A transaction was received: \(transaction)")
        case let .failure(error):
            print("An error occurred while adding transaction observer: \(error.localizedDescription)")
        }
    }
    
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
    // do anything to cleanup Flare?
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
//    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
//      self?.boughtItems.insert(.bonus)
//      self?.callObservers(withUpdate: .success(.restorations([.bonus])))
//      return
//    }
    
    restorePurchases() { [weak self] restoreResult in
      guard let self = self else { return }
      
      switch restoreResult {
      case .success(let items):
        callObservers(withUpdate: .success(.restorations(items)))
      case .failure(let error):
        callObservers(withUpdate: .failure(error))
      }
    }
//    refreshReceipt() { [weak self] refreshResult in
//      guard let self = self else { return }
//      
//      switch refreshResult {
//      case .success(let items) where items.count > 0:
//        callObservers(withUpdate: .success(.restorations(items)))
//        
//      case .success(_):
//        restorePurchases() // will something else call observers??
//        /*
//        restorePurchases() { [weak self] restoreResult in
//          guard let self = self else { return }
//          
//          switch restoreResult {
//          case .success(let items):
//            callObservers(withUpdate: .success(.restorations(items)))
//          case .failure(let error):
//            callObservers(withUpdate: .failure(error))
//          }
//        }*/
//        
//      default:
//        break
//      }
//    }
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
    let result = validateReceipt(nil) // nil parameter lets InAppReceipt grab the local receipt
    if case .success(let items) = result {
      boughtItems = items
    }
    return result
  }
  
  func validateReceipt(_ receiptData: Data? = nil) -> ReceiptResult {
    let errorValue: PurchaseError
    do {
      let receipt: InAppReceipt
      if let receiptData = receiptData {
        receipt = try InAppReceipt(receiptData: receiptData)
      } else {
        receipt = try InAppReceipt()
      }
      try receipt.validate()
      
      // for now all purchases are identified the same, a having purchased the bonus
      return receipt.hasPurchases ? .success([.bonus]) : .success([])
      
    } catch IARError.initializationFailed(let reason) {
      // catch let error as IARError.initializationFailed(reason) .. can swift let us do this?
      if reason == .appStoreReceiptNotFound {
        return .success([]) // short-circuit to return success after all
        
      } else {
        print("Failure validating receipt: validator itself")
        errorValue = .malformedReceipt
      }
      
    } catch IARError.validationFailed {
      // catch let error as IARError.validationFailed(reason)
      print("Failure validating receipt: did not validate")
      errorValue = .invalidReceipt
      
    } catch {
      print("Error during local receipt validation: \(error.localizedDescription)") // TODO: either ditch logging these or improve the manner & messages
      errorValue = .unknown
    }
    
    lastError = errorValue
    return .failure(errorValue)
  }
  
  func refreshReceipt(_ completion: @escaping (ReceiptResult)->Void) {
    Flare.shared.receipt(updateTransactions: false) { [weak self] fetchResult in
      guard let self = self else { return }
      
      switch fetchResult {
      case .success(let receipt64String):
        if let receipt = Data(base64Encoded: receipt64String) {
          let validationResult = validateReceipt(receipt)
          
          completion(validationResult)
          
        } else {
          completion(.failure(.malformedReceipt))
        }
        
      case .failure(.receiptNotFound):
        completion(.success([]))
        
      case .failure(.with(let underlyingError)):
        print("Error during receipt refresh: \(underlyingError.localizedDescription)") // TODO: either ditch logging these or improve the manner & messages
        completion(.failure(.unreachable))
      case .failure(let error):
        print("Error during receipt refresh: \(error.localizedDescription)") // TODO: either ditch logging these or improve the manner & messages
        completion(.failure(.unknown))
      }
    }
    
//    SwiftyStoreKit.fetchReceipt(forceRefresh: true) { [weak self] fetchResult in
//      guard let self = self else { return }
//      
//      switch fetchResult {
//      case .success(let receiptData):
//        let validationResult = self.validateReceipt(receiptData)
//        completion(validationResult)
//        
//      case .error(.noReceiptData), .error(.noRemoteData),
//           .error(.receiptInvalid(_, .subscriptionExpired)):
//        completion(.success([]))
//        
//      case .error(.networkError(let osError)):
//        print("Network failure fetching receipts: \(osError)")
//        completion(.failure(.unreachable))
//        
//      case .error(.receiptInvalid(_, .receiptServerUnavailable)):
//        print("Failure fetching receipts: some apple server reported to be down")
//        completion(.failure(.unreachable))
//        
//      case .error(let error):
//        print("Failure fetching receipts: \(error)") // TOOD: either ditch logging these or improve the manner & messages
//        // perhaps this error case shouldn't be named "unknown", maybe "other"
//        completion(.failure(.unknown))
//      }
//    }
  }
  
  func restorePurchases(_ completion: @escaping (ReceiptResult)->Void) {
    // currently nearly identical to refreshReceipt
    Flare.shared.receipt(updateTransactions: true) { [weak self] restoreResult in
      guard let self = self else { return }
      
      switch restoreResult {
      case .success(let receipt64String):
        if let receipt = Data(base64Encoded: receipt64String) {
          let validationResult = validateReceipt(receipt)
          
          completion(validationResult)
          
        } else {
          completion(.failure(.malformedReceipt))
        }
        
      case .failure(.receiptNotFound):
        completion(.success([]))
        
      case .failure(.with(let underlyingError)):
        print("Error during restore: \(underlyingError.localizedDescription)") // TODO: either ditch logging these or improve the manner & messages
        completion(.failure(.unreachable))
      case .failure(let error):
        print("Error during restore: \(error.localizedDescription)") // TODO: either ditch logging these or improve the manner & messages
        completion(.failure(.unknown))
      }
    }
    
//    SwiftyStoreKit.restorePurchases(atomically: true) { [weak self] restoreResult in
//      guard let self = self else { return }
//      
//      if restoreResult.restoredPurchases.count > 0 {
//        print("Success restoring purchases: \(restoreResult.restoredPurchases)")
//        // validation and invoking observers done in completeTransactionsCallback, does that make sense?
//        //completion(.success([]))
//        
//      } else if restoreResult.restoreFailedPurchases.count > 0 {
//        print("Failure restoring purchases: \(restoreResult.restoreFailedPurchases)")
//        // invoking observers on failure in completeTransactionsCallback too? maybe don't need a completion parameter
//        //completion(.failure(.unknown)) // TODO: what error
//        
//      } else {
//        print("Nothing to Restore")
//        // if no call to completeTransactionsCallback occurs in this case, invoke observers here?
//        //completion(.success([]))
//        self.callObservers(withUpdate: .success(.restorations([])))
//      }
//    }
  }
  
//  private func completeTransactionsCallback(withPurchases purchases: [Purchase]) {
//    // TODO: consolidate set of successful purchases and failures and make just 1 call to observers
//    
//    for purchase in purchases {
//      switch purchase.transaction.transactionState {
//      case .purchased:
//        // when should we validate purchase receipts??
//        
//        // instead of comparing against a well-known product id, any purchase gets the user the bonus
//        boughtItems.insert(.bonus)
//        callObservers(withUpdate: .success(.purchases([.bonus])))
//        lastError = nil
//        
//        if purchase.needsFinishTransaction {
//          SwiftyStoreKit.finishTransaction(purchase.transaction)
//        }
//        
//      case .restored:
//        boughtItems.insert(.bonus)
//        callObservers(withUpdate: .success(.restorations([.bonus])))
//        lastError = nil
//        
//        if purchase.needsFinishTransaction {
//          SwiftyStoreKit.finishTransaction(purchase.transaction)
//        }
//        
//      case .failed:
//        print("Purchase failed: \(purchase.productId), \(purchase.transaction.transactionIdentifier ?? "unknown transaction")")
//        callObservers(withUpdate: .failure(.unknown))
//        lastError = .unknown
//        
//      case .purchasing, .deferred:
//        // TODO: look into these cases and see if we need to do anything
//        break
//      @unknown default:
//        break
//      }
//    }
//  }
  
}
