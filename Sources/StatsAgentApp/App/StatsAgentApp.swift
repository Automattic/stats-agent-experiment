import AppKit
import SwiftUI

/// The proof of concept's app: logging in to WordPress.com and picking a site, then a question box, the agent's cards
/// for each question, and the feedback form, with a Go menu to move between the questions.
///
///     make run
@main
struct StatsAgentApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Window("Stats agent", id: "main") {
            if let question = AskMode.question {
                AskModeView(question: question)
            } else if Previews.folder != nil {
                Color.clear
            } else {
                RootView(account: appDelegate.account, questions: appDelegate.questions)
            }
        }
        .defaultSize(width: Previews.size.width, height: Previews.size.height)
        .commands {
            QuestionCommands()
        }
    }
}

/// `swift run` starts a bare executable rather than an app bundle. This makes it a regular app with a Dock icon, whose
/// window can take the keyboard, and asks macOS to bring it to the front, which macOS can decline. Closing the window
/// quits it.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    // Made on first use, so ask mode and previews, which use neither, never read the keychain or open the database.
    lazy var questions = Questions(recorder: Recorder())
    lazy var account = Account()

    func applicationDidFinishLaunching(_ notification: Notification) {
        if let folder = Previews.folder {
            NSApp.setActivationPolicy(.accessory)
            Task { await Previews.run(in: folder) }
            return
        }
        guard AskMode.question == nil else {
            NSApp.setActivationPolicy(.accessory)
            return
        }
        NSApp.setActivationPolicy(.regular)
        NSApp.activate()
    }

    /// Not in ask mode or previews, which hide the window and quit when they're done.
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        AskMode.question == nil && Previews.folder == nil
    }
}
