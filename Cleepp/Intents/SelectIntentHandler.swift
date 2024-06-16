//
//  SelectIntentHandler.swift
//  Cleepp
//
//  Created by Pierre Houston on 2024-06-15.
//  Copyright © 2024 Bananameter Labs. All rights reserved.
//

import Intents

@available(macOS 11.0, *)
class SelectIntentHandler: NSObject, SelectIntentHandling {
  private let positionOffset = 0
  private var cleepp: Cleepp!
  
  init(_ cleepp: Cleepp) {
    self.cleepp = cleepp
  }
  
  func handle(intent: SelectIntent, completion: @escaping (SelectIntentResponse) -> Void) {
    guard let number = intent.number as? Int,
          cleepp.replayFromHistory(atIndex: number - positionOffset) else {
      completion(SelectIntentResponse(code: .failure, userActivity: nil))
      return
    }
    completion(SelectIntentResponse(code: .success, userActivity: nil))
  }
  
  func resolveNumber(for intent: SelectIntent, with completion: @escaping (SelectNumberResolutionResult) -> Void) {
    guard let number = intent.number as? Int else {
      completion(.needsValue())
      return
    }
    completion(.success(with: number))
  }
  
}
