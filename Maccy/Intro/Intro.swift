//
//  Intro.swift
//  ClipStack
//
//  Created by Pierre Houston on 2024-03-01.
//  Copyright © 2024 Bananameter Labs. All rights reserved.
//

import AppKit

extension NSWindow.FrameAutosaveName {
  static let cleeppIntro: NSWindow.FrameAutosaveName = "lol.bananameter.cleepp.intro.FrameAutosaveName"
}

public class UnresponsiveScrollView : NSScrollView {
  override public func scrollWheel(with event: NSEvent) {
    // do nothing
  }
}

public class IntroWindowController: NSWindowController {
  
  @IBOutlet var scrollView: NSScrollView!
  @IBOutlet var introView: NSView!
  @IBOutlet var previousButton: NSButton!
  @IBOutlet var nextButton: NSButton!
  @IBOutlet var doneButton: NSButton!
  
  private var rightToLeft: Bool { false } // TODO: set based on system language direction
  
  static func load(owner: Any) -> IntroWindowController? {
    guard let nib = NSNib(nibNamed: "Intro", bundle: nil) else {
      return nil
    }
    var nibObjects: NSArray? = NSArray()
    nib.instantiate(withOwner: owner, topLevelObjects: &nibObjects)
    let controller = nibObjects?.compactMap({ $0 as? IntroWindowController }).first
    
    // make sure its not initially visible
    controller?.window?.orderOut(controller)
    
    return controller
  }
  
  @objc
  func openIntro() {
    setupTestViews()
    scroll(toPage: 0)
    updateButtons()
    
    showWindow(self)
    restoreWindowPosition()
    #if compiler(>=5.9) && canImport(AppKit)
    if #available(macOS 14, *) {
      NSApp.activate()
    } else {
      NSApp.activate(ignoringOtherApps: true)
    }
    #else
    NSApp.activate(ignoringOtherApps: true)
    #endif
    
    window?.orderFrontRegardless()
  }
  
  private func restoreWindowPosition() {
    guard let window else {
      return
    }
    
    window.center()
    window.setFrameUsingName(.cleeppIntro)
    window.setFrameAutosaveName(.cleeppIntro)
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
    guard !isAtTheEnd else {
      return
    }
    scroll(toPage: currentPage + 1)
    updateButtons()
  }
  
  @IBAction
  func rewind(_ sender: AnyObject) {
    guard !isAtTheStart, currentPage > 0 else {
      return
    }
    scroll(toPage: currentPage - 1)
    updateButtons()
  }
  
  // TODO: respect rightToLeft
  
  private var isAtTheStart: Bool {
    guard let scrollView = scrollView else {
      return true
    }
    
    let contentBounds = scrollView.contentView.bounds
    print("isAtTheStart \(contentBounds.origin.x == 0.0), x: \(contentBounds.origin.x)")
    return contentBounds.origin.x == 0.0
  }
  
  private var isAtTheEnd: Bool {
    guard let scrollView = scrollView, let introView = introView else {
      return true
    }
    
    let contentBounds = scrollView.contentView.bounds
    let entireWidth = introView.bounds.size.width
    let right = contentBounds.origin.x + contentBounds.size.width
    print("isAtTheEnd \(right == entireWidth), x: \(contentBounds.origin.x), right: \(right), width: \(contentBounds.size.width), entireWidth: \(entireWidth)")
    return right == entireWidth
  }
  
  private var currentPage: Int {
    guard let scrollView = scrollView else {
      return 0
    }
    
    let contentBounds = scrollView.contentView.bounds
    print("x: \(contentBounds.origin.x), x/width: \(contentBounds.origin.x / contentBounds.width)")
    return Int(contentBounds.origin.x / contentBounds.width)
  }
  
  private func scroll(toPage page: Int) {
    guard let scrollView = scrollView else {
      return
    }
    
    let contentBounds = scrollView.contentView.bounds
    let scrollXCoordinate = CGFloat(page) * contentBounds.width
    print("scrolling to x = \(scrollXCoordinate)")
    
    scrollView.contentView.scroll(to: NSPoint(x: scrollXCoordinate, y: 0))
    
    // alternate tip from https://christiantietze.de/posts/2017/07/nsscrollview-scroll-without-knobs-flashing/
    //scrollView.contentView.bounds.origin = point
  }
  
  private func setupTestViews() {
    guard let scrollView = scrollView, let view = introView else {
      return
    }
    let contentBounds = scrollView.contentView.bounds
    
    for subview in view.subviews {
      subview.removeFromSuperview()
    }
    view.frame = NSRect(x: 0, y: 0, width: contentBounds.width * 3.0, height: contentBounds.height)
    
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
      view.addSubview(subview)
    }
    scrollView.reflectScrolledClipView(scrollView.contentView)
  }
  
}
