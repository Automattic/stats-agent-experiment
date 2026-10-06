import SwiftUI

/// The window's contents: the login while there's no token, the site list while there's no site or another is being
/// picked, and otherwise the questions, with the site's name and URL as the window's title and subtitle, and a toolbar
/// menu to switch sites or log out, which waits while an answer is being worked out. When the site changes, the answer
/// on screen goes.
/// Dates are worked out and shown in the site's time zone, or the Mac's when the site's isn't known. Every page has the
/// stats screens' background, and WordPress blue as its accent.
struct RootView: View {
    let account: Account
    let questions: Questions

    var body: some View {
        Group {
            if account.token == nil {
                LoginView(account: account)
            } else if let site = account.site, !account.isChoosingSite {
                QuestionView(questions: questions, account: account)
                    .navigationTitle(site.title)
                    .navigationSubtitle(site.url)
                    .toolbar {
                        ToolbarItem {
                            Menu("Site", systemImage: "globe") {
                                Button("Switch Site…") { account.isChoosingSite = true }
                                Button("Log Out", action: account.logOut)
                            }
                            .disabled(!questions.canAsk)
                        }
                    }
            } else {
                SitePickerView(account: account)
            }
        }
        .frame(minWidth: 640, minHeight: 560)
        .background(Constants.Colors.background)
        .tint(Constants.Colors.blue)
        .environment(\.context, account.site?.timeZone.map { StatsContext(timeZone: $0) } ?? .demo)
        .onChange(of: account.site) {
            questions.clear()
        }
    }
}
