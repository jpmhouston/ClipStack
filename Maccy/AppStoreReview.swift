import StoreKit

class AppStoreReview {
  class func ask(after times: Int = 50) {
    UserDefaults.standard.numberOfUsages += 1
    if UserDefaults.standard.numberOfUsages < times { return }

    let today = Date()
    let lastReviewRequestDate = UserDefaults.standard.lastReviewRequestedAt
    guard let minimumRequestDate = Calendar.current.date(byAdding: .month, value: 1, to: lastReviewRequestDate),
          today > minimumRequestDate else {
      return
    }

    UserDefaults.standard.lastReviewRequestedAt = today

    DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
      SKStoreReviewController.requestReview()
    }
  }
}
