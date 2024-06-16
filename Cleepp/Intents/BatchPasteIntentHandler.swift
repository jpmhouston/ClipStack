//
//  BatchPasteIntentHandler.swift
//  Cleepp
//
//  Created by Pierre Houston on 2024-06-15.
//  Copyright © 2024 Bananameter Labs. All rights reserved.
//

import Intents

@available(macOS 11.0, *)
class BatchPasteIntentHandler: NSObject, BatchPasteIntentHandling {
  private var cleepp: Cleepp!
  
  init(_ cleepp: Cleepp) {
    self.cleepp = cleepp
  }
  
  func handle(intent: BatchPasteIntent, completion: @escaping (BatchPasteIntentResponse) -> Void) {
    guard cleepp.queuedPaste(interactive: false) else {
      completion(BatchPasteIntentResponse(code: .failure, userActivity: nil))
      return
    }
    completion(BatchPasteIntentResponse(code: .success, userActivity: nil))
  }
  
}
