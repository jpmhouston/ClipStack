//
//  QueueUITests.swift
//  Cleepp
//
//  Created by Pierre Houston on 2024-05-06.
//  Copyright © 2024 Bananameter Labs. All rights reserved.
//

import Carbon
import XCTest

class QueueUITests: CleeppUITestBase {
  
  func test00EnterExitQueueMode() throws {
    try XCTSkipUnless(hasAccessibilityPermissions)
    
    popUpUnexpandedMenu()
    let startItem = menuItems["Start Collecting"]
    guard startItem.exists else {
      closeMenu()
      XCTFail("Cleepp Start Collecting menu item doesn't exist")
      return
    }
    startItem.click()
    assertInQueueMode()
    exitQueueMode()
    
    XCUIElement.perform(withKeyModifiers: [.control]) {
      app.statusItems.firstMatch.click()
    }
    assertInQueueMode()
    
    XCUIElement.perform(withKeyModifiers: [.control]) {
      app.statusItems.firstMatch.click()
    }
    assertNotInQueueMode()
    
    // TODO: turning on with ^cmdC
  }
  
  func test10QueueCopiesCollected() throws {
    try XCTSkipUnless(hasAccessibilityPermissions)
    
    enterQueueMode()
    let copy3 = UUID().uuidString
    let copy4 = UUID().uuidString
    copyToClipboard(copy3)
    copyToClipboard(copy4)
    
    popUpUnexpandedMenu()
    assertExists(menuItems[copy3])
    assertExists(menuItems[copy4])
    closeMenu()
    exitQueueMode()
  }
  
  // TODO: add floating text window to app for copying and pasting during tests
  
}
