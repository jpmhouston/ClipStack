import KeyboardShortcuts

extension KeyboardShortcuts.Name {
  // define these merely so code referring to them need not change
  static let popup = Name("popup")
  static let pin = Name("pin")
  static let delete = Name("delete")
  
  // special copy that starts queue mode
  static let queuedCopy = Name("queuedCopy", default: Shortcut(.c, modifiers: [.command, .control]))
  // special paste that advances to next in the queue if in queue mode
  static let queuedPaste = Name("queuedPaste", default: Shortcut(.v, modifiers: [.command, .control]))
}
