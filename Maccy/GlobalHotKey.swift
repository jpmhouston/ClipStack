import AppKit
import KeyboardShortcuts
import Sauce

class GlobalCopyHotKey {
  typealias Handler = () -> Void

  static public var key: Key? {
    guard let key = KeyboardShortcuts.Shortcut(name: .queueCopy)?.key else {
      return nil
    }
    return Sauce.shared.key(for: key.rawValue)
  }
  static public var modifierFlags: NSEvent.ModifierFlags? { KeyboardShortcuts.Shortcut(name: .queueCopy)?.modifiers }

  private var handler: Handler

  init(_ handler: @escaping Handler) {
    self.handler = handler
    KeyboardShortcuts.onKeyDown(for: .queueCopy, action: handler)
  }
}

class GlobalPasteHotKey {
  typealias Handler = () -> Void

  static public var key: Key? {
    guard let key = KeyboardShortcuts.Shortcut(name: .queuePaste)?.key else {
      return nil
    }
    return Sauce.shared.key(for: key.rawValue)
  }
  static public var modifierFlags: NSEvent.ModifierFlags? { KeyboardShortcuts.Shortcut(name: .queuePaste)?.modifiers }

  private var handler: Handler

  init(_ handler: @escaping Handler) {
    self.handler = handler
    KeyboardShortcuts.onKeyDown(for: .queuePaste, action: handler)
  }
}
