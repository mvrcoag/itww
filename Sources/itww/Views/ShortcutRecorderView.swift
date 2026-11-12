import AppKit
import Carbon.HIToolbox
import SwiftUI

public struct ShortcutRecorderView: View {
    public let currentShortcut: HotKeyShortcut
    public let onShortcutChange: (HotKeyShortcut) -> Void

    @State private var isRecording = false
    @State private var eventMonitor: Any?

    public init(
        currentShortcut: HotKeyShortcut,
        onShortcutChange: @escaping (HotKeyShortcut) -> Void
    ) {
        self.currentShortcut = currentShortcut
        self.onShortcutChange = onShortcutChange
    }

    public var body: some View {
        HStack(spacing: 8) {
            Button {
                if isRecording {
                    stopRecording()
                } else {
                    startRecording()
                }
            } label: {
                HStack(spacing: 6) {
                    if isRecording {
                        Circle()
                            .fill(.red)
                            .frame(width: 7, height: 7)
                        Text("Press new shortcut…")
                            .font(.system(size: 12, weight: .medium))
                    } else {
                        Text(currentShortcut.displayString)
                            .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .frame(minWidth: 130)
                .background(
                    isRecording ? Color.accentColor.opacity(0.16) : Color.primary.opacity(0.07),
                    in: RoundedRectangle(cornerRadius: 7)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 7)
                        .strokeBorder(isRecording ? Color.accentColor : Color.primary.opacity(0.15), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)

            if currentShortcut != .default {
                Button("Reset") {
                    stopRecording()
                    onShortcutChange(.default)
                }
                .controlSize(.small)
            }
        }
        .onDisappear {
            stopRecording()
        }
    }

    private func startRecording() {
        isRecording = true
        HotKeyManager.shared.pause()

        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if Int(event.keyCode) == kVK_Escape {
                stopRecording()
                return nil
            }
            if let captured = HotKeyShortcut(event: event) {
                onShortcutChange(captured)
                stopRecording()
                return nil
            }
            NSSound.beep()
            return nil
        }
    }

    private func stopRecording() {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
        if isRecording {
            isRecording = false
            HotKeyManager.shared.resume()
        }
    }
}
