import AppKit
import SwiftUI

/// The proof of concept's app: logging in to WordPress.com and picking a site, then a question box, the agent's cards
/// for each question, and the feedback form.
///
///     make run
@main
struct StatsAgentApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Window("Stats agent", id: "main") {
            if let question = AskMode.question {
                AskModeView(question: question)
            } else {
                RootView(account: appDelegate.account, questions: appDelegate.questions)
            }
        }
        .defaultSize(width: 760, height: 900)
    }
}

/// `swift run` starts a bare executable rather than an app bundle. This makes it a regular app with a Dock icon, whose
/// window can take the keyboard, and asks macOS to bring it to the front, which macOS can decline. Closing the window
/// quits it.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    // Made on first use, so ask mode, which uses neither, never reads the keychain or opens the database.
    lazy var questions = Questions(recorder: Recorder())
    lazy var account = Account()

    func applicationDidFinishLaunching(_ notification: Notification) {
        guard AskMode.question == nil else {
            NSApp.setActivationPolicy(.accessory)
            return
        }
        NSApp.setActivationPolicy(.regular)
        NSApp.activate()
    }

    /// Not in ask mode, which hides the window and quits when it's done.
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        AskMode.question == nil
    }
}
