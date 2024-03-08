//
//  PagedWindow.swift
//  ClipStack
//
//  Created by Pierre Houston on 2024-03-07.
//  Copyright © 2024 p0deje. All rights reserved.
//

import AppKit

@objc protocol PagedWindowControllerDelegate {
  func willOpen()
  func willShowPage(_ number: Int)
  func shouldSkipPage(_ number: Int) -> Bool
  func willClose()
}

public class PagedWindowController: NSWindowController, NSWindowDelegate {
  // should make its class UnresponsiveScrollView so it igores scroll gestures
  @IBOutlet var scrollView: NSScrollView!
  @IBOutlet var contentSubview: NSView! { didSet { if isWindowLoaded { useView(contentSubview) } } }
  @IBOutlet var previousButton: NSButton!
  @IBOutlet var nextButton: NSButton!
  @IBOutlet var doneButton: NSButton!
  
  @IBOutlet weak var pageDelegate: PagedWindowControllerDelegate?
  
  private var rightToLeft: Bool { false } // TODO: set based on system language direction
  
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
    pageDelegate?.willClose()
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
  
  func reset() {
    var firstPageNumber = 0
    
    if contentSubview == nil { // TODO: perhaps wrap in #if DEBUG
      setupTestViews()
    }
    
    if let delegate = pageDelegate {
      // when there's a page delegate some pages may be invisible, skip over those
      while firstPageNumber <= lastPageNumber {
        if !delegate.shouldSkipPage(firstPageNumber) {
          break
        }
        firstPageNumber += 1
      }
      if firstPageNumber > lastPageNumber {
        firstPageNumber = 0 // if all invisible then show page 0 after all, tough noogies
      }
      
      // and call the delegate
      delegate.willShowPage(firstPageNumber)
    }
    
    scroll(toPage: firstPageNumber)
    updateButtons()
    
    pageDelegate?.willOpen()
  }
  
  private func updateButtons() {
    previousButton.isEnabled = !isAtTheStart
    
    // window might be getting confused if multiple buttons have keyEquivalent set to Return
    // clearing keyEquivalent on the button that's hidden, setting on the one showing, seems solid
    let returnKey = "\r"
    if !isAtTheEnd {
      doneButton.isHidden = true
      doneButton.keyEquivalent = ""
      nextButton.isHidden = false
      if nextButton.keyEquivalent.isEmpty {
        nextButton.keyEquivalent = returnKey
      }
    } else {
      nextButton.isHidden = true
      nextButton.keyEquivalent = ""
      doneButton.isHidden = false
      if doneButton.keyEquivalent.isEmpty {
        doneButton.keyEquivalent = returnKey
      }
    }
  }
  
  @IBAction
  func advance(_ sender: AnyObject) {
    var nextPageNumber = currentPageNumber + 1
    
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
      
      // and call the delegate
      delegate.willShowPage(nextPageNumber)
    } else {
      // when no page delegate all pages are visible, just sanity check we're not already at the end
      guard !isAtTheEnd else {
        return
      }
    }
    
    scroll(toPage: nextPageNumber)
    updateButtons()
  }
  
  @IBAction
  func rewind(_ sender: AnyObject) {
    var nextPageNumber = currentPageNumber - 1
    
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
      
      // and call the delegate
      delegate.willShowPage(nextPageNumber)
    } else {
      // when no page delegate all pages are visible, just sanity check we're not already at the start
      guard !isAtTheStart, nextPageNumber >= 0 else {
        return
      }
    }
    
    scroll(toPage: nextPageNumber)
    updateButtons()
  }
  
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
//    guard let scrollView = scrollView, let content = contentSubview else {
//      return true
//    }
//    let contentBounds = scrollView.contentView.bounds
//    let entireWidth = content.bounds.size.width
//    let right = contentBounds.origin.x + contentBounds.size.width
//    print("isAtTheEnd \(right == entireWidth), x: \(contentBounds.origin.x), right: \(right), width: \(contentBounds.size.width), entireWidth: \(entireWidth)")
//    if right == entireWidth {
//      return true
//    }
    
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

public class UnresponsiveScrollView : NSScrollView {
  override public func scrollWheel(with event: NSEvent) {
    // do nothing so as to prevent scrolling by swipe gesture
  }
}

