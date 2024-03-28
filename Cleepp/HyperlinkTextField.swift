//
//  HyperlinkTextField.swift
//  Cleepp (App Store)
//
//  Created by Pierre Houston on 2024-03-28.
//  Copyright © 2024 Bananameter Labs. All rights reserved.
//
//  Based on snippits and tips from
//  https://stackoverflow.com/a/56854375/592739
//  https://gist.github.com/mminer/597c1b2c40adcf3c319f7feeade62ed4
//  https://stackoverflow.com/a/21282058/592739
//

import AppKit

class HyperlinkTextField: NSTextField {
  
  override func resetCursorRects() {
    super.resetCursorRects()
    addHyperlinkCursorRects()
  }
  
  override func mouseDown(with event: NSEvent) {
    super.mouseDown(with: event)
    openClickedHyperlink(with: event)
  }
  
  lazy var layoutManager: NSLayoutManager = {
    let layoutManager = NSLayoutManager()
    let textContainer = NSTextContainer(containerSize: bounds.size)
    layoutManager.addTextContainer(textContainer)
    // tried making textStorage just once here too, but it seems layoutManager doesn't keep a
    // strong reference to its textStorage, instead make new one in each call addHyperlinkCursorRects
    return layoutManager
  }()
  
  // Displays a hand cursor when a link is hovered over.
  private func addHyperlinkCursorRects() {
    guard attributedStringValue.length > 0 && !bounds.isEmpty else {
      return
    }
    
    let range = NSRange(location: 0, length: attributedStringValue.length)
    attributedStringValue.enumerateAttribute(.link, in: range) { value, range, _ in
      guard value != nil, let textContainer = layoutManager.textContainers.first else {
        return
      }
      
      let textStorage = NSTextStorage()
      textStorage.setAttributedString(attributedStringValue)
      layoutManager.textStorage = textStorage
      
      textContainer.containerSize = bounds.size
      let rect = layoutManager.boundingRect(forGlyphRange: range, in: textContainer)
      addCursorRect(rect, cursor: .pointingHand)
      
      layoutManager.textStorage = nil
    }
  }
  
  private func openClickedHyperlink(with event: NSEvent) {
    guard attributedStringValue.length > 0 && !bounds.isEmpty, let textContainer = layoutManager.textContainers.first else {
      return
    }
    
    let point = convert(event.locationInWindow, from: nil)
    
    let textStorage = NSTextStorage()
    textStorage.setAttributedString(attributedStringValue)
    layoutManager.textStorage = textStorage
    
    textContainer.containerSize = bounds.size
    let characterIndex = layoutManager.characterIndex(for: point, in: textContainer, fractionOfDistanceBetweenInsertionPoints: nil)
    
    layoutManager.textStorage = nil
    
    guard characterIndex < attributedStringValue.length else {
      return
    }
    let attributes = attributedStringValue.attributes(at: characterIndex, effectiveRange: nil)
    guard let linkAttribute = attributes[.link] else {
      return
    }
    
    // sample code I saw got this attr as a string, i see it as a url. support either possibility
    guard let url = linkAttribute as? URL ?? (linkAttribute as? String).flatMap(URL.init(string:)) else {
      return
    }
    
    NSWorkspace.shared.open(url)
  }
  
}
