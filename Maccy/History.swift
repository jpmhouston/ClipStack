import AppKit

class History {
  var all: [HistoryItem] {
    let sorter = Sorter(by: UserDefaults.standard.sortBy)
    
    // TODO: if we still want to limit showing UserDefaults.standard.size in the menu, i dont think this the right place to do it
    // TODO: ... or if this is supposed to be a limit on the number of items stored, still, is this where we should do it
    // TODO: ... but also how would that interfere with someone queue-copying more than that many times
//    var items = sorter.sort(HistoryItem.all)
//    while items.count > UserDefaults.standard.size {
//      remove(items.removeLast())
//    }
    
    return sorter.sort(HistoryItem.all)
  }

  private var sessionLog: [Int: HistoryItem] = [:]

  init() {
    UserDefaults.standard.register(defaults: [UserDefaults.Keys.size: UserDefaults.Values.size])
    if ProcessInfo.processInfo.arguments.contains("ui-testing") {
      clear()
    }
  }

  func add(_ item: HistoryItem) {
    // TODO: fix how duplicates work, definitely don't remove previous, probably don't even check
    if let existingHistoryItem = findSimilarItem(item) {
      if isModified(item) == nil {
        item.contents = existingHistoryItem.contents
      }
      item.firstCopiedAt = existingHistoryItem.firstCopiedAt
      item.numberOfCopies += existingHistoryItem.numberOfCopies
      item.title = existingHistoryItem.title
      if !item.fromMaccy {
        item.application = existingHistoryItem.application
      }
      remove(existingHistoryItem)
    }

    // used to do here: Notifier.notify(body: item.title, sound: .write)
    
    sessionLog[Clipboard.shared.changeCount] = item
    CoreDataManager.shared.saveContext()
  }

  func update(_ item: HistoryItem?) {
    CoreDataManager.shared.saveContext()
  }

  func remove(_ item: HistoryItem?) {
    guard let item else { return }

    item.getContents().forEach(CoreDataManager.shared.viewContext.delete(_:))
    CoreDataManager.shared.viewContext.delete(item)
  }

  // TODO: will be removed, not sure if we want a special version of clear in its place or not
  func clearUnpinned() {
    all.forEach(remove(_:)) // was: all.filter({ $0.pin == nil }).forEach(remove(_:))
  }

  func clear() {
    all.forEach(remove(_:))
  }

  private func findSimilarItem(_ item: HistoryItem) -> HistoryItem? {
    let duplicates = all.filter({ $0 == item || $0.supersedes(item) })
    if duplicates.count > 1 {
      return duplicates.first(where: { $0.objectID != item.objectID })
    } else {
      return isModified(item)
    }
  }

  private func isModified(_ item: HistoryItem) -> HistoryItem? {
    if let modified = item.modified, sessionLog.keys.contains(modified) {
      return sessionLog[modified]
    }

    return nil
  }
}
