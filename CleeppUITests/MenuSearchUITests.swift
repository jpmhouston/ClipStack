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
    openExpandedMenu()
    checkForBonusFeatures()
    try XCTSkipUnless(hasBonusFeatures)
    
    // didn't think this would be needed, when not uitesting user can just type and it goes into the search field
    app.searchFields.firstMatch.click()
    
    search(copy2)
    assertSearchFieldValue(copy2)
    assertExists(menuItems[copy2])
    //assertSelected(menuItems[copy2].firstMatch)
    assertNotExists(menuItems[copy1])
    closeMenu()
  }
  
  func test10SearchFiles() throws {
    copyToClipboard(url: file2)
    copyToClipboard(url: file1)
    
    openExpandedMenu()
    checkForBonusFeatures()
    try XCTSkipUnless(hasBonusFeatures)
    
    app.searchFields.firstMatch.click()
    search(file2.lastPathComponent)
    assertExists(menuItems[file2.absoluteString])
    //assertSelected(menuItems[file2.absoluteString].firstMatch)
    assertNotExists(menuItems[file1.absoluteString])
    closeMenu()
  }
  
  func test11AllowsToFocusSearchField() throws {
    openExpandedMenu()
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
    openExpandedMenu()
    app.searchFields.firstMatch.click()
    search("foo")
    assertSearchFieldValue("foo")
    closeMenu()
  }
  
  func test12ClearSearchWithEscape() throws {
    openExpandedMenu()
    checkForBonusFeatures()
    try XCTSkipUnless(hasBonusFeatures)
    
    app.searchFields.firstMatch.click()
    search("foo bar")
    app.typeKey(.escape, modifierFlags: [])
    assertSearchFieldValue("")
    closeMenu()
  }
  
  func test13ClearDuringSearch() throws {
    openExpandedMenu()
    checkForBonusFeatures()
    try XCTSkipUnless(hasBonusFeatures)
    
    app.searchFields.firstMatch.click()
    search(copy2)
    menuItems["Clear History…"].click()
    
    // confirmation alert
    let button = app.dialogs.firstMatch.buttons["Clear"].firstMatch
    expectation(for: NSPredicate(format: "isHittable = 1"), evaluatedWith: button)
    waitForExpectations(timeout: 3)
    button.click()
    
    openExpandedMenu()
    assertNotExists(menuItems[copy1])
    assertNotExists(menuItems[copy2])
    closeMenu()
  }
  
  func test20RemoveLastWordFromSearchWithControlW() throws {
    openExpandedMenu()
    checkForBonusFeatures()
    try XCTSkipUnless(hasBonusFeatures)
    
    app.searchFields.firstMatch.click()
    search("foo bar")
    app.typeKey("w", modifierFlags: [.control])
    assertSearchFieldValue("foo ")
    closeMenu()
  }
  
  // thought this would be needed, when not uitesting user can just type and it goes into the search field
//  func test21TypeToSearchWithFieldUnfocused() throws {
//    openExpandedMenu()
//    checkForBonusFeatures()
//    try XCTSkipUnless(hasBonusFeatures)
//    
//    app.typeKey("a", modifierFlags: [])
//    waitForSearch()
//    assertSearchFieldValue("a")
//    closeMenu()
//  }
  
//  func test30DeleteEntryDuringSearch() throws {
//    openExpandedMenu()
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
//    openExpandedMenu()
//    assertNotExists(menuItems[copy2])
//    closeMenu()
//  }
  
}
