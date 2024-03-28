//
//  NSAttributedString+Style.swift
//  Cleepp
//
//  Created by Pierre Houston on 2024-03-11.
//  Copyright © 2024 Bananameter Labs. All rights reserved.
//

import AppKit

extension NSMutableAttributedString {
  
  @discardableResult
  func applySimpleStyles(basedOnFont baseFont: NSFont, withLink defaultLink: String? = nil) -> Bool {
    // currently the only styling supported is bold & italics, indicated by markdown-like ** and _
    let boldMarker = "**"
    let italicsMarker = "_"
    let linkBeginMarker = "["
    let linkEndMarker = "]"
    let linkURLMarker = "]("
    let linkURLEndMarker = ")"
    
    let fontMgr = NSFontManager()
    let boldFont = fontMgr.convert(baseFont, toHaveTrait: .boldFontMask)
    let italicsFont = fontMgr.convert(baseFont, toHaveTrait: .italicFontMask)
    var didApplyStyle = false
    
    var scanLocation = 0
    while true {
      if let range = styleRange(delimitedBy: boldMarker, at: scanLocation, removingDelimiters: true) {
        let boldicizedFont: NSFont
        if let existingFont = fontAttributes(in: range)[NSAttributedString.Key.font] as? NSFont {
          boldicizedFont = fontMgr.convert(existingFont, toHaveTrait: .boldFontMask)
        } else {
          boldicizedFont = boldFont
        }
        addAttribute(.font, value: boldicizedFont, range: range)
        scanLocation = range.location + range.length
        
        didApplyStyle = true
      } else {
        break
      }
    }
    
    scanLocation = 0
    while true {
      if let range = styleRange(delimitedBy: italicsMarker, at: scanLocation, removingDelimiters: true) {
        let italicizedFont: NSFont
        if let existingFont = fontAttributes(in: range)[NSAttributedString.Key.font] as? NSFont {
          italicizedFont = fontMgr.convert(existingFont, toHaveTrait: .italicFontMask)
        } else {
          italicizedFont = italicsFont
        }
        addAttribute(.font, value: italicizedFont, range: range)
        scanLocation = range.location + range.length
        
        didApplyStyle = true
      } else {
        break
      }
    }
    
    // must do this before the default link one below, o/w it would catch [blah] and leave the (url) part
    scanLocation = 0
    while true {
      if let range = styleRange(delimitedBy: linkBeginMarker, and: linkURLMarker, at: scanLocation, removingDelimiters: true) {
        scanLocation = range.location + range.length
        if let range2 = styleRange(delimitedBy: nil, and: linkURLEndMarker, at: scanLocation, removingDelimiters: true) {
          let link = attributedSubstring(from: range2).string
          if let url = NSURL(string: link) {
            addAttribute(.link, value: url, range: range)
          }
          deleteCharacters(in: range2)
          scanLocation = range.location + range.length
          
          didApplyStyle = true
        }
      } else {
        break
      }
    }
    
    scanLocation = 0
    if let link = defaultLink, let url = NSURL(string: link) {
      while true {
        if let range = styleRange(delimitedBy: linkBeginMarker, and: linkEndMarker, at: scanLocation, removingDelimiters: true) {
          addAttribute(.link, value: url, range: range)
          scanLocation = range.location + range.length
          
          didApplyStyle = true
        } else {
          break
        }
      }
    }
    
    return didApplyStyle
  }
  
  func styleRange(delimitedBy delimiter1: String?, and delimiter2: String? = nil, at location: Int, removingDelimiters remove: Bool) -> NSRange? {
    if delimiter1 == nil && delimiter2 == nil {
      return nil
    }
    if let delimiter1 = delimiter1, delimiter1.isEmpty {
      return nil
    }
    if let delimiter2 = delimiter2, delimiter2.isEmpty {
      return nil
    }
    let startDelimiter = delimiter1 ?? ""
    let endDelimiter = delimiter2 ?? startDelimiter
    
    let stringLength = length
    if location >= stringLength {
      return nil
    }
    
    let entireRange = NSRange(location: location, length: stringLength - location)
    var startDelimiterRange: NSRange
    if !startDelimiter.isEmpty {
      startDelimiterRange = (string as NSString).range(of: startDelimiter, options: [], range: entireRange)
      if startDelimiterRange.location == NSNotFound {
        return nil
      }
    } else {
      startDelimiterRange = NSRange(location: entireRange.location, length: 0)
    }
    
    // get the location inside the start delimeter
    var delimitedLocation = startDelimiterRange.location + startDelimiterRange.length
    if delimitedLocation >= stringLength {
      return nil
    }
    
    let remainingRange = NSRange(location: delimitedLocation, length: stringLength - delimitedLocation)
    let endDelimiterRange = (string as NSString).range(of: endDelimiter, options: [], range: remainingRange)
    if endDelimiterRange.location == NSNotFound {
      return nil
    }
    
    // get the length not up but not including the end delimeter
    let delimitedLength = endDelimiterRange.location - delimitedLocation
    
    if remove {
      // important to remove in this order, in removed start first then the afterwared the end range will be wrong
      deleteCharacters(in: endDelimiterRange)
      deleteCharacters(in: startDelimiterRange)
      delimitedLocation -= startDelimiterRange.length
    }
    
    return NSRange(location: delimitedLocation, length: delimitedLength)
  }
}
