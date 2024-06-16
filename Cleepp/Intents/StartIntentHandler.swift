//
//  StartIntentHandler.swift
//  Cleepp
//
//  Created by Pierre Houston on 2024-06-14.
//  Copyright © 2024 Bananameter Labs. All rights reserved.
//

import Intents

@available(macOS 11.0, *)
class StartIntentHandler: NSObject, StartIntentHandling {
  private var cleepp: Cleepp!
  
  init(_ cleepp: Cleepp) {
    self.cleepp = cleepp
  }

  func handle(intent: StartIntent, completion: @escaping (StartIntentResponse) -> Void) {
    guard cleepp.startQueueMode(interactive: false) else {
      completion(StartIntentResponse(code: .failure, userActivity: nil))
      return
    }
    completion(StartIntentResponse(code: .success, userActivity: nil))
  }
  
}
