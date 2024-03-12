//
//  Purchase.swift
//  ClipStack
//
//  Created by Pierre Houston on 2024-03-10.
//  Copyright © 2024 p0deje. All rights reserved.
//

import AppKit
import StoreKit

enum PurchaseError: Error, CaseIterable {
  case cancelled, declined, noneToRestore, networkFailure
}

class Purchase {
  
  static var hasPurchasedExtras = false
  
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
  
}
