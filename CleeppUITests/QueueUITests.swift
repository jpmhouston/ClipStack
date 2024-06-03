//
//  QueueUITests.swift
//  Cleepp
//
//  Created by Pierre Houston on 2024-05-06.
//  Copyright © 2024 Bananameter Labs. All rights reserved.
//

import Carbon
import XCTest

final class QueueUITests: CleeppUITestBase {
  
  func test00EnterExitQueueMode() {
    // with key shortcuts
    assertNotInQueueMode()
    app.typeKey("c", modifierFlags: [.control, .command])
    waitUntilNotBusy()
    assertInQueueMode()
    
    app.typeKey("v", modifierFlags: [.control, .command])
    waitUntilNotBusy()
    assertNotInQueueMode()
    
    // with start/cancel menu items
    openUnexpandedMenu()
    clickWhenExists(menuItems["Start Collecting"])
    assertInQueueMode()
    
    openUnexpandedMenu()
    clickWhenExists(menuItems["Cancel Collecting / Replaying"])
    waitUntilNotBusy()
    assertNotInQueueMode()
    
    // with control-click on status item
    XCUIElement.perform(withKeyModifiers: [.control]) {
      app.statusItems.firstMatch.click()
    }
    assertInQueueMode()
    
    XCUIElement.perform(withKeyModifiers: [.control]) {
      app.statusItems.firstMatch.click()
    }
    assertNotInQueueMode()
  }
  
  func test01CancelQueueMode() {
    enterQueueMode()
    
    let copy3 = UUID().uuidString
    let copy4 = UUID().uuidString
    let copy5 = UUID().uuidString
    copyToClipboard(copy3)
    copyToClipboard(copy4)
    copyToClipboard(copy5)
    
    waitUntilNotBusy()
    exitQueueMode()
    assertNotInQueueMode()
  }
  
  func test10MenuCopyPaste() {
    selectMenuItemWhenNotBusy(menuItems["Copy & Collect"])
    selectMenuItemWhenNotBusy(menuItems["Copy & Collect"])
    
    selectMenuItemWhenNotBusy(menuItems["Paste & Advance"])
    selectMenuItemWhenNotBusy(menuItems["Paste & Advance"])
    
    waitUntilNotBusy()
    assertNotInQueueMode()
  }
  
  func test11CopyVerify() {
    enterQueueMode()
    
    let copy3 = UUID().uuidString
    let copy4 = UUID().uuidString
    copyToClipboard(copy3)
    copyToClipboard(copy4)
    
    waitUntilNotBusy()
    openUnexpandedMenu()
    assertExists(menuItems[copy3])
    assertExists(menuItems[copy4])
    closeMenu()
    
    selectMenuItemWhenNotBusy(menuItems["Paste & Advance"])
    selectMenuItemWhenNotBusy(menuItems["Paste & Advance"])
    
    waitUntilNotBusy()
    exitQueueMode()
    assertNotInQueueMode()
  }
  
  func test12CopyPasteInterleaved() {
    enterQueueMode()
    
    let copy3 = UUID().uuidString
    let copy4 = UUID().uuidString
    copyToClipboard(copy3)
    copyToClipboard(copy4)
    
    selectMenuItemWhenNotBusy(menuItems["Paste & Advance"])
    waitUntilNotBusy()
    
    let copy5 = UUID().uuidString
    copyToClipboard(copy5)
    
    selectMenuItemWhenNotBusy(menuItems["Paste & Advance"])
    selectMenuItemWhenNotBusy(menuItems["Paste & Advance"])
    
    waitUntilNotBusy()
    exitQueueMode()
    assertNotInQueueMode()
  }
  
  func test20DeleteFirstToLast() {
    enterQueueMode()
    
    let copy3 = UUID().uuidString
    let copy4 = UUID().uuidString
    copyToClipboard(copy3)
    copyToClipboard(copy4)
    
    hoverOnMenuItemAndTypeWhenNotBusy(menuItems[copy3], key: .delete, modifierFlags: [.command])
    
    waitUntilNotBusy()
    assertQueueSize(is: 1)
    
    hoverOnMenuItemAndTypeWhenNotBusy(menuItems[copy4], key: .delete, modifierFlags: [.command])
    
    waitUntilNotBusy()
    assertQueueSize(is: 0)
    exitQueueMode()
  }
  
  func test21DeleteLastToFirst() {
    enterQueueMode()
    
    let copy3 = UUID().uuidString
    let copy4 = UUID().uuidString
    copyToClipboard(copy3)
    copyToClipboard(copy4)
    
    hoverOnMenuItemAndTypeWhenNotBusy(menuItems[copy4], key: .delete, modifierFlags: [.command])
    
    waitUntilNotBusy()
    assertQueueSize(is: 1)
    
    hoverOnMenuItemAndTypeWhenNotBusy(menuItems[copy3], key: .delete, modifierFlags: [.command])
    
    waitUntilNotBusy()
    assertQueueSize(is: 0)
    exitQueueMode()
  }
  
}
