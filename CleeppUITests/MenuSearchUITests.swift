//
//  MenuSearchUITests.swift
//  Cleepp
//
//  Created by Pierre Houston on 2024-05-06.
//  Copyright © 2024 Bananameter Labs. All rights reserved.
//

import XCTest

final class MenuSearchUITests: CleeppUITestBase {
  
  func test00Search() throws {
    popUpExpandedMenu()
    checkForBonusFeatures()
    try XCTSkipUnless(hasBonusFeatures)
    
    search(copy2)
    assertSearchFieldValue(copy2)
    assertExists(menuItems[copy2])
    assertSelected(menuItems[copy2].firstMatch)
    assertNotExists(menuItems[copy1])
    closeMenu()
  }
  
  func test10SearchFiles() throws {
    copyToClipboard(url: file2)
    copyToClipboard(url: file1)
    
    popUpExpandedMenu()
    checkForBonusFeatures()
    try XCTSkipUnless(hasBonusFeatures)
    
    search(file2.lastPathComponent)
    assertExists(menuItems[file2.absoluteString])
    assertSelected(menuItems[file2.absoluteString].firstMatch)
    assertNotExists(menuItems[file1.absoluteString])
    closeMenu()
  }
  
  func test11AllowsToFocusSearchField() throws {
    popUpExpandedMenu()
    checkForBonusFeatures()
    try XCTSkipUnless(hasBonusFeatures)
    
    // The first click succeeds because application is frontmost.
    app.searchFields.firstMatch.click()
    search("foo")
    assertSearchFieldValue("foo")
    // Now close the window AND focus another application
    // by clicking outside of menu.
    let textFieldCoordinates = app.searchFields.firstMatch.coordinate(
      withNormalizedOffset: CGVector(dx: 0, dy: 0))
    let outsideCoordinates = textFieldCoordinates.withOffset(CGVector(dx: 0, dy: -20))
    outsideCoordinates.click()
    // Open again and try to click and focus search field again.
    popUpExpandedMenu()
    app.searchFields.firstMatch.click()
    search("foo")
    assertSearchFieldValue("foo")
    closeMenu()
  }
  
  func test12ClearSearchWithEscape() throws {
    popUpExpandedMenu()
    checkForBonusFeatures()
    try XCTSkipUnless(hasBonusFeatures)
    
    search("foo bar")
    app.typeKey(.escape, modifierFlags: [])
    assertSearchFieldValue("")
    closeMenu()
  }
  
  func test13ClearDuringSearch() throws {
    popUpExpandedMenu()
    checkForBonusFeatures()
    try XCTSkipUnless(hasBonusFeatures)
    
    search(copy2)
    menuItems["Clear History…"].click()
    
    // confirmation alert
    let button = app.dialogs.firstMatch.buttons["Clear"].firstMatch
    expectation(for: NSPredicate(format: "isHittable = 1"), evaluatedWith: button)
    waitForExpectations(timeout: 3)
    button.click()
    
    popUpExpandedMenu()
    assertNotExists(menuItems[copy1])
    assertNotExists(menuItems[copy2])
    closeMenu()
  }
  
  func test20RemoveLastWordFromSearchWithControlW() throws {
    popUpExpandedMenu()
    checkForBonusFeatures()
    try XCTSkipUnless(hasBonusFeatures)
    
    search("foo bar")
    app.typeKey("w", modifierFlags: [.control])
    assertSearchFieldValue("foo ")
    closeMenu()
  }
  
  func test21TypeToSearchWithFieldUnfocused() throws {
    popUpExpandedMenu()
    checkForBonusFeatures()
    try XCTSkipUnless(hasBonusFeatures)
    
    app.typeKey("a", modifierFlags: [])
    waitForSearch()
    assertSearchFieldValue("a")
    closeMenu()
  }
  
//  func test30DeleteEntryDuringSearch() throws {
//    popUpExpandedMenu()
//    checkForBonusFeatures()
//    try XCTSkipUnless(hasBonusFeatures)
//
//    search(copy2)
//    hover(menuItems[copy2].firstMatch)
//    app.typeKey(.delete, modifierFlags: [.option])
//    assertNotExists(menuItems[copy2])
//    // assertSelected(menuItems[copy1].firstMatch) maybe put this back in
//
//    // !!! want to simulate click in search box close box here
//    closeMenu()
//
//    popUpExpandedMenu()
//    assertNotExists(menuItems[copy2])
//    closeMenu()
//  }
  
}
