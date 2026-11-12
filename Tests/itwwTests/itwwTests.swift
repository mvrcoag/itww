import Carbon.HIToolbox
import Foundation
import Testing
@testable import itww

@Suite("itww Core Tests")
struct ITWWTests {
    @Test("WordDiff detects replacements while preserving unchanged text")
    func wordDiffReplacement() {
        let original = "i has a gramar eror here."
        let revised = "I have a grammar error here."
        let segments = WordDiff.compute(original: original, revised: revised)

        let reconstructedRevised = segments
            .filter { $0.kind != .removed }
            .map(\.text)
            .joined()
        let reconstructedOriginal = segments
            .filter { $0.kind != .added }
            .map(\.text)
            .joined()

        #expect(reconstructedRevised == revised)
        #expect(reconstructedOriginal == original)
        #expect(segments.contains(where: { $0.kind == .removed }))
        #expect(segments.contains(where: { $0.kind == .added }))
    }

    @Test("WordDiff returns single unchanged segment for identical strings")
    func wordDiffIdentical() {
        let text = "Clean sentence with zero mistakes."
        let segments = WordDiff.compute(original: text, revised: text)
        #expect(segments == [DiffSegment(id: 0, kind: .unchanged, text: text)])
    }

    @Test("RewriteMode strips accidental wrapping quotes and source_text tags")
    func cleanModelOutputQuotes() {
        let cleaned = RewriteMode.cleanModelOutput("\"Fixed the typo.\"", original: "Fixd the typo.")
        #expect(cleaned == "Fixed the typo.")

        let preserved = RewriteMode.cleanModelOutput("\"Keep my quotes.\"", original: "\"Keep my qoutes.\"")
        #expect(preserved == "\"Keep my quotes.\"")

        let tagStripped = RewriteMode.cleanModelOutput("<source_text>\nSharp copy.\n</source_text>", original: "sharp copy")
        #expect(tagStripped == "Sharp copy.")
    }

    @Test("RewriteMode preserves trailing newline when original ended with newline")
    func cleanModelOutputTrailingNewline() {
        let cleaned = RewriteMode.cleanModelOutput("Hello world.", original: "Helo world.\n")
        #expect(cleaned == "Hello world.\n")
    }

    @Test("RewriteMode injects custom instruction and global style rules into both system instructions and prompt")
    func buildPromptAndInstructionsPriority() {
        let sys = RewriteMode.improve.systemInstructions(
            extraRules: "Never use em dashes.",
            customInstruction: "Translate into Spanish"
        )
        #expect(sys.contains("Never use em dashes."))
        #expect(sys.contains("Translate into Spanish"))
        // Should lift the same-language lock when translation is requested
        #expect(!sys.contains("Keep the same language as the input text"))

        let prompt = RewriteMode.improve.buildPrompt(
            for: "can u check this?",
            customInstruction: "make it friendly",
            extraRules: "No emojis."
        )
        #expect(prompt.contains("<source_text>\ncan u check this?\n</source_text>"))
        #expect(prompt.contains("make it friendly"))
        #expect(prompt.contains("No emojis."))
    }

    @Test("HotKeyShortcut formats default Control+Option+I display string")
    func defaultHotKeyDisplay() {
        #expect(HotKeyShortcut.default.displayString == "⌃⌥I")
        let custom = HotKeyShortcut(
            keyCode: UInt32(kVK_Space),
            carbonModifiers: UInt32(optionKey | shiftKey)
        )
        #expect(custom.displayString == "⌥⇧Space")
    }

    @MainActor
    @Test("AppSettings persists shortcut, mode, onboarding flag, and custom style rules")
    func settingsPersistence() {
        let suiteName = "com.mvrcoag.itww.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let settings = AppSettings(defaults: defaults)
        #expect(settings.hasCompletedOnboarding == false)

        let newShortcut = HotKeyShortcut(
            keyCode: UInt32(kVK_ANSI_E),
            carbonModifiers: UInt32(cmdKey | shiftKey)
        )
        settings.shortcut = newShortcut
        settings.defaultMode = .concise
        settings.customStyleRules = "Avoid passive voice."
        settings.hasCompletedOnboarding = true

        let reloaded = AppSettings(defaults: defaults)
        #expect(reloaded.shortcut == newShortcut)
        #expect(reloaded.defaultMode == .concise)
        #expect(reloaded.customStyleRules == "Avoid passive voice.")
        #expect(reloaded.hasCompletedOnboarding == true)
    }
}
