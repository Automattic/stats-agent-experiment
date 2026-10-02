import AppKit
import SwiftUI

/// The proof of concept's app: a question box, the agent's cards for each question, and the feedback form.
///
///     swift run stats-agent-app
@main
struct StatsAgentApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Window("Stats agent", id: "main") {
            QuestionView(questions: appDelegate.questions)
        }
        .defaultSize(width: 760, height: 900)
    }
}

/// `swift run` starts a bare executable rather than an app bundle. This makes it a regular app with a Dock icon, whose
/// window can take the keyboard, and asks macOS to bring it to the front, which macOS can decline. Closing the window
/// quits it, and quitting writes the answer on screen to the feedback log with the feedback it has, if any.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let questions = Questions()

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

    func applicationWillTerminate(_ notification: Notification) {
        questions.writeAnswer()
    }
}
