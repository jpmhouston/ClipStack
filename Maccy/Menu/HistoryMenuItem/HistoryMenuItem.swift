import Cocoa

extension NSAttributedString.Key {
  static let headIndicator: Self = .init("cleeppqueuehead")
}

class HistoryMenuItem: NSMenuItem {
  var isPinned = false
  var item: HistoryItem?
  var value = ""
  #if CLEEPP
  var isHeadOfQueue = false {
    didSet { updateHeadOfQueueIndication() }
  }
  private let indicatorBadge = NSLocalizedString("first_replay_item_badge", comment: "") + " \u{2BAD}"
  private var useBadges: Bool {
    // return false and comment the rest out to exercise not using badges when on macOS >=14
    if #unavailable(macOS 14) {
      false
    } else {
      !AppDelegate.performingUITest // use badges unless running a UI test
    }
  }
  #endif

  internal var clipboard: Clipboard!

  private let imageMaxWidth: CGFloat = 340.0

  // Assign "empty" title to the image (but it can't be empty string).
  // This is required for onStateImage to render correctly when item is pinned.
  // Otherwise, it's not rendered with the error:
  //
  // GetEventParameter(inEvent, kEventParamMenuTextBaseline, typeCGFloat, NULL, sizeof baseline, NULL, &baseline)
  // returned error -9870 on line 2078 in -[NSCarbonMenuImpl _carbonDrawStateImageForMenuItem:withEvent:]
  private let imageTitle = " "

  private let systemFont: NSFont = {
    if #available(macOS 11, *) {
      return NSFont.systemFont(ofSize: 13)
    } else {
      return NSFont.systemFont(ofSize: 14)
    }
  }()

  private let systemBoldFont: NSFont = {
    if #available(macOS 11, *) {
      return NSFont.boldSystemFont(ofSize: 13)
    } else {
      return NSFont.boldSystemFont(ofSize: 14)
    }
  }()

  private let systemItalicFont: NSFont = {
    var systemFont: NSFont
    if #available(macOS 11, *) {
      systemFont = NSFont.systemFont(ofSize: 13)
    } else {
      systemFont = NSFont.systemFont(ofSize: 14)
    }

    let italicFontDescriptor = systemFont.fontDescriptor.withSymbolicTraits([.italic])

    return NSFont(descriptor: italicFontDescriptor, size: 0) ?? systemFont
  }()

  private var editPinObserver: NSKeyValueObservation?
  private var editTitleObserver: NSKeyValueObservation?

  required init(coder: NSCoder) {
    super.init(coder: coder)
  }

#if CLEEPP
  // define this to avoid this mysterious runtime failure:
  // Fatal error: Use of unimplemented initializer 'init(title:action:keyEquivalent:)' for class 'Cleepp.HistoryMenuItem'
  override init(title: String, action: Selector?, keyEquivalent: String) {
    super.init(title: title, action: action, keyEquivalent: keyEquivalent)
  }
  
  func configured(withItem item: HistoryItem, distinguishForDebugging: Bool = false) -> Self {
    self.item = item
    
    if isImage(item) {
      loadImage(item)
    } else if isFile(item) {
      loadFile(item)
    } else if isText(item) {
      loadText(item)
    } else if isRTF(item) {
      loadRTF(item)
    } else if isHTML(item) {
      loadHTML(item)
    }
    
    if distinguishForDebugging {
      let attributedTitle = NSMutableAttributedString(string: title, attributes: [.underlineStyle: NSUnderlineStyle.single.rawValue])
      self.attributedTitle = attributedTitle
    }
    return self
  }
  
#else
  init(item: HistoryItem, clipboard: Clipboard) {
    super.init(title: "", action: #selector(onSelect(_:)), keyEquivalent: "")

    self.clipboard = clipboard
    self.item = item
    self.onStateImage = NSImage(named: "PinImage")
    self.target = self

    if isImage(item) {
      loadImage(item)
    } else if isFile(item) {
      loadFile(item)
    } else if isText(item) {
      loadText(item)
    } else if isRTF(item) {
      loadRTF(item)
    } else if isHTML(item) {
      loadHTML(item)
    }

    if let itemPin = item.pin {
      pin(itemPin)
    }

    alternate()

    editPinObserver = item.observe(\.pin, options: .new, changeHandler: { item, _ in
      self.keyEquivalent = item.pin ?? ""
    })
    editTitleObserver = item.observe(\.title, options: .new, changeHandler: { item, _ in
      self.title = item.title ?? ""
    })
  }
#endif

  deinit {
    editPinObserver?.invalidate()
    editTitleObserver?.invalidate()
  }

  @objc
  func onSelect(_ sender: NSMenuItem) {
    select()
    // Only call this in the App Store version.
    // AppStoreReview.ask()
  }

  func select() {
    // Override in children.
  }

  func alternate() {
    isAlternate = true
    // isHidden is implicit in macOS 14.4 and completely prevents selecting hidden item.
    if #unavailable(macOS 14.4) {
      isHidden = true
    }
  }

  func pin(_ pin: String) {
    item?.pin = pin
    self.isPinned = true
    self.keyEquivalent = pin
    self.state = .on
  }

  func unpin() {
    item?.pin = nil
    self.isPinned = false
    self.keyEquivalent = ""
    self.state = .off
  }

  func resizeImage() {
    guard let item, !isImage(item) else {
      return
    }

    loadImage(item)
  }

  func regenerateTitle() {
    guard let item, !isImage(item), !isPinned else {
      return
    }

    item.title = item.generateTitle(item.getContents())
  }

  func highlight(_ ranges: [ClosedRange<Int>]) {
    guard !ranges.isEmpty, title != imageTitle else {
      self.attributedTitle = nil
      return
    }

    let attributedTitle = NSMutableAttributedString(string: title)
    for range in ranges {
      let rangeLength = range.upperBound - range.lowerBound + 1
      let highlightRange = NSRange(location: range.lowerBound, length: rangeLength)

      if Range(highlightRange, in: title) != nil {
        switch UserDefaults.standard.highlightMatches {
        case "italic":
          attributedTitle.addAttribute(.font, value: systemItalicFont, range: highlightRange)
        case "underline":
          attributedTitle.addAttributes([
            .underlineStyle: NSUnderlineStyle.single.rawValue,
            .font: systemFont
          ], range: highlightRange)
        default:
          attributedTitle.addAttribute(.font, value: systemBoldFont, range: highlightRange)
        }
      }
    }

    self.attributedTitle = attributedTitle

    #if CLEEPP
    if isHeadOfQueue && !useBadges {
      styleToIndicateHeadOfQueue()
    }
    #endif
  }

  private func isImage(_ item: HistoryItem) -> Bool {
    return item.image != nil
  }

  private func isFile(_ item: HistoryItem) -> Bool {
    return !item.fileURLs.isEmpty
  }

  private func isRTF(_ item: HistoryItem) -> Bool {
    return item.rtf != nil
  }

  private func isHTML(_ item: HistoryItem) -> Bool {
    return item.html != nil
  }

  private func isText(_ item: HistoryItem) -> Bool {
    return item.text != nil
  }

  private func loadImage(_ item: HistoryItem) {
    guard let image = item.image else {
      return
    }

    if image.size.width > imageMaxWidth {
      image.size.height /= image.size.width / imageMaxWidth
      image.size.width = imageMaxWidth
    }

    let imageMaxHeight = CGFloat(UserDefaults.standard.imageMaxHeight)
    if image.size.height > imageMaxHeight {
      image.size.width /= image.size.height / imageMaxHeight
      image.size.height = imageMaxHeight
    }

    self.image = image
    self.title = imageTitle
  }

  private func loadFile(_ item: HistoryItem) {
    guard !item.fileURLs.isEmpty else {
      return
    }

    self.value = item.fileURLs
      .compactMap { $0.absoluteString.removingPercentEncoding }
      .joined(separator: "\n")
    self.title = item.title ?? ""
    self.image = ColorImage.from(title)
  }

  private func loadRTF(_ item: HistoryItem) {
    guard let string = item.rtf?.string else {
      return
    }

    self.value = string
    self.title = item.title ?? ""
    self.image = ColorImage.from(title)
  }

  private func loadHTML(_ item: HistoryItem) {
    guard let string = item.html?.string else {
      return
    }

    self.value = string
    self.title = item.title ?? ""
    self.image = ColorImage.from(title)
  }

  private func loadText(_ item: HistoryItem) {
    guard let string = item.text else {
      return
    }

    self.value = string
    self.title = item.title ?? ""
    self.image = ColorImage.from(title)
  }
  
#if CLEEPP
  private func updateHeadOfQueueIndication() {
    if useBadges {
      badgeToIndicateHeadOfQueue()
    } else {
      styleToIndicateHeadOfQueue()
    }
  }
  
  private func badgeToIndicateHeadOfQueue() {
    if #available(macOS 14, *) {
      if isHeadOfQueue {
        badge = NSMenuItemBadge(string: indicatorBadge)
      } else {
        badge = nil
      }
    }
  }
  
  private func styleToIndicateHeadOfQueue() {
    // not bulletproof, adding to attributedTitle adds to title too
//    let indicatorPrefix = "\u{261D}\u{FE0E} "
//    var indicatorPrefixLength: Int { (indicatorPrefix as NSString).length }
//    guard title != imageTitle else {
//      return
//    }
//    if let currentStyledTitle = attributedTitle {
//      let indicatorAttributes: [NSAttributedString.Key: Any] = [.font: systemBoldFont, .headIndicator: NSNumber(value: true)]
//      let alreadyPrefixed = currentStyledTitle.attribute(.headIndicator, at: 0, effectiveRange: nil) != nil
//      
//      if isHeadOfQueue && !alreadyPrefixed {
//        let prefixedTitle = NSMutableAttributedString(string: indicatorPrefix as String, attributes: indicatorAttributes)
//        prefixedTitle.append(currentStyledTitle)
//        attributedTitle = prefixedTitle
//        
//      } else if !isHeadOfQueue && !alreadyPrefixed {
//        let unprefixedTitle = NSMutableAttributedString(attributedString: currentStyledTitle)
//        unprefixedTitle.deleteCharacters(in: NSRange(location: 0, length: indicatorPrefixLength))
//      }
//          
//    } else if isHeadOfQueue {
//      let styledTitle = NSMutableAttributedString(string: title, attributes: [.font: systemFont])
//      let prefixedTitle = NSMutableAttributedString(string: indicatorPrefix as String, attributes: [.font: systemBoldFont])
//      prefixedTitle.append(styledTitle)
//      attributedTitle = prefixedTitle
//    }
  }
#endif
  
}
