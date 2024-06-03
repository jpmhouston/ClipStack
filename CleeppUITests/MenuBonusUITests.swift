//
//  MenuBonusUITests.swift
//  Cleepp
//
//  Created by Pierre Houston on 2024-06-02.
//  Copyright © 2024 Bananameter Labs. All rights reserved.
//

import XCTest

final class MenuBonusUITests: CleeppUITestBase {
  
  func test00UndoCopy() throws {
    openExpandedMenu()
    checkForBonusFeatures()
    try XCTSkipUnless(hasBonusFeatures)
    
    // copy 2 is copied first, copy 1 second, for whatever reason. so first undo leaves copy2
    menuItems["Undo Last Copy"].click()
    openExpandedMenu()
    assertExists(menuItems[copy2])
    assertNotExists(menuItems[copy1])
  }
  
  func test00UndoAllCopies() throws {
    openExpandedMenu()
    checkForBonusFeatures()
    try XCTSkipUnless(hasBonusFeatures)
    
    menuItems["Undo Last Copy"].click()
    openExpandedMenu()
    menuItems["Undo Last Copy"].click()
    
    openExpandedMenu()
    assertNotExists(menuItems[copy1])
    assertNotExists(menuItems[copy2])
    XCTAssertFalse(app.searchFields.firstMatch.exists) // empty history thus no search field
  }
  
}
