//
//  Licenses.swift
//  Cleepp
//
//  Created by Pierre Houston on 2024-04-14.
//  Copyright © 2024 Bananameter Labs. All rights reserved.
//

import AppKit

public class LicensesWindowController: NSWindowController {
  
  @IBOutlet var textView: NSTextView?
  
  convenience init() {
    self.init(windowNibName: "Licenses")
  }
  
  public override func awakeFromNib() {
    super.awakeFromNib()
    textView?.usesAdaptiveColorMappingForDarkAppearance = true
  }
  
  func openLicenses() {
    // accessing window triggers loading from nib, do this before showWindow so we can setup before showing
    guard let window = window else {
      return
    }
    
    guard importText() else {
      return
    }
    scrollToTop()
    
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
    
    window.collectionBehavior.formUnion(.moveToActiveSpace)
    window.orderFrontRegardless()
  }
  
  private func restoreWindowPosition() {
    guard let window else {
      return
    }
    
    window.center()
    window.setFrameUsingName(.cleeppIntro)
    window.setFrameAutosaveName(.cleeppIntro)
  }
  
  private func importText() -> Bool {
    #if FOR_APP_STORE
    let filename = "License credits-MAS"
    #else
    let filename = "License credits"
    #endif
    
    guard let textView = textView, let textStorage = textView.textStorage else {
      return false
    }
    if textStorage.length > 0 {
      return true // has contents already, assume been in here once before and results are still around
    }
    
    if let rtfurl = Bundle.main.url(forResource: filename, withExtension: "rtf"),
       textView.read(from: rtfurl, type: .rtf) && textStorage.length > 0
    {
      return true
    }
    
    // fallback to show the markdown as plain text
    if let mdurl = Bundle.main.url(forResource: filename, withExtension: "md"),
       textView.read(from: mdurl, type: .plain) && textStorage.length > 0
    {
      // this backslash removal is now done by the build rule for .mkdn files
      return true
    }
    
    return false
  }
  
  private func scrollToTop() {
    textView?.enclosingScrollView?.documentView?.scroll(.zero)
  }
  
}

// MARK: -

extension NSTextView {
  func read(from url: URL, type: NSAttributedString.DocumentType, defaultAttributes: [NSAttributedString.Key: Any] = [:]) -> Bool {
    guard let textStorage = textStorage else {
      return false
    }
    do {
      var options: [NSAttributedString.DocumentReadingOptionKey: Any] = [.documentType: type]
      if defaultAttributes.count > 0 {
        options[.defaultAttributes] = defaultAttributes
      }
      try textStorage.read(from: url, options: options, documentAttributes: nil, error: ())
      return true
    } catch {
      return false
    }
  }
  
  func read(from url: URL, type: NSAttributedString.DocumentType, font: NSFont) -> Bool {
    return read(from: url, type: type, defaultAttributes: [.font: font])
  }
}
