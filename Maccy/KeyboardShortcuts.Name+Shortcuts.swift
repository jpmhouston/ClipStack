import KeyboardShortcuts

extension KeyboardShortcuts.Name {
  // special copy that starts queue mode
  static let queueCopy = Name("queue-copy", default: Shortcut(.c, modifiers: [.command, .control]))
  // special paste that advances to next in the queue if in queue mode
  static let queuePaste = Name("queue-paste", default: Shortcut(.v, modifiers: [.command, .control]))
  
  static let deleteItem = Name("delete-item", default: Shortcut(.delete, modifiers: [.command]))
}
