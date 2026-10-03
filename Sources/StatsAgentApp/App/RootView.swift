import SwiftUI

/// The window's contents: the login while there's no token, the site list while there's no site or another is being
/// picked, and otherwise the questions. When the site changes, the answer on screen is written to the feedback log.
/// Dates are worked out and shown in the site's time zone, or the Mac's when the site's isn't known.
struct RootView: View {
    let account: Account
    let questions: Questions

    var body: some View {
        Group {
            if account.token == nil {
                LoginView(account: account)
            } else if account.site == nil || account.isChoosingSite {
                SitePickerView(account: account)
            } else {
                QuestionView(questions: questions, account: account)
            }
        }
        .frame(minWidth: 640, minHeight: 560)
        .environment(\.context, account.site?.timeZone.map { StatsContext(timeZone: $0) } ?? .demo)
        .onChange(of: account.site) {
            questions.writeAnswer()
        }
    }
}
