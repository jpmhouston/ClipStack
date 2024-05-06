//
//  DispatchSource+scheduledTimer.swift
//  Cleepp
//
//  Created by Pierre Houston on 2024-03-27.
//  Copyright © 2024 Bananameter Labs. All rights reserved.
//

import Foundation

extension DispatchSource {
  
  static func scheduledTimerForRunningOnMainQueueRepeated(afterDelay delaySeconds: Double, interval intervalSeconds: Double, _ action: @escaping () -> Bool) -> DispatchSourceTimer {
    let timer = DispatchSource.makeTimerSource()
    timer.schedule(wallDeadline: .now() + .milliseconds(Int(delaySeconds * 1000)), repeating: intervalSeconds)
    timer.setEventHandler {
      DispatchQueue.main.async {
        if !action() {
          timer.cancel()
        }
      }
    }
    timer.resume()
    return timer
  }
  
  static func scheduledTimerForRunningOnMainQueue(afterDelay delaySeconds: Double, _ action: @escaping () -> Void) -> DispatchSourceTimer {
    let timer = DispatchSource.makeTimerSource()
    timer.schedule(wallDeadline: .now() + .milliseconds(Int(delaySeconds * 1000)))
    timer.setEventHandler {
      DispatchQueue.main.async {
        action()
      }
    }
    timer.resume()
    return timer
  }
  
}
