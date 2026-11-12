import AppKit
import SwiftUI

public struct HUDView: View {
    @Bindable var controller: AppController
    @FocusState private var focusedField: Field?

    private enum Field {
        case manualInput
        case customPrompt
    }

    private let quickTweaks: [(label: String, prompt: String)] = [
        ("Shorter", "Make it noticeably shorter and tighter."),
        ("Casual", "Keep the tone warm, casual, and conversational."),
        ("Direct", "Cut all fluff and get straight to the point."),
        ("→ Spanish", "Translate the text into natural Spanish."),
        ("→ English", "Translate the text into natural English.")
    ]

    public init(controller: AppController) {
        self.controller = controller
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            headerBar
            Divider().opacity(0.5)
            modeStrip
            Divider().opacity(0.5)
            mainContent
            Divider().opacity(0.5)
            customInstructionBar
            Divider().opacity(0.5)
            footerBar
        }
        .frame(width: 580)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.14), lineWidth: 1)
        )
    }

    // MARK: - Header (Draggable)

    private var headerBar: some View {
        HStack(spacing: 8) {
            // Left + middle area is an explicit AppKit window drag surface
            ZStack(alignment: .leading) {
                WindowDragHandle()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                HStack(spacing: 8) {
                    Capsule()
                        .fill(Color.primary.opacity(0.22))
                        .frame(width: 22, height: 4)
                        .help("Drag to move window")

                    Image(systemName: "sparkles")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.tint)

                    Text("itww")
                        .font(.system(size: 13, weight: .semibold))

                    if let appName = controller.sourceAppName {
                        Text("· \(appName)")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }

                    if let backend = controller.backendUsedLabel {
                        Text(backend)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.primary.opacity(0.06), in: Capsule())
                    }

                    if let appliedInstruction = controller.appliedInstructionBadge {
                        Text(appliedInstruction)
                            .lineLimit(1)
                            .truncationMode(.tail)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(Color.accentColor)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 2)
                            .frame(maxWidth: 150)
                            .background(Color.accentColor.opacity(0.14), in: Capsule())
                    }

                    Spacer(minLength: 8)
                }
                .allowsHitTesting(false)
            }
            .frame(height: 26)

            Button {
                controller.settings.showDiff.toggle()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: controller.settings.showDiff ? "eye.fill" : "eye")
                        .font(.system(size: 11))
                    Text("Diff")
                        .font(.system(size: 11, weight: .medium))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(
                    controller.settings.showDiff ? Color.accentColor.opacity(0.18) : Color.primary.opacity(0.06),
                    in: Capsule()
                )
            }
            .buttonStyle(.plain)
            .help("Toggle inline word diff (⌘D)")

            Button {
                controller.openSettingsWindow()
            } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("Settings")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
    }

    // MARK: - Mode Strip

    private var modeStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(RewriteMode.allCases) { mode in
                    let isSelected = (controller.selectedMode == mode)
                    Button {
                        controller.selectMode(mode)
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: mode.symbolName)
                                .font(.system(size: 11))
                            Text(mode.title)
                                .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
                            Text("⌘\(mode.indexShortcut)")
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(
                            isSelected ? Color.accentColor.opacity(0.2) : Color.primary.opacity(0.05),
                            in: Capsule()
                        )
                        .overlay(
                            Capsule().strokeBorder(
                                isSelected ? Color.accentColor.opacity(0.55) : Color.clear,
                                lineWidth: 1
                            )
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
        }
    }

    // MARK: - Main Content

    @ViewBuilder
    private var mainContent: some View {
        switch controller.state {
        case .needsAccessibility:
            accessibilityCard
        case .emptySelection, .idle:
            manualInputCard
        case .streaming, .ready:
            outputCard
        case .failed(let message):
            errorCard(message)
        }
    }

    private var accessibilityCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Accessibility access required", systemImage: "hand.raised.fill")
                .font(.system(size: 13, weight: .semibold))

            Text("itww needs macOS Accessibility permission to read your selected text and paste the improved version back into the active app.")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 8) {
                Button("Grant Accessibility Access") {
                    controller.promptAccessibility()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)

                Button("Use Clipboard Instead") {
                    controller.loadClipboardIntoManualInput()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var manualInputCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("No text selection detected. Type or paste text to improve:")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Paste Clipboard") {
                    controller.loadClipboardIntoManualInput()
                }
                .buttonStyle(.bordered)
                .controlSize(.mini)
            }

            TextEditor(text: $controller.sourceText)
                .font(.system(size: 13))
                .scrollContentBackground(.hidden)
                .padding(8)
                .frame(minHeight: 110, maxHeight: 160)
                .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 8))
                .focused($focusedField, equals: .manualInput)
                .onAppear {
                    focusedField = .manualInput
                }

            HStack {
                Spacer()
                Button("Improve Text") {
                    controller.startGeneration()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .disabled(controller.sourceText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(14)
    }

    private var outputCard: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                if controller.state == .streaming && controller.improvedText.isEmpty {
                    HStack(spacing: 8) {
                        ProgressView()
                            .controlSize(.small)
                        Text("Apple Intelligence is rewriting…")
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 18)
                } else if controller.settings.showDiff && controller.state == .ready {
                    diffTextView
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    Text(controller.improvedText)
                        .font(.system(size: 14))
                        .lineSpacing(3)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                if controller.state == .ready && controller.improvedText == controller.sourceText {
                    Label("No grammar or phrasing issues found.", systemImage: "checkmark.seal.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(.green)
                }
            }
            .padding(16)
        }
        .frame(minHeight: 130, maxHeight: 260)
    }

    private var diffTextView: Text {
        let segments = WordDiff.compute(original: controller.sourceText, revised: controller.improvedText)
        var attributed = AttributedString()
        for segment in segments {
            var part = AttributedString(segment.text)
            switch segment.kind {
            case .unchanged:
                part.font = .system(size: 14)
            case .removed:
                part.font = .system(size: 14)
                part.strikethroughStyle = .single
                part.strikethroughColor = .red
                part.foregroundColor = .red.opacity(0.85)
                part.backgroundColor = .red.opacity(0.10)
            case .added:
                part.font = .system(size: 14, weight: .medium)
                part.foregroundColor = .green
                part.backgroundColor = .green.opacity(0.12)
            }
            attributed.append(part)
        }
        return Text(attributed)
    }

    private func errorCard(_ message: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Could not improve text", systemImage: "exclamationmark.triangle.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.orange)

            Text(message)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 8) {
                Button("Retry") {
                    controller.startGeneration()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)

                Button("Open Siri & Apple Intelligence Settings") {
                    if let url = URL(string: "x-apple.systempreferences:com.apple.Siri-Settings.extension") {
                        NSWorkspace.shared.open(url)
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Custom Instruction Bar

    private var customInstructionBar: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: "wand.and.stars")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)

                TextField(
                    "Instruction (e.g. \"make it punchier\", \"bullet points\", \"translate to Spanish\") — press Return to apply",
                    text: $controller.customInstruction
                )
                .textFieldStyle(.plain)
                .font(.system(size: 12))
                .focused($focusedField, equals: .customPrompt)
                .onSubmit {
                    applyCustomInstruction()
                }

                if !controller.customInstruction.isEmpty {
                    Button {
                        controller.customInstruction = ""
                        controller.appliedInstructionBadge = nil
                        controller.startGeneration()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Clear instruction")
                }

                Button("Apply") {
                    applyCustomInstruction()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.mini)
                .disabled(
                    controller.customInstruction.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                    controller.sourceText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                )
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 6)
            .background(Color.primary.opacity(0.055), in: RoundedRectangle(cornerRadius: 8))

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 5) {
                    ForEach(quickTweaks, id: \.label) { chip in
                        Button {
                            controller.customInstruction = chip.prompt
                            applyCustomInstruction()
                        } label: {
                            Text(chip.label)
                                .font(.system(size: 10.5, weight: .medium))
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Color.primary.opacity(0.05), in: Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
    }

    private func applyCustomInstruction() {
        focusedField = nil
        NSApp.keyWindow?.makeFirstResponder(nil)
        let trimmed = controller.customInstruction.trimmingCharacters(in: .whitespacesAndNewlines)
        controller.appliedInstructionBadge = trimmed.isEmpty ? nil : trimmed
        controller.startGeneration()
    }

    // MARK: - Footer

    private var footerBar: some View {
        HStack(spacing: 10) {
            Button {
                controller.cancelAndDismiss()
            } label: {
                keyHint(label: "Cancel", key: "esc")
            }
            .buttonStyle(.plain)

            Button {
                controller.startGeneration()
            } label: {
                keyHint(label: "Retry", key: "⌘R")
            }
            .buttonStyle(.plain)
            .disabled(controller.sourceText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

            Spacer()

            Button {
                controller.copyResultAndClose()
            } label: {
                keyHint(label: "Copy", key: "⌘C")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .disabled(controller.improvedText.isEmpty)

            Button {
                controller.acceptAndReplace()
            } label: {
                HStack(spacing: 5) {
                    Text(controller.sourcePID != nil ? "Replace" : "Copy & Close")
                        .font(.system(size: 12, weight: .semibold))
                    Text("↩")
                        .font(.system(size: 11, design: .monospaced))
                        .opacity(0.85)
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            .disabled(controller.state != .ready || controller.improvedText.isEmpty)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
    }

    private func keyHint(label: String, key: String) -> some View {
        HStack(spacing: 4) {
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            Text(key)
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 5)
                .padding(.vertical, 1.5)
                .background(Color.primary.opacity(0.07), in: RoundedRectangle(cornerRadius: 4))
        }
    }
}
