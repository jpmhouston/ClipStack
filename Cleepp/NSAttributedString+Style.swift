//
//  NSAttributedString+Style.swift
//  Cleepp
//
//  Created by Pierre Houston on 2024-03-11.
//  Copyright © 2024 Bananameter Labs. All rights reserved.
//

import AppKit

extension NSMutableAttributedString {
  func applySimpleStyles(basedOnFont baseFont: NSFont) {
    // currently the only styling supported is bold & italics, indicated by markdown-like ** and _
    let boldMarker = "**"
    let italicsMarker = "_"
    
    let fontMgr = NSFontManager()
    let boldFont = fontMgr.convert(baseFont, toHaveTrait: .boldFontMask)
    let italicsFont = fontMgr.convert(baseFont, toHaveTrait: .italicFontMask)
    
    var scanLocation = 0
    while true {
      if let range = range(delimitedBy: boldMarker, at: scanLocation, removingDelimiters: true) {
        let boldicizedFont: NSFont
        if let existingFont = fontAttributes(in: range)[NSAttributedString.Key.font] as? NSFont {
          boldicizedFont = fontMgr.convert(existingFont, toHaveTrait: .boldFontMask)
        } else {
          boldicizedFont = boldFont
        }
        addAttribute(NSAttributedString.Key.font, value: boldicizedFont, range: range)
        scanLocation = range.location + range.length
      } else {
        break
      }
    }
    
    scanLocation = 0
    while true {
      if let range = range(delimitedBy: italicsMarker, at: scanLocation, removingDelimiters: true) {
        let italicizedFont: NSFont
        if let existingFont = fontAttributes(in: range)[NSAttributedString.Key.font] as? NSFont {
          italicizedFont = fontMgr.convert(existingFont, toHaveTrait: .italicFontMask)
        } else {
          italicizedFont = italicsFont
        }
        addAttribute(NSAttributedString.Key.font, value: italicizedFont, range: range)
        scanLocation = range.location + range.length
      } else {
        break
      }
    }
  }
  
  func range(delimitedBy delimiter1: String, and delimiter2: String? = nil, at location: Int, removingDelimiters remove: Bool) -> NSRange? {
    let startDelimiter = delimiter1
    let endDelimiter = delimiter2 ?? delimiter1
    
    let stringLength = length
    if location >= stringLength {
      return nil
    }
    
    let entireRange = NSRange(location: location, length: stringLength - location)
    let startDelimiterRange = (string as NSString).range(of: startDelimiter, options: [], range: entireRange)
    if startDelimiterRange.location == NSNotFound {
      return nil
    }
    
    var delimitedLocation = startDelimiterRange.location + startDelimiterRange.length
    if delimitedLocation >= stringLength {
      return nil
    }
    
    let remainingRange = NSRange(location: delimitedLocation, length: stringLength - delimitedLocation)
    let endDelimiterRange = (string as NSString).range(of: endDelimiter, options: [], range: remainingRange)
    if endDelimiterRange.location == NSNotFound {
      return nil
    }
    
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
