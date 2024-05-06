//
//  MenuBasicUITests.swift
//  Cleepp
//
//  Created by Pierre Houston on 2024-05-06.
//  Copyright © 2024 Bananameter Labs. All rights reserved.
//

import Carbon
import XCTest

class MenuBasicUITests: CleeppUITestBase {
  
  func test00MenuContainsAddedItems() {
    popUpExpandedMenu()
    assertExists(menuItems[copy1])
    assertExists(menuItems[copy2])
    closeMenu()
    
    let copy3 = UUID().uuidString
    copyToClipboard(copy3)
    popUpExpandedMenu()
    assertExists(menuItems[copy3])
    closeMenu()
    
    // currently the app doesn't update the menu while its open
    //    popUpExpandedMenu()
    //    let copy3 = UUID().uuidString
    //    copyToClipboard(copy3)
    //    assertExists(menuItems[copy3])
    //    closeMenu()
  }
  
  // MARK: -
  
  func test10CopyWithClickOrEnter() {
    popUpExpandedMenu()
    menuItems[copy1].firstMatch.click()
    assertPasteboardStringEquals(copy1)
    
    popUpExpandedMenu()
    hover(menuItems[copy2].firstMatch)
    app.typeKey(.enter, modifierFlags: [])
    assertPasteboardStringEquals(copy2)
  }
  
  func test11CopyItemTypes() {
    // images
    copyToClipboard(image: image2)
    copyToClipboard(image: image1)
    popUpExpandedMenu()
    checkForBonusFeatures()
    visibleMenuItems[firstHistoryIndex + 1].click()
    assertPasteboardDataCountEquals(image2.tiffRepresentation!.count, forType: .tiff)
    
    // file urls
    copyToClipboard(url: file2)
    copyToClipboard(url: file1)
    popUpExpandedMenu()
    checkForBonusFeatures()
    XCTAssertEqual(visibleMenuItemTitles[firstHistoryIndex...firstHistoryIndex + 1],
                   [file1.absoluteString, file2.absoluteString])
    
    menuItems[file2.absoluteString].firstMatch.click()
    assertPasteboardStringEquals(file2.absoluteString, forType: .fileURL)
    
    // html
    copyToClipboard(data: html2, .html)
    copyToClipboard(data: html1, .html)
    popUpExpandedMenu()
    checkForBonusFeatures()
    XCTAssertEqual(visibleMenuItemTitles[firstHistoryIndex...firstHistoryIndex + 1],
                   ["foo", "bar"])
    
    menuItems["bar"].firstMatch.click()
    assertPasteboardDataEquals(html2, forType: .html)
    
    // rtf - does not work because NSPasteboardItem somehow becomes "empty" ???
    //   copyToClipboard(rtf2, .rtf)
    //   copyToClipboard(rtf1, .rtf)
    //   popUpExpandedMenu()
    //   checkForBonusFeatures()
    //   XCTAssertEqual(visibleMenuItemTitles()[firstHistoryIndex...firstHistoryIndex + 1],
    //                  ["foo", "bar"])
    //
    //   menuItems["bar"].firstMatch.click()
    //   XCTAssertEqual(pasteboard.data(forType: .rtf), rtf2)
  }
  
  // MARK: -
  
  func test20Delete() {
    popUpExpandedMenu()
    hover(menuItems[copy1].firstMatch)
    app.typeKey(.delete, modifierFlags: [.command])
    
    popUpExpandedMenu()
    assertNotExists(menuItems[copy1])
    closeMenu()
  }
  
  func test21Clear() {
    popUpExpandedMenu()
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
  
  // MARK: -
  
  func test30DisablesOnControlControlOptionShiftClickingMenubarIcon() {
    XCUIElement.perform(withKeyModifiers: [.control, .option, .shift]) {
      app.statusItems.firstMatch.click()
    }
    
    let copy3 = UUID().uuidString
    let copy4 = UUID().uuidString
    copyToClipboard(copy3)
    copyToClipboard(copy4)
    
    popUpExpandedMenu()
    assertNotExists(menuItems[copy3])
    assertNotExists(menuItems[copy4])
    closeMenu()
    
    XCUIElement.perform(withKeyModifiers: [.control, .option, .shift]) {
      app.statusItems.firstMatch.click()
    }
  }
  
  func test31DisablesOnlyForNextCopyOnControlOptionClickingMenubarIcon() {
    XCUIElement.perform(withKeyModifiers: [.control, .option]) {
      app.statusItems.firstMatch.click()
    }
    
    let copy3 = UUID().uuidString
    let copy4 = UUID().uuidString
    copyToClipboard(copy3)
    copyToClipboard(copy4)
    
    popUpExpandedMenu()
    assertNotExists(menuItems[copy3])
    assertExists(menuItems[copy4])
    closeMenu()
  }
  
}
