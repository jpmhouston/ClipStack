//
//  Maccy+Actions.swift
//  Cleepp
//
//  Created by Pierre Houston on 2024-03-20.
//  Copyright © 2024 Bananameter Labs. All rights reserved.
//

import AppKit
import Settings

extension Cleepp {
  
  private var pasteMultipleDelaySeconds: Float { 0.333 }
  private var pasteMultipleDelay: DispatchTimeInterval { .milliseconds(Int(pasteMultipleDelaySeconds * 1000)) }
  
  @IBAction
  func startQueueMode(_ sender: AnyObject) {
    menu.cancelTrackingWithoutAnimation() // do this before any alerts appear
    guard Accessibility.check() else {
      return
    }
    guard !Self.isQueueModeOn else {
      return
    }
    
    restoreClipboardMonitoring()
    
    Self.isQueueModeOn = true
    Self.queueSize = 0
    permitEmptyQueueMode = true
    
    updateStatusMenuIcon()
    updateMenuTitle()
  }
  
  private func restoreClipboardMonitoring() {
    if UserDefaults.standard.ignoreEvents {
      UserDefaults.standard.ignoreEvents = false
      UserDefaults.standard.ignoreOnlyNextEvent = false
    }
  }
  
  @IBAction
  func queuedCopy(_ sender: AnyObject) {
    queuedCopy()
  }
  
  func queuedCopy() {
    guard Accessibility.check() else {
      return
    }
    
    restoreClipboardMonitoring()
    
    if !Self.isQueueModeOn {
      Self.isQueueModeOn = true
      permitEmptyQueueMode = false
    }
    
    Self.busy = true
    
    // make the frontmost application perform a copy
    // let clipboard object detect this normally and invoke incrementQueue
    clipboard.invokeApplicationCopy() {
      Self.busy = false
    }
  }
  
  func incrementQueue() {
    guard Self.isQueueModeOn else {
      return
    }
    
    Self.queueSize += 1
    
    updateStatusMenuIcon(.increment)
    updateMenuTitle()
    menu.updateHeadOfQueue(index: queueHeadIndex)
    
    // revert pasteboard back to first item in the queue (don't have to when queueSize is now 1)
    if let index = queueHeadIndex, index > 0 && index < history.count {
      clipboard.copy(history.all[index])
    }
  }
  
  @IBAction
  func queuedPaste(_ sender: AnyObject) {
    queuedPaste()
  }
  
  func queuedPaste() {
    guard Self.isQueueModeOn && Self.queueSize > 0 else {
      return
    }
    
    guard Accessibility.check() else {
      return
    }
    
    Self.busy = true
    
    // make the frontmost application perform a paste
    clipboard.invokeApplicationPaste() {
      self.decrementQueue()
      
      Self.busy = false
      
      #if FOR_APP_STORE
        // TODO: enable reviews when this target is truly building for the app store
//      if !Self.isQueueModeOn {
//        AppStoreReview.ask(after: 20)
//      }
      #endif
    }
  }
  
  func decrementQueue(withIconUpdates updateIcon: Bool = true) {
    guard Self.isQueueModeOn && Self.queueSize > 0 else {
      return
    }
    
    Self.queueSize -= 1

    if Self.queueSize <= 0 {
      Self.isQueueModeOn = false
    } else if let index = queueHeadIndex, index < history.count {
      clipboard.copy(history.all[index]) // reset pasteboard to the latest item copied
    }
    
    if updateIcon {
      updateStatusMenuIcon(.decrement)
    }
    updateMenuTitle()
    menu.updateHeadOfQueue(index: queueHeadIndex)
  }
  
  @IBAction
  func queuedPasteMultiple(_ sender: AnyObject) {
    guard Accessibility.check() else {
      return
    }
    
    menu.cancelTrackingWithoutAnimation() // do this before any alerts appear
    withNumberToPasteAlert() { number in
      // Tricky! See MenuController for how `withFocus` normally uses NSApp.hide
      // after making the menu open, except when returnFocusToPreviousApp false.
      // `withNumberToPasteAlert` must set that flag to false to run the alert
      // and so at this moment our app has not been hidden.
      // `invokeApplicationPaste` internally does a dispatch async around
      // controlling the frontmost app so it does so only after the `withFocus`
      // closure does NSApp.hide as it exits.
      // Because this runs after withFocus has already exited without doing
      // NSApp.hide (since withNumberToPasteAlert sets returnFocusToPreviousApp
      // to false), and we want to immediately control the app now, must do the
      // NSApp.hide ourselves here.
      NSApp.hide(self)
      
      self.queuedPasteMultiple(number)
    }
  }
  
  @IBAction
  func queuedPasteAll(_ sender: AnyObject) {
    guard Accessibility.check() else {
      return
    }
    
    queuedPasteMultiple(Self.queueSize)
  }
  
  private func queuedPasteMultiple(_ count: Int) {
    guard count >= 1 && count <= Self.queueSize else {
      return
    }
    if count == 1 {
      queuedPaste()
    } else {
      Self.busy = true
      
      setStatusMenuIcon(to: .cleepMenuIconListMinus)
      queuedPasteMultipleIteration(count)
    }
  }
  
  private func queuedPasteMultipleIteration(_ count: Int) {
    // make the frontmost application perform a paste again & again until count decrements to 0
    if count > 0 {
      clipboard.invokeApplicationPaste() {
        self.decrementQueue(withIconUpdates: false)
        DispatchQueue.main.asyncAfter(deadline: .now() + self.pasteMultipleDelay) {
          self.queuedPasteMultipleIteration(count - 1)
        }
      }
    } else {
      updateStatusMenuIcon()
      
      Self.busy = false
    }
  }
  
  func copy(string: String, excludedFromHistory: Bool) {
    clipboard.copy(string, excludeFromHistory: excludedFromHistory)
  }
  
  @IBAction
  func cancelQueueMode(_ sender: AnyObject) {
    Self.isQueueModeOn = false
    Self.queueSize = 0
    
    updateStatusMenuIcon()
    updateMenuTitle()
    menu.updateHeadOfQueue(index: nil)

    // in case pasteboard was left set to an item deeper in the queue, reset to the latest item copied
    if let newestItem = history.first {
      clipboard.copy(newestItem)
    }
  }
  
  @IBAction
  func advanceReplay(_ sender: AnyObject) {
    decrementQueue()
  }
  
  @IBAction
  func replayFromHistory(_ sender: AnyObject) {
    menu.cancelTrackingWithoutAnimation() // do this before any alerts appear
    guard Accessibility.check() else {
      return
    }
    
    guard let item = (sender as? HistoryMenuItem)?.item, let index = history.all.firstIndex(of: item) else {
      return
    }
    
    Self.isQueueModeOn = true
    Self.queueSize = index + 1
    permitEmptyQueueMode = false
    
    updateStatusMenuIcon()
    updateMenuTitle()
    menu.updateHeadOfQueue(index: index)
  }
  
  @IBAction
  func copyFromHistory(_ sender: AnyObject) {
    guard let item = (sender as? HistoryMenuItem)?.item else {
      return
    }
    
    clipboard.copy(item)
  }
  
  func deleteHistoryItem(_ index: Int) {
    guard index < 1000 else {
      return
    }
    
    menu.delete(position: index)
    
    fixQueueAfterDeletingItem(atIndex: index)
  }
  
  @IBAction
  func deleteHistoryItem(_ sender: AnyObject) {
    guard let item = (sender as? HistoryMenuItem)?.item, let index = history.all.firstIndex(of: item) else {
      return
    }
    
    menu.delete(position: index)
    
    fixQueueAfterDeletingItem(atIndex: index)
  }
  
  @IBAction
  func deleteHighlightedHistoryItem(_ sender: AnyObject) {
    guard let deletedIndex = menu.deleteHighlightedItem() else {
      return
    }
    
    fixQueueAfterDeletingItem(atIndex: deletedIndex)
  }
  
  func fixQueueAfterDeletingItem(atIndex index: Int) {
    if Self.isQueueModeOn, let headIndex = queueHeadIndex, index <= headIndex {
      Self.queueSize -= 1
      if !permitEmptyQueueMode && Self.queueSize == 0 {
        Self.isQueueModeOn = false
      }
      
      updateStatusMenuIcon(.decrement)
      updateMenuTitle()
      // menu updates the head of queue item itself when deleting
    }
  }
  
  @IBAction
  func clear(_ sender: AnyObject) {
    clearUnpinned() // for us this is the same as clearAll
    if !permitEmptyQueueMode {
      Self.isQueueModeOn = false
    }
  }
  
  @IBAction
  func undoLastCopy(_ sender: AnyObject) {
    guard let removeItem = history.first else {
      return
    }
    
    history.remove(removeItem)
    menu.delete(position: 0)
    
    if Self.isQueueModeOn && Self.queueSize > 0 {
      fixQueueAfterDeletingItem(atIndex: 0)
    }
    
    // Normally set pasteboard to the previous history item, now first in the history after doing the
    // delete above. However if have items queued we instead don't want to change the pasteboard at all,
    // it needs to stay set to the front item in the queue.
    if !Self.isQueueModeOn || Self.queueSize == 0 {
      if let replaceItem = history.first {
        clipboard.copy(replaceItem)
      } else {
        clipboard.copy("")
      }
    }
  }
  
  @IBAction
  func showAbout(_ sender: AnyObject) {
    Self.returnFocusToPreviousApp = false
    about.openAbout()
    Self.returnFocusToPreviousApp = true
  }
  
  @IBAction
  func showIntro(_ sender: AnyObject) {
    Self.returnFocusToPreviousApp = false
    intro.openIntro(with: self)
    Self.returnFocusToPreviousApp = true
  }
  
  @IBAction
  func showIntroAtPermissionPage(_ sender: AnyObject) {
    Self.returnFocusToPreviousApp = false
    intro.openIntro(atPage: .checkAuth, with: self)
    Self.returnFocusToPreviousApp = true
  }
  
  @IBAction
  func showSettings(_ sender: AnyObject) {
    showSettings()
  }
  
  func showSettings(selectingPane pane: Settings.PaneIdentifier? = nil) {
    Self.returnFocusToPreviousApp = false
    settingsWindowController.show(pane: pane)
    settingsWindowController.window?.orderFrontRegardless()
    Self.returnFocusToPreviousApp = true
  }
  
  @IBAction
  func quit(_ sender: AnyObject) {
    NSApp.terminate(sender)
  }
  
}
