//
//  PagedWindow.swift
//  ClipStack
//
//  Created by Pierre Houston on 2024-03-07.
//  Copyright © 2024 Bananameter Labs. All rights reserved.
//

import AppKit

@objc protocol PagedWindowControllerDelegate {
  func willOpen() -> Int // return desired starting page number
  func willShowPage(_ number: Int) -> NSButton?
  func shouldLeavePage(_ number: Int) -> Bool
  func shouldSkipPage(_ number: Int) -> Bool
  func willClose()
}

// MARK: -

public class PagedWindowController: NSWindowController, NSWindowDelegate {
  // should make its class UnresponsiveScrollView so it igores scroll gestures
  @IBOutlet var scrollView: NSScrollView!
  @IBOutlet var contentSubview: NSView! { didSet { if isWindowLoaded { useView(contentSubview) } } }
  @IBOutlet var backButton: NSButton!
  @IBOutlet var nextButton: NSButton!
  @IBOutlet var doneButton: NSButton!
  
  @IBOutlet weak var pageDelegate: PagedWindowControllerDelegate?
  
  var isOpen = false
  weak var altDefaultButton: NSButton?
  
  private var rightToLeft: Bool { false } // TODO: set based on system language direction
  
  // MARK: -
  
  public override func windowDidLoad() {
    window?.delegate = self
    
    if let scrollView = scrollView, let contentSubview = contentSubview {
      // permit contentSubview outlet be set initially to a view outside the scrollview
      if scrollView.contentView != contentSubview.superview {
        useView(contentSubview)
      }
    }
  }
  
  public func windowWillClose(_ notification: Notification) {
    finishPreviousPage()
    pageDelegate?.willClose()
    isOpen = false
  }
  
  func useView(_ view: NSView) {
    if let existingSubview = contentSubview {
      if view == existingSubview { // do nothing if already set to this view
        return
      }
      existingSubview.removeFromSuperview()
    }
    
    // perhaps should remove exsting views within scrollView.contentView, like this?
    //for priorSubview in scrollView.contentView.subviews {
    //  priorSubview.removeFromSuperview()
    //}
    
    contentSubview = view
    scrollView.contentView.addSubview(view)
    scrollView.contentView.bounds.origin = NSPoint.zero
  }
  
  func reset(opening: Bool = true) {
    // if resetting without opening then reset to page 0, was going to have a separate delegate method but :shrug:
    var startingPageNumber = 0
    if opening {
      startingPageNumber = pageDelegate?.willOpen() ?? 0
    }
    
    if contentSubview == nil { // perhaps should wrap in #if DEBUG
      setupTestViews()
    }
    
    if let delegate = pageDelegate {
      // when there's a page delegate some pages may be invisible, skip over those
      while startingPageNumber <= lastPageNumber {
        if !delegate.shouldSkipPage(startingPageNumber) {
          break
        }
        startingPageNumber += 1
      }
      if startingPageNumber > lastPageNumber {
        startingPageNumber = 0 // if all invisible then show page 0 after all, tough noogies delegate
        // maybe instead scan backwards from the original startingPageNumber?
      }
    }
    
    setupNextPage(startingPageNumber)
    
    if opening {
      isOpen = true
    }
  }
  
  @discardableResult
  private func finishPreviousPage() -> Bool {
    altDefaultButton?.keyEquivalent = ""
    altDefaultButton = nil
    
    return pageDelegate?.shouldLeavePage(currentPageNumber) ?? true
  }
  
  private func setupNextPage(_ pageNumber: Int) {
    altDefaultButton = pageDelegate?.willShowPage(pageNumber)
    scroll(toPage: pageNumber)
    updateButtons()
  }
  
  private func updateButtons() {
    backButton.isEnabled = !isAtTheStart
    
    // Window seems to get confused if multiple buttons have keyEquivalent set to Return
    // even though the other buttons with it set are hidden, so here need to clear
    // keyEquivalent on a button that's hidden.
    
    // pick which button, next or done, is visible
    let visibleButton: NSButton
    let returnKey = "\r"
    if !isAtTheEnd {
      nextButton.isHidden = false
      visibleButton = nextButton // keyEquivalent set below if there's no altDefaultButton
      doneButton.isHidden = true
      if doneButton.keyEquivalent == returnKey {
        doneButton.keyEquivalent = ""
      }
    } else {
      doneButton.isHidden = false
      visibleButton = doneButton // keyEquivalent set below if there's no altDefaultButton
      nextButton.isHidden = true
      if nextButton.keyEquivalent == returnKey {
        nextButton.keyEquivalent = ""
      }
    }
    
    // pick which buttons is default (by having keyEquivalent set to the return character)
    // the visible one picked above, or the one provided for the page
    if let userButton = altDefaultButton {
      if visibleButton.keyEquivalent == returnKey {
        visibleButton.keyEquivalent = ""
      }
      userButton.keyEquivalent = returnKey
    } else {
      if visibleButton.keyEquivalent.isEmpty {
        visibleButton.keyEquivalent = returnKey
      }
    }
  }
  
  // MARK: -
  
  @IBAction
  func advance(_ sender: AnyObject) {
    var nextPageNumber = currentPageNumber + 1
    
    if !finishPreviousPage() {
      return
    }
    
    if let delegate = pageDelegate {
      // when there's a page delegate some pages may be invisible, skip over those
      while nextPageNumber <= lastPageNumber {
        if !delegate.shouldSkipPage(nextPageNumber) {
          break
        }
        nextPageNumber += 1
      }
      if nextPageNumber > lastPageNumber {
        return
      }
    } else {
      // when no page delegate all pages are visible, just sanity check we're not already at the end
      guard !isAtTheEnd else {
        return
      }
    }
    
    setupNextPage(nextPageNumber)
  }
  
  @IBAction
  func rewind(_ sender: AnyObject) {
    var nextPageNumber = currentPageNumber - 1
    
    if !finishPreviousPage() {
      return
    }

    if let delegate = pageDelegate {
      // when there's a page delegate some pages may be invisible, skip over those
      while nextPageNumber >= 0 {
        if !delegate.shouldSkipPage(nextPageNumber) {
          break
        }
        nextPageNumber -= 1
      }
      if nextPageNumber < 0 {
        return
      }
    } else {
      // when no page delegate all pages are visible, just sanity check we're not already at the start
      guard !isAtTheStart, nextPageNumber >= 0 else {
        return
      }
    }
    
    setupNextPage(nextPageNumber)
  }
  
  // MARK: -
  // TODO: respect rightToLeft
  
  var isAtTheStart: Bool {
    if currentPageNumber <= 0 {
      return true
    }
    
    // also return true if at the start of the visible pages
    if let delegate = pageDelegate {
      for page in stride(from: currentPageNumber - 1, through: 0, by: -1) {
        if !delegate.shouldSkipPage(page) {
          return false
        }
      }
      return true // all pages before the current one were invisible!
    }
    
    return false
  }
  
  var isAtTheEnd: Bool {
    if currentPageNumber >= lastPageNumber {
      return true
    }
    
    // also return true if at the end of the visible pages
    if let delegate = pageDelegate {
      for page in currentPageNumber + 1 ... lastPageNumber {
        if !delegate.shouldSkipPage(page) {
          return false
        }
      }
      return true // all pages after the current one were invisible!
    }
    
    return false
  }
  
  var numberOfPages: Int {
    // last page number irrespecive of pages that aren't visible
    guard let scrollView = scrollView, let content = contentSubview else {
      return 0
    }
    
    let contentBounds = scrollView.contentView.bounds
    let entireWidth = content.bounds.size.width
    return Int(entireWidth / contentBounds.width)
    // remaining width off the end of the content that isn't a multiple of the scrollview's width will not be shown
  }
  
  var lastPageNumber: Int {
    let total = numberOfPages
    return if total == 0 { 0 } else { total - 1 }
  }
  
  var currentPageNumber: Int {
    guard let scrollView = scrollView else {
      return 0
    }
    
    let contentBounds = scrollView.contentView.bounds
    //print("x: \(contentBounds.origin.x), x/width: \(contentBounds.origin.x / contentBounds.width)")
    let result = Int(contentBounds.origin.x / contentBounds.width)
    
    assert(result <= lastPageNumber)
    return result

  }
  
  private func scroll(toPage page: Int) {
    guard let scrollView = scrollView else {
      return
    }
    
    let contentBounds = scrollView.contentView.bounds
    let scrollXCoordinate = CGFloat(page) * contentBounds.width
    //print("scrolling to x = \(scrollXCoordinate)")
    
    scrollView.contentView.scroll(to: NSPoint(x: scrollXCoordinate, y: 0))
    
    // alternate? from tip from https://christiantietze.de/posts/2017/07/nsscrollview-scroll-without-knobs-flashing/
    //scrollView.contentView.bounds.origin = point
  }
  
  func setupTestViews() {
    guard let scrollView = scrollView else {
      return
    }
    let contentBounds = scrollView.contentView.bounds
    
    if let contentSubview = contentSubview {
      for subview in contentSubview.subviews {
        subview.removeFromSuperview()
      }
    } else {
      useView(NSView(frame: contentBounds))
    }
    guard let contentSubview = contentSubview else {
      return
    }

    contentSubview.frame = NSRect(x: 0, y: 0, width: contentBounds.width * 3.0, height: contentBounds.height)
    
    for i in 0..<3 {
      let subview = NSView(frame: NSRect(x: CGFloat(i) * contentBounds.width, y: 0, width: contentBounds.width, height: contentBounds.height))
      subview.wantsLayer = true
      subview.layer?.backgroundColor =
        switch i {
        case 0:
          NSColor.red.cgColor
        case 1:
          NSColor.green.cgColor
        default:
          NSColor.blue.cgColor
        }
      contentSubview.addSubview(subview)
    }
    scrollView.reflectScrolledClipView(scrollView.contentView)
  }
  
}

// MARK: -

public class UnresponsiveScrollView : NSScrollView {
  override public func scrollWheel(with event: NSEvent) {
    // do nothing so as to prevent scrolling by swipe gesture
  }
}

