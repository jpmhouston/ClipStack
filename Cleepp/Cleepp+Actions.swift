//
//  Maccy+Actions.swift
//  Cleepp
//
//  Created by Pierre Houston on 2024-03-20.
//  Copyright © 2024 Bananameter Labs. All rights reserved.
//

import AppKit
import Settings

// TODO: put these somewhere else
func nop() { }
func dontWarnUnused(_ x: Any) { }

extension Cleepp {
  
  private var copyTimeoutSeconds: Double { 1.0 }
  private var standardPasteDelaySeconds: Double { 0.33333 }
  private var standardPasteDelay: DispatchTimeInterval { .milliseconds(Int(standardPasteDelaySeconds * 1000)) }
  private var extraPasteDelaySeconds: Double { 0.66666 }
  private var extraPasteDelay: DispatchTimeInterval { .milliseconds(Int(extraPasteDelaySeconds * 1000)) }
  private var pasteMultipleDelay: DispatchTimeInterval { .milliseconds(Int(extraPasteDelaySeconds * 1000)) }
  
  private var extraDelayOnQueuedPaste: Bool {
    #if arch(x86_64) || arch(i386)
    true
    #else
    false
    #endif
    // or maybe is not processor, but instead the latest OS fixes need for longer delay
    //if #unavailable(macOS 14) { true } else { false }
  }
  
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
  
  func queuedCopy() {
    // handler for the global keyboard shortcut
    doQueuedCopy()
  }
  
  @IBAction
  func queuedCopy(_ sender: AnyObject) {
    doQueuedCopy()
  }
  
  func doQueuedCopy() {
    guard !Self.busy else {
      return
    }
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
    clipboard.invokeApplicationCopy() { [weak self] in
      guard let self = self else { return }

      // allow copy again if no copy deletected after this duration
      self.runOnCopyTimeoutTimer(afterTimeout: self.copyTimeoutSeconds) { [weak self] in
        guard self != nil else { return }
        
        Self.busy = false
      }
    }
  }
  
  func incrementQueue() {
    // called from clipboard via its onNewCopy mechanism
    guard Self.isQueueModeOn else {
      return
    }
    
    // cancel timeout if its timer is active and clear the busy flag controlled by the timer
    let withinTimeout = copyTimeoutTimer != nil
    if withinTimeout {
      cancelCopyTimeoutTimer()
      // perhaps assert Self.busy here?
    }
    
    Self.queueSize += 1
    
    // revert pasteboard back to first item in the queue (don't have to when queueSize is now 1)
    if let index = queueHeadIndex, index > 0 && index < history.count {
      clipboard.copy(history.all[index])
    }
    
    updateStatusMenuIcon(.increment)
    updateMenuTitle()
    menu.updateHeadOfQueue(index: queueHeadIndex)
    
    if withinTimeout {
      Self.busy = false
    }
  }
  
  func queuedPaste() {
    // handler for the global keyboard shortcut
    doQueuedPaste()
  }
  
  @IBAction
  func queuedPaste(_ sender: AnyObject) {
    doQueuedPaste()
  }
  
  func doQueuedPaste() {
    guard !Self.busy else {
      return
    }
    
    guard Self.isQueueModeOn && Self.queueSize > 0 else {
      return
    }
    guard Accessibility.check() else {
      return
    }
    
    Self.busy = true
    
    let decrementQueueDelay = extraDelayOnQueuedPaste ? extraPasteDelay : standardPasteDelay
    
    // make the frontmost application perform a paste
    clipboard.invokeApplicationPaste() { [weak self] in
      guard self != nil else { return }
      
      // advance queue only after out delay, keep the app from doing anything else until them
      DispatchQueue.main.asyncAfter(deadline: .now() + decrementQueueDelay) { [weak self] in
        guard let self = self else { return }
        
        self.decrementQueue()
        
        Self.busy = false
        
        #if FOR_APP_STORE
          // TODO: enable reviews when this target is truly building for the app store
//        if !Self.isQueueModeOn {
//          AppStoreReview.ask(after: 20)
//        }
        #endif
      }
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
      clipboard.copy(history.all[index])
    }
    
    if updateIcon {
      updateStatusMenuIcon(.decrement)
    }
    updateMenuTitle()
    menu.updateHeadOfQueue(index: queueHeadIndex)
  }
  
  @IBAction
  func queuedPasteMultiple(_ sender: AnyObject) {
    guard !Self.busy else {
      return
    }
    
    guard Self.isQueueModeOn && Self.queueSize > 0 else {
      return
    }
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
    guard !Self.busy else {
      return
    }
    
    guard Self.isQueueModeOn && Self.queueSize > 0 else {
      return
    }
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
      doQueuedPaste()
    } else {
      Self.busy = true
      
      setStatusMenuIcon(to: .cleepMenuIconListMinus)
      
      queuedPasteMultipleIterator(count) {
        self.updateStatusMenuIcon()
        
        Self.busy = false
        
        #if FOR_APP_STORE
        // TODO: enable reviews when this target is truly building for the app store
//        if !Self.isQueueModeOn {
//          AppStoreReview.ask(after: 20)
//        }
        #endif
      }
    }
  }
  
  private func queuedPasteMultipleIterator(_ count: Int, then completion: @escaping ()->Void) {
    // make the frontmost application perform a paste again & again until count decrements to 0
    if count > 0 {
      nop() // TODO: remove once no longer need a breakpoint here
      
      clipboard.invokeApplicationPaste() { [weak self] in
        guard let self = self else { return }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + self.pasteMultipleDelay) { [weak self] in
          guard let self = self else { return }
          
          self.decrementQueue(withIconUpdates: false)
          
          self.queuedPasteMultipleIterator(count - 1, then: completion)
        }
      }
    } else {
      completion()
    }
  }
  
  func copy(string: String, excludedFromHistory: Bool) {
    clipboard.copy(string, excludeFromHistory: excludedFromHistory)
  }
  
  @IBAction
  func cancelQueueMode(_ sender: AnyObject) {
    guard !Self.busy else {
      return
    }
    
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
    guard !Self.busy else {
      return
    }
    
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
    
    // put it on the clipboard ready to be pasted
    clipboard.copy(item)
  }
  
  @IBAction
  func copyFromHistory(_ sender: AnyObject) {
    guard !Self.busy else {
      return
    }
    
    guard let item = (sender as? HistoryMenuItem)?.item else {
      return
    }
    
    clipboard.copy(item)
  }
  
  func deleteHistoryItem(_ index: Int) {
    guard index < history.count else {
      return
    }
    
    menu.delete(position: index)
    
    fixQueueAfterDeletingItem(atIndex: index)
  }
  
  @IBAction
  func deleteHistoryItem(_ sender: AnyObject) {
    guard !Self.busy else {
      return
    }
    
    guard let item = (sender as? HistoryMenuItem)?.item, let index = history.all.firstIndex(of: item) else {
      return
    }
    
    menu.delete(position: index)
    
    fixQueueAfterDeletingItem(atIndex: index)
  }
  
  @IBAction
  func deleteHighlightedHistoryItem(_ sender: AnyObject) {
    guard !Self.busy else {
      return
    }
    
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
    guard !Self.busy else {
      return
    }
    
    clearUnpinned() // for us this is the same as clearAll
    if !permitEmptyQueueMode {
      Self.isQueueModeOn = false
    }
  }
  
  @IBAction
  func undoLastCopy(_ sender: AnyObject) {
    guard !Self.busy else {
      return
    }
    
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
    introWindowController.openIntro(with: self)
    Self.returnFocusToPreviousApp = true
  }
  
  @IBAction
  func showIntroAtPermissionPage(_ sender: AnyObject) {
    Self.returnFocusToPreviousApp = false
    introWindowController.openIntro(atPage: .checkAuth, with: self)
    Self.returnFocusToPreviousApp = true
  }
  
  func showLicenses() {
    Self.returnFocusToPreviousApp = false
    licensesWindowController.openLicenses()
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
  
  // MARK: -
  
  private func runOnCopyTimeoutTimer(afterTimeout timeout: Double, _ action: @escaping () -> Void) {
    if copyTimeoutTimer != nil {
      cancelCopyTimeoutTimer()
    }
    copyTimeoutTimer = DispatchSource.scheduledTimerForRunningOnMainQueue(afterDelay: timeout) { [weak self] in
      self?.copyTimeoutTimer = nil // doing this before calling closure supports closure itself calling runOnCopyTimeoutTimer, fwiw
      action()
    }
  }
  
  private func cancelCopyTimeoutTimer() {
    copyTimeoutTimer?.cancel()
    copyTimeoutTimer = nil
  }
  
}
