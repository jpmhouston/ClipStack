import Cocoa

class HistoryMenuItem: NSMenuItem {
  var item: HistoryItem?
  var value = ""
  var isHeadOfQueue = false {
    didSet { updateHeadOfQueueIndication() }
  }

  internal var clipboard: Clipboard!

  private let imageMaxWidth: CGFloat = 340.0

  // Assign "empty" title to the image (but it can't be empty string).
  // This is required for onStateImage to render correctly when item is pinned.
  // Otherwise, it's not rendered with the error:
  //
  // GetEventParameter(inEvent, kEventParamMenuTextBaseline, typeCGFloat, NULL, sizeof baseline, NULL, &baseline)
  // returned error -9870 on line 2078 in -[NSCarbonMenuImpl _carbonDrawStateImageForMenuItem:withEvent:]
  private let imageTitle = " "

  private let highlightFont: NSFont = {
    if #available(macOS 11, *) {
      return NSFont.boldSystemFont(ofSize: 13)
    } else {
      return NSFont.boldSystemFont(ofSize: 14)
    }
  }()

  required init(coder: NSCoder) {
    super.init(coder: coder)
  }

  init(item: HistoryItem, clipboard: Clipboard) {
    super.init(title: "", action: #selector(onSelect(_:)), keyEquivalent: "")

    self.clipboard = clipboard
    self.item = item
    self.isHeadOfQueue = false
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
  }

  @objc
  func onSelect(_ sender: NSMenuItem) {
    select()
    // Only call this in the App Store version.
    // AppStoreReview.ask()
  }

  func select() {
    // Can override in children.
  }

  func resizeImage() {
    guard let item, !isImage(item) else {
      return
    }

    loadImage(item)
  }

  func regenerateTitle() {
    guard let item, !isImage(item) else {
      return
    }
    
    item.title = item.generateTitle(item.getContents())
    attributedTitle = nil
    
    updateHeadOfQueueIndication()
  }
  
  func highlight(_ ranges: [ClosedRange<Int>]) {
    guard !ranges.isEmpty, title != imageTitle else {
      regenerateTitle()
      return
    }
    
    let attributedTitle = NSMutableAttributedString(string: title, attributes: isHeadOfQueue ? headOfQueueAttributes() : nil)
    
    for range in ranges {
      let rangeLength = range.upperBound - range.lowerBound + 1
      let highlightRange = NSRange(location: range.lowerBound, length: rangeLength)
      
      if Range(highlightRange, in: title) != nil {
        attributedTitle.addAttribute(.font, value: highlightFont, range: highlightRange)
      }
    }
    
    self.attributedTitle = attributedTitle
  }
  
  private func headOfQueueAttributes() -> [NSAttributedString.Key: Any]? {
    if #unavailable(macOS 14) {
      [.underlineStyle: NSUnderlineStyle.single.rawValue]
    } else {
      nil
    }
  }
  
  private func styleToIndicateHeadOfQueue() {
    // NB: if item has had highlight called, will now lose the styling it set; just assume that won't happen
    if isHeadOfQueue {
      guard title != imageTitle else { return }
      attributedTitle = NSMutableAttributedString(string: title, attributes: headOfQueueAttributes())
    } else {
      attributedTitle = nil
    }
  }
  
  private func badgeToIndicateHeadOfQueue() {
    if #available(macOS 14, *) {
      if isHeadOfQueue {
        badge = NSMenuItemBadge(string: "replay from here \u{2BAD}") // \u{2BAD}
      } else {
        badge = nil
      }
    }
  }
  
  private func updateHeadOfQueueIndication() {
    if #unavailable(macOS 14) {
      styleToIndicateHeadOfQueue()
    } else {
      badgeToIndicateHeadOfQueue()
    }
  }

  private func isImage(_ item: HistoryItem) -> Bool {
    return item.image != nil
  }

  private func isFile(_ item: HistoryItem) -> Bool {
    return item.fileURL != nil
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
      image.size.height = image.size.height / (image.size.width / imageMaxWidth)
      image.size.width = imageMaxWidth
    }

    let imageMaxHeight = CGFloat(UserDefaults.standard.imageMaxHeight)
    if image.size.height > imageMaxHeight {
      image.size.width = image.size.width / (image.size.height / imageMaxHeight)
      image.size.height = imageMaxHeight
    }

    self.image = image
    self.title = imageTitle
  }

  private func loadFile(_ item: HistoryItem) {
    guard let fileURL = item.fileURL,
          let string = fileURL.absoluteString.removingPercentEncoding else {
      return
    }

    self.value = string
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
}
