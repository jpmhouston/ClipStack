import AppKit

extension HistoryMenuItem {
  class CopyMenuItem: HistoryMenuItem {
    
    required init(coder: NSCoder) {
      super.init(coder: coder)
    }
    
    override init(item: HistoryItem, clipboard: Clipboard, target: AnyObject?, action: Selector?) {
      super.init(item: item, clipboard: clipboard, target: target, action: action)
      
      keyEquivalentModifierMask = []
    }
    
  }
}
