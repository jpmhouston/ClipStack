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
  var visibleMenuItemTitles: [String] { visibleMenuItems.map({ $0.title }) }
  
  override func setUp() {
    super.setUp()
    app.launchArguments.append("ui-testing")
    app.launch()
    
    copyToClipboard(copy2)
    copyToClipboard(copy1)
  }
  
  override func tearDown() {
    super.tearDown()
    app.terminate()
  }
  
  // MARK: -
  
  func popUpUnexpandedMenu() {
    app.statusItems.firstMatch.click()
    waitUntilPoppedUp()
  }
  
  func popUpExpandedMenu() {
    XCUIElement.perform(withKeyModifiers: [.option]) {
      app.statusItems.firstMatch.click()
    }
    waitUntilPoppedUp()
  }
  
  func popUpWithMouse() {
    popUpExpandedMenu()
  }
  
  func waitUntilPoppedUp() {
    if !app.menuItems.firstMatch.waitForExistence(timeout: 3) {
      XCTFail("Cleepp menu did not open")
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
  
  func assertExists(_ element: XCUIElement) {
    expectation(for: NSPredicate(format: "exists = 1"), evaluatedWith: element)
    waitForExpectations(timeout: 3)
  }
  
  func assertNotExists(_ element: XCUIElement) {
    expectation(for: NSPredicate(format: "exists = 0"), evaluatedWith: element)
    waitForExpectations(timeout: 3)
  }
  
  func assertNotVisible(_ element: XCUIElement) {
    expectation(
      for: NSPredicate(format: "(exists = 0) || (isHittable = 0)"), evaluatedWith: element)
    waitForExpectations(timeout: 3)
  }
  
  func assertPasteboardDataEquals(
    _ expected: Data?, forType: NSPasteboard.PasteboardType = .string
  ) {
    let predicate = NSPredicate { (object, _) -> Bool in
      guard let copy = object as? Data else {
        return false
      }
      
      return self.pasteboard.data(forType: forType) == copy
    }
    expectation(for: predicate, evaluatedWith: expected)
    waitForExpectations(timeout: 3)
  }
  
  func assertPasteboardDataCountEquals(
    _ expected: Int, forType: NSPasteboard.PasteboardType = .string
  ) {
    let predicate = NSPredicate { (object, _) -> Bool in
      guard let count = object as? Int else {
        return false
      }
      
      return self.pasteboard.data(forType: forType)!.count == count
    }
    expectation(for: predicate, evaluatedWith: expected)
    waitForExpectations(timeout: 3)
  }
  
  func assertPasteboardStringEquals(
    _ expected: String?, forType: NSPasteboard.PasteboardType = .string
  ) {
    let predicate = NSPredicate { (object, _) -> Bool in
      guard let copy = object as? String else {
        return false
      }
      
      return self.pasteboard.string(forType: forType) == copy
    }
    expectation(for: predicate, evaluatedWith: expected)
    waitForExpectations(timeout: 3)
  }
  
  func assertSelected(_ element: XCUIElement) {
    expectation(for: NSPredicate(format: "isSelected = 1"), evaluatedWith: element)
    waitForExpectations(timeout: 3)
  }
  
  func assertSearchFieldValue(_ string: String) {
    XCTAssertEqual(app.searchFields.firstMatch.value as? String, string)
  }
  
}

// swiftlint:enable type_body_length
// swiftlint:enable file_length
