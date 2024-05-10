//
//  CleeppUITestBase.swift
//  Cleepp
//
//  Created by Pierre Houston on 2024-05-06.
//  Copyright © 2024 Bananameter Labs. All rights reserved.
//

import Carbon
import XCTest

// swiftlint:disable file_length
// swiftlint:disable type_body_length

class CleeppUITestBase: XCTestCase {
  
  let app = XCUIApplication()
  let pasteboard = NSPasteboard.general
  
  let copy1 = UUID().uuidString
  let copy2 = UUID().uuidString
  
  // https://hetima.github.io/fucking_nsimage_syntax
  let image1 = NSImage(named: "NSAddTemplate")!
  let image2 = NSImage(named: "NSBluetoothTemplate")!
  
  let file1 = URL(fileURLWithPath: "/tmp/file1")
  let file2 = URL(fileURLWithPath: "/tmp/file2")
  
  let rtf1 = NSAttributedString(string: "foo").rtf(
    from: NSRange(0...2),
    documentAttributes: [:]
  )
  let rtf2 = NSAttributedString(string: "bar").rtf(
    from: NSRange(0...2),
    documentAttributes: [:]
  )
  
  let html1 = "<a href='#'>foo</a>".data(using: .utf8)
  let html2 = "<a href='#'>bar</a>".data(using: .utf8)
  
  // using this instead of app.menuItems should skip scanning all of Xcodes own menus sometimes
  var menuItems: XCUIElementQuery { app.statusItems.firstMatch.descendants(matching: .menuItem) }
  
  var visibleMenuItems: [XCUIElement] { menuItems.allElementsBoundByIndex.filter({ $0.isHittable }) }
  var visibleMenuItemTitles: [String] { visibleMenuItems.map { $0.title } }
  
  static let firstHistoryIndexWithoutBonus = 7
  static let firstHistoryIndexWithBonus = 8
  var firstHistoryIndex = firstHistoryIndexWithoutBonus
  
  var hasBonusFeatures = false
  var hasAccessibilityPermissions = false
  
  override func setUp() {
    super.setUp()
    app.launchArguments.append("ui-testing")
    app.launch()
    
    let introWindow = app.windows["Intro"]
    if !introWindow.exists {
      // this logic valid only if app has launched once before, so could get a false negative
      // before running tests that rely on this, one should manually build & run app then grant permission
      hasAccessibilityPermissions = true
    } else {
      introWindow.buttons[XCUIIdentifierCloseWindow].click()
    }
    
//    if isMenuOpen {
//      print("menu is open for some reason after detecting intro window, clicking status item to get it to close")
//      closeMenu()
//    }
    
    copyToClipboard(copy2)
    copyToClipboard(copy1)
    
//    if isMenuOpen {
//      print("menu is open for some reason before exiting setUp(), clicking status item to get it to close")
//      closeMenu()
//    }
  }
  
  override func tearDown() {
    super.tearDown()
    app.terminate()
  }
  
  // MARK: -
  
  func openUnexpandedMenu() {
    if isMenuOpen {
      app.statusItems.firstMatch.click()
    }
    app.statusItems.firstMatch.click()
    waitUntilMenuOpened()
  }
  
  func openExpandedMenu() {
    if isMenuOpen {
      app.statusItems.firstMatch.click()
    }
    XCUIElement.perform(withKeyModifiers: [.option]) {
      app.statusItems.firstMatch.click()
      waitUntilMenuOpened()
    }
  }
  
  func waitUntilMenuOpened() {
    if !menuItems.firstMatch.waitForExistence(timeout: 10) {
      XCTFail("Cleepp menu did not open")
    }
  }
  
  var isMenuOpen: Bool {
    menuItems.firstMatch.exists
  }
  
  func closeMenu() {
    if isMenuOpen {
      app.statusItems.firstMatch.click()
    }
  }
  
  func checkForBonusFeatures() {
    // should call this with the menu open before using firstHistoryIndex or hasBonusFeatures
    let pasteAppItem = menuItems["Paste All"]
    if pasteAppItem.exists && pasteAppItem.isHittable {
      hasBonusFeatures = true
      firstHistoryIndex = Self.firstHistoryIndexWithoutBonus
    }
  }
  
  func copyToClipboard(_ content: String) {
    pasteboard.clearContents()
    pasteboard.setString(content, forType: .string)
    waitTillClipboardCheck()
  }
  
  func copyToClipboard(image content: NSImage) {
    pasteboard.clearContents()
    pasteboard.setData(content.tiffRepresentation, forType: .tiff)
    waitTillClipboardCheck()
  }
  
  func copyToClipboard(url content: URL) {
    pasteboard.clearContents()
    pasteboard.setData(content.dataRepresentation, forType: .fileURL)
    // WTF: The subsequent writes to pasteboard are not
    // visible unless we explicitly read the last one?!
    pasteboard.string(forType: .fileURL)
    waitTillClipboardCheck()
  }
  
  func copyToClipboard(data content: Data?, _ type: NSPasteboard.PasteboardType) {
    pasteboard.clearContents()
    pasteboard.setData(content, forType: type)
    waitTillClipboardCheck()
  }
  
  // Default interval for Cleepp to check clipboard is 1 second
  func waitTillClipboardCheck() {
    usleep(1_500_000)
  }
  
  func hover(_ element: XCUIElement) {
    element.hover()
    usleep(50_000)
  }
  
  var isInQueueMode: Bool {
    // app.statusItems.firstMatch.title.trimmingCharacters(in: .whitespaces)
    app.statusItems.firstMatch.title != ""
  }
  
  func enterQueueMode() {
    guard !isInQueueMode else {
      return
    }
    XCUIElement.perform(withKeyModifiers: [.control]) {
      app.statusItems.firstMatch.click()
    }
    assertInQueueMode()
  }
  
  func exitQueueMode() {
    guard isInQueueMode else {
      return
    }
    XCUIElement.perform(withKeyModifiers: [.control]) {
      app.statusItems.firstMatch.click()
    }
    assertNotInQueueMode()
  }
  
  func search(_ string: String) {
    // NOTE: app.typeText is broken in Sonoma and causes some
    //       Chars to be submitted with a .command mask (e.g. 'p', 'k' or 'j')
    string.forEach {
      app.typeKey("\($0)", modifierFlags: [])
    }
    waitForSearch()
  }
  
  func waitForSearch() {
    // NOTE: This is a hack and is flaky.
    // Ideally we should wait for a proper condition to detect that search has settled down.
    usleep(500_000)  // wait for search throttle
  }
  
  func waitUntilNotBusy() {
    let predicate = NSPredicate { _, _ in
      self.openUnexpandedMenu()
      let items = self.app.statusItems.firstMatch.descendants(matching: .menuItem)
      let ready = items["Copy & Collect"].isHittable
      self.closeMenu()
      return ready
    }
    expectation(for: predicate, evaluatedWith: nil)
    waitForExpectations(timeout: 10)
  }
  
  func clickWhenExists(_ element: XCUIElement) {
    expectation(for: NSPredicate(format: "exists = 1"), evaluatedWith: element)
    waitForExpectations(timeout: 10)
    if element.exists {
      element.click()
    }
  }
  
  func assertExists(_ element: XCUIElement) {
    // debugging expansion for when element is a menu item
//    let predicate = NSPredicate { object, _ in
//      guard let element = object as? XCUIElement else {
//        return false
//      }
//      let exists = element.exists
//      if !exists && !self.isMenuOpen { print("element doesn't exist, perhaps becuase menu not open?") }
//      else if !exists { print("element doesn't exist, menu items: \(self.menuItems.allElementsBoundByIndex.map { $0.title })") }
//      return exists
//    }
//    expectation(for: predicate, evaluatedWith: element)
    expectation(for: NSPredicate(format: "exists = 1"), evaluatedWith: element)
    waitForExpectations(timeout: 10)
  }
  
  func assertNotExists(_ element: XCUIElement) {
    expectation(for: NSPredicate(format: "exists = 0"), evaluatedWith: element)
    waitForExpectations(timeout: 10)
  }
  
  func assertNotVisible(_ element: XCUIElement) {
    expectation(
      for: NSPredicate(format: "(exists = 0) || (isHittable = 0)"), evaluatedWith: element)
    waitForExpectations(timeout: 10)
  }
  
  func assertInQueueMode() {
    if isInQueueMode {
      return
    }
    let menu = app.statusItems.firstMatch
    expectation(for: NSPredicate(format: "title != ''"), evaluatedWith: menu)
    waitForExpectations(timeout: 10)
  }
  
  func assertNotInQueueMode() {
    if !isInQueueMode {
      return
    }
    let menu = app.statusItems.firstMatch
    expectation(for: NSPredicate(format: "title = ''"), evaluatedWith: menu)
    waitForExpectations(timeout: 10)
  }
  
  func assertPasteboardDataEquals(
    _ expected: Data?, forType: NSPasteboard.PasteboardType = .string
  ) {
    let predicate = NSPredicate { object, _ in
      guard let copy = object as? Data else {
        return false
      }
      return self.pasteboard.data(forType: forType) == copy
    }
    expectation(for: predicate, evaluatedWith: expected)
    waitForExpectations(timeout: 10)
  }
  
  func assertPasteboardDataCountEquals(
    _ expected: Int, forType: NSPasteboard.PasteboardType = .string
  ) {
    let predicate = NSPredicate { object, _ in
      guard let count = object as? Int else {
        return false
      }
      return (self.pasteboard.data(forType: forType)?.count ?? 0) == count
    }
    expectation(for: predicate, evaluatedWith: expected)
    waitForExpectations(timeout: 10)
  }
  
  func assertPasteboardStringEquals(
    _ expected: String?, forType: NSPasteboard.PasteboardType = .string
  ) {
    let predicate = NSPredicate { object, _ in
      guard let copy = object as? String else {
        return false
      }
      return self.pasteboard.string(forType: forType) == copy
    }
    expectation(for: predicate, evaluatedWith: expected)
    waitForExpectations(timeout: 10)
  }
  
  func assertSelected(_ element: XCUIElement) {
    expectation(for: NSPredicate(format: "isSelected = 1"), evaluatedWith: element)
    waitForExpectations(timeout: 10)
  }
  
  func assertSearchFieldValue(_ string: String) {
    XCTAssertEqual(app.searchFields.firstMatch.value as? String, string)
  }
  
  /*
  func openTestWindow() {
    let testWindow = app.windows["Cleepp Test Window"]
    if testWindow.exists {
      return
    }
    openUnexpandedMenu()
    let openWindowItem = menuItems["Show Test Window"]
    assertExists(openWindowItem)
    openWindowItem.click()
    if !openWindowItem.waitForExistence(timeout: 1) {
      XCTFail("Cleepp test window did not open")
    }
  }
  
  func closeTestWindow() {
    let testWindow = app.windows["Cleepp Test Window"]
    if !testWindow.exists {
      return
    }
    openUnexpandedMenu()
    let closeWindowItem = menuItems["Hide Test Window"]
    assertExists(closeWindowItem)
    closeWindowItem.click()
  }
  
  func typeNSelect(_ str: String) {
    guard str.count > 0 else {
      return
    }
    let testWindow = app.windows["Cleepp Test Window"]
    let text = testWindow.textViews.firstMatch
    if !text.exists {
      XCTFail("Cleepp test window is not already open")
    }
    
    // "failed to synthesize event: Neither element nor any descendant has keyboard focus"
    //text.click()
    //text.typeText(str)
    
    app.typeText(str)
    for _ in 0 ..< str.count {
      app.typeKey(.leftArrow, modifierFlags: [.shift])
    }
  }
  */
  
}

// swiftlint:enable type_body_length
// swiftlint:enable file_length
