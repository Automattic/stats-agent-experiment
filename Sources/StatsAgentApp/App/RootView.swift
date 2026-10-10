import SwiftUI

/// The window's contents: the login while there's no token, the site list while there's no site or another is being
/// picked, and otherwise the questions, with the site's name and URL as the window's title and subtitle, and a toolbar
/// menu to switch sites or log out, which waits while an answer is being worked out. When the site changes, the answer
/// on screen goes.
/// Logging out, from the menu or the site list, asks first whether to keep what the database holds, which it suggests
/// so it can still be exported, or to delete it.
/// Dates are worked out and shown in the site's time zone, or the Mac's when the site's isn't known. Every page has the
/// stats screens' background, and WordPress blue as its accent. File → Export Data… opens the export sheet, logged in or
/// not, unless the database couldn't be opened.
struct RootView: View {
    let account: Account
    let questions: Questions
    @State private var isExporting = false
    @State private var isLoggingOut = false
    /// Why deleting the data on logging out failed.
    @State private var deleteError: String?

    var body: some View {
        Group {
            if account.token == nil {
                LoginView(account: account)
            } else if let site = account.site, !account.isChoosingSite {
                QuestionsView(questions: questions, account: account)
                    .navigationTitle(site.title)
                    .navigationSubtitle(site.url)
                    .toolbar {
                        ToolbarItem {
                            Menu("Site", systemImage: "globe") {
                                Button("Switch Site…") { account.isChoosingSite = true }
                                Button("Log Out…") { isLoggingOut = true }
                            }
                            .disabled(!questions.canAsk)
                        }
                    }
            } else {
                SitePickerView(account: account) { isLoggingOut = true }
            }
        }
        // Every page fills the window, so a page with little in it, such as the login, doesn't shrink the window to fit.
        .frame(minWidth: 640, maxWidth: .infinity, minHeight: 560, maxHeight: .infinity)
        .background(Constants.Colors.background)
        .tint(Constants.Colors.blue)
        .environment(\.context, account.site?.timeZone.map { StatsContext(timeZone: $0) } ?? .demo)
        .onChange(of: account.site) {
            questions.clear()
        }
        .sheet(isPresented: $isExporting) {
            ExportView(database: questions.recorder.database)
        }
        .focusedSceneValue(\.isExporting, questions.recorder.database == nil ? nil : $isExporting)
        .confirmationDialog("Log out of WordPress.com?", isPresented: $isLoggingOut) {
            Button("Log Out", action: account.logOut)
                .keyboardShortcut(.defaultAction)
            Button("Log Out and Delete Data", role: .destructive, action: logOutAndDelete)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(
                "Your questions, the agent's answers and your feedback stay on this Mac, so you can still export them to "
                    + "help improve the agent. You can delete them instead."
            )
        }
        .alert(
            "Couldn't delete the data",
            isPresented: Binding(get: { deleteError != nil }, set: { if !$0 { deleteError = nil } })
        ) {
            Button("OK") {}
        } message: {
            Text(deleteError ?? "")
        }
    }

    private func logOutAndDelete() {
        account.logOut()
        Task {
            do {
                try await questions.recorder.deleteEverything()
            } catch {
                deleteError = Answer.message(for: error)
            }
        }
    }
}
