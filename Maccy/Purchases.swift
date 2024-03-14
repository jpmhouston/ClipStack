//
//  Purchase.swift
//  ClipStack
//
//  Created by Pierre Houston on 2024-03-10.
//  Copyright © 2024 Bananameter Labs. All rights reserved.
//

import AppKit
import StoreKit

enum PurchaseError: Error, CaseIterable {
  case prohibited, cancelled, declined, noneToRestore, networkFailure
}

//protocol PurchaseObserver: AnyObject {
//  func paymentStateChanged()
//  func paymentFailure(_ error: PurchaseError)
//}

class Purchases: NSObject, SKPaymentTransactionObserver, SKRequestDelegate {
  // observer scheme described in https://www.swiftbysundell.com/articles/observers-in-swift-part-1/
  //  struct Observation {
  //      weak var observer: ?
  //  }
  //  private var observations = [ObjectIdentifier : Observation]()
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
  typealias PurchaseResult = Result<Bool, PurchaseError>
  typealias ObserveResult = Result<Bool, PurchaseError>
  private var observations: [UUID: (ObserveResult) -> Void] = [:]
  
  static let shared = Purchases()
  
  static var extrasPurchased: Bool {
    Self.shared.hasPurchasedExtras
  }
  var hasPurchasedExtras = false
  
  // MARK: -
  
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

  func connect<T: AnyObject>(withObserver observer: T, callback: @escaping (T, ObserveResult) -> Void) -> ObservationToken {
    SKPaymentQueue.default().add(self)
    return addObserver(observer, callback: callback)
  }
  
  func connect() {
    SKPaymentQueue.default().add(self)
  }
  
  func disconnect(andRemoveObserver token: ObservationToken? = nil) {
    if let token = token {
      token.cancel()
    }
    SKPaymentQueue.default().remove(self)
  }
  
  func addObserver<T: AnyObject>(_ observer: T, callback: @escaping (T, ObserveResult) -> Void) -> ObservationToken {
    let id = UUID()
    observations[id] = { [weak self, weak observer] result in
      guard let observer = observer else {
        self?.observations.removeValue(forKey: id)
        return
      }
      callback(observer, result)
    }
    return ObservationToken { [weak self] in
        self?.observations.removeValue(forKey: id)
    }
  }
  
  func removeObserver(_ token: ObservationToken) {
    token.cancel()
  }
  
  // MARK: -
  
  func buyBonus() -> Result<Void, PurchaseError> {
    guard SKPaymentQueue.canMakePayments() else {
      return .failure(.prohibited)
    }
    
    return .success(())
  }
  
  func restore() -> Result<Void, PurchaseError> {
    guard SKPaymentQueue.canMakePayments() else {
      return .failure(.prohibited)
    }
    
    let refresh = SKReceiptRefreshRequest()
    refresh.delegate = self
    refresh.start()
    
    return .success(())
  }
  
  // remove:
  static var errorSampler: PurchaseError = .cancelled
  static func nextError() {
    let curr = PurchaseError.allCases.firstIndex(of: Self.errorSampler) ?? 0
    let next = (curr + 1) % PurchaseError.allCases.count
    Self.errorSampler = PurchaseError.allCases[next]
  }
  
  static func purchaseExtras(callback: @escaping (_ error: PurchaseError?) -> Void) {
    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
      if Self.errorSampler == .noneToRestore { Self.nextError() }
      callback(Self.errorSampler)
      Self.nextError()
    }
  }
  
  static func restorePurchases(callback: @escaping (_ error: PurchaseError?) -> Void) {
    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
      callback(Self.errorSampler)
      Self.nextError()
    }
  }
  
  static func verifyPurchase(callback: @escaping (_ updated: Bool) -> Void) {
    DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
      callback(true)
    }
  }
  
  // MARK: -
  
  // callbacks for refreshing receipts
  func requestDidFinish(_ request: SKRequest) {
    
  }
  func request(_ request: SKRequest, didFailWithError error: any Error) {
    
  }
  
  // callback for restoring purchases
  func paymentQueueRestoreCompletedTransactionsFinished(_ queue: SKPaymentQueue) {
    
  }
  
  func paymentQueue(_ queue: SKPaymentQueue, restoreCompletedTransactionsFailedWithError error: any Error) {
    
  }
  
  // callback for making purchases
  func paymentQueue(_ queue: SKPaymentQueue, updatedTransactions transactions: [SKPaymentTransaction]) {
    
  }
  
}
