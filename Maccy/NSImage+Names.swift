import Cocoa

extension NSImage.Name {
  static let cleepMenuIcon = NSImage.Name("cleepp.clipboard")
  static let cleepMenuIconFill = NSImage.Name("cleepp.clipboard.fill")
  static let cleepMenuIconFillPlus = NSImage.Name("cleepp.clipboard.fill.badge.plus")
  static let cleepMenuIconList = NSImage.Name("cleepp.list.clipboard.fill")
  static let cleepMenuIconListPlus = NSImage.Name("cleepp.list.clipboard.fill.badge.plus")
  static let cleepMenuIconListMinus = NSImage.Name("cleepp.list.clipboard.fill.badge.minus")

  static let clipboard = NSImage.Name("clipboard.fill")
  static let externaldrive = loadName("externaldrive")
  static let gearshape = loadName("gearshape")
  static let gearshape2 = loadName("gearshape.2")
  static let maccyStatusBar = NSImage.Name("StatusBarMenuImage")
  static let nosign = loadName("nosign")
  static let paintpalette = loadName("paintpalette")
  static let pincircle = loadName("pin.circle")
  static let scissors = NSImage.Name("scissors")
  static let currency = loadName("currency")

  private static func loadName(_ name: String) -> NSImage.Name {
    if #available(macOS 11, *) {
      return NSImage.Name("\(name).svg")
    } else {
      return NSImage.Name("\(name).png")
    }
  }
}
