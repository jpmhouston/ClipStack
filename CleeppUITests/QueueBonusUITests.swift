//
//  QueueBonusUITests.swift
//  Cleepp
//
//  Created by Pierre Houston on 2024-06-02.
//  Copyright © 2024 Bananameter Labs. All rights reserved.
//

import XCTest

final class QueueBonusUITests: CleeppUITestBase {

  func test00PasteAll() throws {
    openExpandedMenu()
    checkForBonusFeatures()
    try XCTSkipUnless(hasBonusFeatures)
    closeMenu()
    
    enterQueueMode()
    copyToClipboard("foo")
    copyToClipboard("bar")
    
    selectMenuItemWhenNotBusy(menuItems["Paste All"])
    
    waitUntilNotBusy()
    exitQueueMode()
    
    putCatenatedPasteHistoryOnClipboard()
    assertPasteboardStringEquals("foobar")
  }
  
  func test00PasteMultiple() throws {
    openExpandedMenu()
    checkForBonusFeatures()
    try XCTSkipUnless(hasBonusFeatures)
    closeMenu()
    
    enterQueueMode()
    copyToClipboard("foo")
    copyToClipboard("bar")
    copyToClipboard(UUID().uuidString)
    
    selectMenuItemWhenNotBusy(menuItems["Paste Multiple…"], withMenuAlternateModifierFlags: .option)
    
    // in alert enter "2" in the field and hit the button
    let field = app.dialogs.firstMatch.textFields.firstMatch
    expectation(for: NSPredicate(format: "isHittable = 1"), evaluatedWith: field)
    waitForExpectations(timeout: 3)
    field.click()
    app.typeKey("2", modifierFlags: [])
    let button = app.dialogs.firstMatch.buttons["Paste"].firstMatch
    button.click()
    
    usleep(1_000_000) // perhaps not necessary, seems like a good idea to give time for alert to close
    waitUntilNotBusy()
    exitQueueMode()
    
    putCatenatedPasteHistoryOnClipboard()
    assertPasteboardStringEquals("foobar")
  }
  
}
