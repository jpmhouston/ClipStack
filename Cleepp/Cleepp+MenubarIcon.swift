//
//  Maccy+MenubarIcon.swift
//  Cleepp
//
//  Created by Pierre Houston on 2024-03-20.
//  Copyright © 2024 Bananameter Labs. All rights reserved.
//

import AppKit

extension Cleepp {
  
  enum QueueChangeDirection {
    case none, increment, decrement
  }
  enum SymbolTransition {
    case replace
    case blink(transitionIcon: NSImage.Name)
  }
  
  private var iconBlinkIntervalSeconds: Float { 0.75 }
  
  func setupStatusMenuIcon() {
    guard let button = statusItem.button else {
      return
    }
    
    button.image = NSImage(named: .cleepMenuIcon)
    button.imagePosition = .imageRight
    (button.cell as? NSButtonCell)?.highlightsBy = []
  }
  
  func setStatusMenuIcon(to name: NSImage.Name) {
    guard let iconImage = NSImage(named: name) else {
      return
    }
    statusItem.button?.image = iconImage
  }
  
  func updateStatusMenuIcon(_ direction: QueueChangeDirection = .none) {
    let icon: NSImage.Name
    var transition = SymbolTransition.replace
    if !Self.isQueueModeOn {
      icon = .cleepMenuIcon
      if direction == .decrement {
        transition = .blink(transitionIcon: .cleepMenuIconListMinus)
      }
    } else {
      if Self.queueSize == 0 {
        icon = .cleepMenuIconFill
      } else {
        icon = .cleepMenuIconList
      }
      if direction == .decrement {
        transition = .blink(transitionIcon: .cleepMenuIconListMinus)
      } else if direction == .increment && Self.queueSize == 1 {
        transition = .blink(transitionIcon: .cleepMenuIconFillPlus)
      } else if direction == .increment && Self.queueSize > 1 {
        transition = .blink(transitionIcon: .cleepMenuIconListPlus)
      }
    }
    
    guard let iconImage = NSImage(named: icon) else {
      return
    }
    
    if case .blink(let transitionIcon) = transition, let transitionImage = NSImage(named: transitionIcon) {
      // first show transition symbol, then blink to the final symbol
      statusItem.button?.image = transitionImage
      runOnIconBlinkTimer(afterInterval: iconBlinkIntervalSeconds) { [weak self] in
        self?.statusItem.button?.image = iconImage
      }
    } else {
      statusItem.button?.image = iconImage
    }
  }
  
  private func runOnIconBlinkTimer(afterInterval interval: Float, _ action: @escaping () -> Void) {
    if iconBlinkTimer != nil {
      cancelIconBlinkTimer()
    }
    iconBlinkTimer = timerForRunningOnMainQueueAfterDelay(interval) { [weak self] in
      self?.iconBlinkTimer = nil // doing this before calling closure supports closure itself calling runOnIconBlinkTimer, fwiw
      action()
    }
  }
  
  internal func cancelIconBlinkTimer() {
    iconBlinkTimer?.cancel()
    iconBlinkTimer = nil
  }
  
  private func timerForRunningOnMainQueueAfterDelay(_ seconds: Float, _ action: @escaping () -> Void) -> DispatchSourceTimer {
    let timer = DispatchSource.makeTimerSource()
    timer.schedule(wallDeadline: .now() + .milliseconds(Int(seconds * 1000)))
    timer.setEventHandler {
      DispatchQueue.main.async {
        action()
      }
    }
    timer.resume()
    return timer
  }
  
}
