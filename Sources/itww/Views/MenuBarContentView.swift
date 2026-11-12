import AppKit
import SwiftUI

public struct MenuBarContentView: View {
    let controller: AppController

    public init(controller: AppController) {
        self.controller = controller
    }

    public var body: some View {
        Button("Improve Selected Text (\(controller.settings.shortcut.displayString))") {
            Task { @MainActor in
                await controller.handleHotKeyTriggered()
            }
        }

        Button("Improve Clipboard Text") {
            controller.improveClipboardNow()
        }

        Divider()

        Menu("Default Mode: \(controller.settings.defaultMode.title)") {
            ForEach(RewriteMode.allCases) { mode in
                Button {
                    controller.settings.defaultMode = mode
                } label: {
                    if controller.settings.defaultMode == mode {
                        Label(mode.title, systemImage: "checkmark")
                    } else {
                        Text(mode.title)
                    }
                }
            }
        }

        Divider()

        switch controller.modelReadiness {
        case .ready(let detail):
            Text("✓ \(detail)")
        case .unavailable(let title, _):
            Text("⚠ \(title)")
        }

        if !controller.isAccessibilityTrusted {
            Button("Grant Accessibility Permission…") {
                controller.promptAccessibility()
            }
        }

        Divider()

        Button("Welcome & Permissions…") {
            controller.openWelcomeWindow()
        }

        Button("Settings…") {
            controller.openSettingsWindow()
        }
        .keyboardShortcut(",", modifiers: .command)

        Button("Quit itww") {
            NSApplication.shared.terminate(nil)
        }
        .keyboardShortcut("q", modifiers: .command)
    }
}
