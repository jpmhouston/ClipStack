import AppKit
import KeyboardShortcuts
import Sauce

enum KeyChord: CaseIterable {
  // Fetch paste from Edit / Paste menu item.
  // Fallback to ⌘V if unavailable.
  static var pasteKey: Key {
    (NSApp.delegate as? AppDelegate)?.pasteMenuItem.key ?? .v
  }
  static var pasteKeyModifiers: NSEvent.ModifierFlags {
    (NSApp.delegate as? AppDelegate)?.pasteMenuItem.keyEquivalentModifierMask ?? [.command]
  }
  
  case clearHistory
  case clearHistoryAll
  case clearSearch
  case deleteCurrentItem
  case deleteOneCharFromSearch
  case deleteLastWordFromSearch
  case ignored
  case moveToNext
  case moveToPrevious
  case openPreferences
  case paste
  case selectCurrentItem
  case unknown
  
  // swiftlint:disable cyclomatic_complexity
  init(_ key: Key, _ modifierFlags: NSEvent.ModifierFlags) {
    switch (key, modifierFlags) {
    case (Key(character: MenuFooter.clear.keyEquivalent, virtualKeyCode: nil), MenuFooter.clear.keyEquivalentModifierMask):
      self = .clearHistory
    case (Key(character: MenuFooter.clearAll.keyEquivalent, virtualKeyCode: nil), MenuFooter.clearAll.keyEquivalentModifierMask):
      self = .clearHistoryAll
    case (Key(character: MenuFooter.preferences.keyEquivalent, virtualKeyCode: nil), MenuFooter.preferences.keyEquivalentModifierMask):
      self = .openPreferences
    case (.escape, []), (.u, [.control]):
      self = .clearSearch
    case (.delete, []), (.h, [.control]):
      self = .deleteOneCharFromSearch
    case (.w, [.control]):
      self = .deleteLastWordFromSearch
    case (.j, [.control]):
      self = .moveToNext
    case (.k, [.control]):
      self = .moveToPrevious
    case (.return, _), (.keypadEnter, _):
      self = .selectCurrentItem
    case (.delete, [.command]):
      self = .deleteCurrentItem
    case (KeyChord.pasteKey, KeyChord.pasteKeyModifiers):
      self = .paste
    case (GlobalCopyHotKey.key, GlobalCopyHotKey.modifierFlags): // when menu showing want this global shortcut to do nothing
      self = .ignored
    case (GlobalPasteHotKey.key, GlobalPasteHotKey.modifierFlags): // when menu showing want this global shortcut to do nothing
      self = .ignored
    case (_, _) where Self.keysToSkip.contains(key) || !modifierFlags.isDisjoint(with: Self.modifiersToSkip):
      self = .ignored
    default:
      self = .unknown
    }
  }
  // swiftlint:enable cyclomatic_complexity
  
  private static let keysToSkip = [
    Key.home,
    Key.pageUp,
    Key.pageDown,
    Key.end,
    Key.downArrow,
    Key.leftArrow,
    Key.rightArrow,
    Key.upArrow,
    Key.escape,
    Key.tab,
    Key.f1,
    Key.f2,
    Key.f3,
    Key.f4,
    Key.f5,
    Key.f6,
    Key.f7,
    Key.f8,
    Key.f9,
    Key.f10,
    Key.f11,
    Key.f12,
    Key.f13,
    Key.f14,
    Key.f15,
    Key.f16,
    Key.f17,
    Key.f18,
    Key.f19
  ]
  private static let modifiersToSkip = NSEvent.ModifierFlags([
    .command,
    .control,
    .option
  ])
  
}
