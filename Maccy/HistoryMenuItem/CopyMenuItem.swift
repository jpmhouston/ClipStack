import AppKit

extension HistoryMenuItem {
  class CopyMenuItem: HistoryMenuItem {
    
    required init(coder: NSCoder) {
      super.init(coder: coder)
    }
    
    override init(item: HistoryItem, clipboard: Clipboard) {
      super.init(item: item, clipboard: clipboard)
      
      keyEquivalentModifierMask = .option
      isAlternate = true
      isHidden = true
    }
    
  }
}
