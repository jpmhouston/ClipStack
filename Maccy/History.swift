import AppKit

class History {
  var all: [HistoryItem] {
    // TODO: remove sort control in storage settings panel and UserDefaults proprty sortBy
    let sorter = Sorter(by: "lastCopiedAt")
    var items = sorter.sort(HistoryItem.all)
    
    // trim results and the database based on size setting, but if queueing then also ensure to include it entirely
    let maxItems = max(UserDefaults.standard.size, Maccy.queueSize)
    while items.count > maxItems {
      remove(items.removeLast())
    }
    
    return items
  }
  
  var first: HistoryItem? {
    let sorter = Sorter(by: "lastCopiedAt")
    return sorter.first(HistoryItem.all)
  }
  
  var count: Int {
    HistoryItem.count
  }

  private var sessionLog: [Int: HistoryItem] = [:]

  init() {
    UserDefaults.standard.register(defaults: [UserDefaults.Keys.size: UserDefaults.Values.size])
    if ProcessInfo.processInfo.arguments.contains("ui-testing") {
      clear()
    }
  }

  func add(_ item: HistoryItem) {
    // TODO: maybe keep this exception, maybe give up on coalescing duplicates altogether
    if !Maccy.queueModeOn {
      while let existingHistoryItem = findSimilarItem(item) {
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
