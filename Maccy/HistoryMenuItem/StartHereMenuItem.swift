import AppKit

extension HistoryMenuItem {
  class StartHereMenuItem: HistoryMenuItem {
    
    required init(coder: NSCoder) {
      super.init(coder: coder)
    }
    
    override init(item: HistoryItem, clipboard: Clipboard) {
      super.init(item: item, clipboard: clipboard)
      
      keyEquivalentModifierMask = []
    }
    
    override func select() {
      // TODO: call whatever to start queue mode
      clipboard.copy(item) // TODO: either make new call that copies without adding to menu, or change existing copy to do that
    }
    
  }
}
