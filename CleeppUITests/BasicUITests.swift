import Carbon
import XCTest

class BasicUITests: CleeppUITestBase {
  
  let firstHistoryIndex = 7
  
  func test00MenuContainsAddedItems() {
    popUpExpandedMenu()
    assertExists(menuItems[copy1])
    assertExists(menuItems[copy2])
    app.typeKey(.escape, modifierFlags: [])
    
    let copy3 = UUID().uuidString
    copyToClipboard(copy3)
    popUpExpandedMenu()
    assertExists(menuItems[copy3])
    app.typeKey(.escape, modifierFlags: [])
    
    // currently the app doesn't update the menu while its open
//    popUpExpandedMenu()
//    let copy3 = UUID().uuidString
//    copyToClipboard(copy3)
//    assertExists(menuItems[copy3])
//    app.typeKey(.escape, modifierFlags: [])
  }
  
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
    visibleMenuItems[firstHistoryIndex + 1].click()
    assertPasteboardDataCountEquals(image2.tiffRepresentation!.count, forType: .tiff)
    
    // file urls
    copyToClipboard(url: file2)
    copyToClipboard(url: file1)
    popUpExpandedMenu()
    XCTAssertEqual(visibleMenuItemTitles[firstHistoryIndex...firstHistoryIndex + 1],
                   [file1.absoluteString, file2.absoluteString])
    
    menuItems[file2.absoluteString].firstMatch.click()
    assertPasteboardStringEquals(file2.absoluteString, forType: .fileURL)
    
    // html
    copyToClipboard(data: html2, .html)
    copyToClipboard(data: html1, .html)
    popUpExpandedMenu()
    XCTAssertEqual(visibleMenuItemTitles[firstHistoryIndex...firstHistoryIndex + 1],
                   ["foo", "bar"])
    
    menuItems["bar"].firstMatch.click()
    assertPasteboardDataEquals(html2, forType: .html)
    
    // rtf - does not work because NSPasteboardItem somehow becomes "empty" ???
//   copyToClipboard(rtf2, .rtf)
//   copyToClipboard(rtf1, .rtf)
//   popUpWithHotkey()
//   XCTAssertEqual(visibleMenuItemTitles()[firstHistoryIndex...firstHistoryIndex + 1],
//                  ["foo", "bar"])
//
//   menuItems["bar"].firstMatch.click()
//   XCTAssertEqual(pasteboard.data(forType: .rtf), rtf2)
  }
  
  func test20Delete() {
    popUpExpandedMenu()
    hover(menuItems[copy1].firstMatch)
    app.typeKey(.delete, modifierFlags: [.command])
    
    popUpExpandedMenu()
    assertNotExists(menuItems[copy1])
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
  }
  
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
    
    app.typeKey(.escape, modifierFlags: [])
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
  }
  
#if false // these use cleepp bonus features, move elsewhere

  func testSearch() {
    popUpExpandedMenu()
    search(copy2)
    assertSearchFieldValue(copy2)
    assertExists(menuItems[copy2])
    assertSelected(menuItems[copy2].firstMatch)
    assertNotExists(menuItems[copy1])
  }

  func testSearchFiles() {
    copyToClipboard(url: file2)
    copyToClipboard(url: file1)
    popUpExpandedMenu()
    search(file2.lastPathComponent)
    assertExists(menuItems[file2.absoluteString])
    assertSelected(menuItems[file2.absoluteString].firstMatch)
    assertNotExists(menuItems[file1.absoluteString])
  }

//  func testDeleteEntryDuringSearch() {
//    popUpExpandedMenu()
//    search(copy2)
//    hover(menuItems[copy2].firstMatch)
//    app.typeKey(.delete, modifierFlags: [.option])
//    assertNotExists(menuItems[copy2])
//    // assertSelected(menuItems[copy1].firstMatch) maybe put this back in
//
//    // !!! want to simulate click in close box here
//
//    app.typeKey(.escape, modifierFlags: [])
//    popUpExpandedMenu()
//    assertNotExists(menuItems[copy2])
//  }

  func testClearSearchWithEscape() {
    popUpExpandedMenu()
    search("foo bar")
    app.typeKey(.escape, modifierFlags: [])
    assertSearchFieldValue("")
  }

  func testRemoveLastWordFromSearchWithControlW() {
    popUpExpandedMenu()
    search("foo bar")
    app.typeKey("w", modifierFlags: [.control])
    assertSearchFieldValue("foo ")
  }

  func testAllowsToFocusSearchField() {
    popUpExpandedMenu()
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
  }

  func testTypeToSearchWithFieldUnfocused() {
    popUpExpandedMenu()
    app.typeKey("a", modifierFlags: [])
    waitForSearch()
    assertSearchFieldValue("a")
  }

  func testClearDuringSearch() {
    popUpExpandedMenu()
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
  }

#endif

}
