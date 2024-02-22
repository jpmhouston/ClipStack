import AppKit

extension HistoryMenuItem {
  class ReplayMenuItem: HistoryMenuItem {
    
    required init(coder: NSCoder) {
      super.init(coder: coder)
    }
    
    override init(item: HistoryItem, clipboard: Clipboard) {
      super.init(item: item, clipboard: clipboard)
      
      keyEquivalentModifierMask = []
    }
    
  }
}
