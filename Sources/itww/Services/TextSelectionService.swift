import AppKit
import ApplicationServices
import Carbon.HIToolbox
import Foundation

public struct CapturedSelection: Sendable {
    public let text: String
    public let sourceBundleIdentifier: String?
    public let sourceAppName: String?
    public let sourcePID: pid_t?
    public let anchorPoint: NSPoint

    public init(
        text: String,
        sourceBundleIdentifier: String?,
        sourceAppName: String?,
        sourcePID: pid_t?,
        anchorPoint: NSPoint
    ) {
        self.text = text
        self.sourceBundleIdentifier = sourceBundleIdentifier
        self.sourceAppName = sourceAppName
        self.sourcePID = sourcePID
        self.anchorPoint = anchorPoint
    }
}

@MainActor
public final class TextSelectionService {
    public static let shared = TextSelectionService()

    private init() {}

    public var isAccessibilityTrusted: Bool {
        AXIsProcessTrusted()
    }

    public func requestAccessibilityPermission() {
        let promptKey = "AXTrustedCheckOptionPrompt" as CFString
        let options = [promptKey: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }

    public func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    public func captureSelection() async -> CapturedSelection? {
        let frontApp = NSWorkspace.shared.frontmostApplication
        let ownPID = ProcessInfo.processInfo.processIdentifier
        let targetApp = (frontApp?.processIdentifier == ownPID) ? nil : frontApp

        let fallbackPoint = NSEvent.mouseLocation

        guard isAccessibilityTrusted else {
            return nil
        }

        // 1. Fast path: read directly from Accessibility focused element.
        if let axResult = readSelectedTextViaAccessibility() {
            let trimmed = axResult.text.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                return CapturedSelection(
                    text: axResult.text,
                    sourceBundleIdentifier: targetApp?.bundleIdentifier,
                    sourceAppName: targetApp?.localizedName,
                    sourcePID: targetApp?.processIdentifier,
                    anchorPoint: axResult.anchorPoint ?? fallbackPoint
                )
            }
        }

        // 2. Universal fallback (Electron, browsers, custom editors): simulate Cmd+C and restore pasteboard.
        if let copiedText = await copySelectionViaSimulatedShortcut(),
           !copiedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return CapturedSelection(
                text: copiedText,
                sourceBundleIdentifier: targetApp?.bundleIdentifier,
                sourceAppName: targetApp?.localizedName,
                sourcePID: targetApp?.processIdentifier,
                anchorPoint: fallbackPoint
            )
        }

        return nil
    }

    public func replaceSelection(with newText: String, targetPID: pid_t?) async -> Bool {
        guard isAccessibilityTrusted else { return false }

        if let pid = targetPID,
           let runningApp = NSRunningApplication(processIdentifier: pid) {
            runningApp.activate()
            // Wait up to 250ms for the target app to regain key focus.
            for _ in 0..<16 {
                if NSWorkspace.shared.frontmostApplication?.processIdentifier == pid {
                    break
                }
                try? await Task.sleep(for: .milliseconds(15))
            }
            try? await Task.sleep(for: .milliseconds(40))
        }

        let pasteboard = NSPasteboard.general
        let snapshot = snapshotPasteboard(pasteboard)

        pasteboard.clearContents()
        pasteboard.setString(newText, forType: .string)

        postKeyCombo(virtualKey: CGKeyCode(kVK_ANSI_V), flags: .maskCommand)

        // Allow target app time to consume the pasted string before restoring clipboard.
        try? await Task.sleep(for: .milliseconds(260))
        restorePasteboard(snapshot, to: pasteboard)
        return true
    }

    // MARK: - Accessibility Reader

    private func readSelectedTextViaAccessibility() -> (text: String, anchorPoint: NSPoint?)? {
        let systemWide = AXUIElementCreateSystemWide()
        var focusedRef: CFTypeRef?
        let focusErr = AXUIElementCopyAttributeValue(
            systemWide,
            kAXFocusedUIElementAttribute as CFString,
            &focusedRef
        )
        guard focusErr == .success, let focusedRef else {
            return nil
        }
        // Safe cast: AXUIElementCopyAttributeValue returns an AXUIElement for kAXFocusedUIElementAttribute.
        guard CFGetTypeID(focusedRef) == AXUIElementGetTypeID() else {
            return nil
        }
        let element = unsafeDowncast(focusedRef, to: AXUIElement.self)

        var selectedTextRef: CFTypeRef?
        let textErr = AXUIElementCopyAttributeValue(
            element,
            kAXSelectedTextAttribute as CFString,
            &selectedTextRef
        )
        guard textErr == .success, let selectedText = selectedTextRef as? String, !selectedText.isEmpty else {
            return nil
        }

        let anchor = readSelectionAnchorPoint(from: element)
        return (selectedText, anchor)
    }

    private func readSelectionAnchorPoint(from element: AXUIElement) -> NSPoint? {
        var rangeRef: CFTypeRef?
        let rangeErr = AXUIElementCopyAttributeValue(
            element,
            kAXSelectedTextRangeAttribute as CFString,
            &rangeRef
        )
        guard rangeErr == .success, let rangeRef else { return nil }

        var boundsRef: CFTypeRef?
        let boundsErr = AXUIElementCopyParameterizedAttributeValue(
            element,
            kAXBoundsForRangeParameterizedAttribute as CFString,
            rangeRef,
            &boundsRef
        )
        guard boundsErr == .success,
              let boundsRef,
              CFGetTypeID(boundsRef) == AXValueGetTypeID() else {
            return nil
        }

        let axValue = unsafeDowncast(boundsRef, to: AXValue.self)
        var quartzRect = CGRect.zero
        guard AXValueGetValue(axValue, .cgRect, &quartzRect),
              quartzRect.width >= 0,
              quartzRect.origin != .zero else {
            return nil
        }

        // Convert Quartz global coordinates (origin top-left of primary screen) to AppKit screen coordinates.
        let primaryHeight = NSScreen.screens.first?.frame.height ?? 900
        let appKitY = primaryHeight - (quartzRect.origin.y + quartzRect.height)
        return NSPoint(x: quartzRect.midX, y: appKitY)
    }

    // MARK: - Synthetic Copy / Paste Helpers

    private func copySelectionViaSimulatedShortcut() async -> String? {
        let pasteboard = NSPasteboard.general
        let snapshot = snapshotPasteboard(pasteboard)

        pasteboard.clearContents()
        let initialChangeCount = pasteboard.changeCount

        postKeyCombo(virtualKey: CGKeyCode(kVK_ANSI_C), flags: .maskCommand)

        var copied: String?
        for _ in 0..<12 {
            try? await Task.sleep(for: .milliseconds(15))
            if pasteboard.changeCount != initialChangeCount {
                copied = pasteboard.string(forType: .string)
                break
            }
        }

        restorePasteboard(snapshot, to: pasteboard)
        return copied
    }

    private func postKeyCombo(virtualKey: CGKeyCode, flags: CGEventFlags) {
        guard let source = CGEventSource(stateID: .hidSystemState),
              let keyDown = CGEvent(keyboardEventSource: source, virtualKey: virtualKey, keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: source, virtualKey: virtualKey, keyDown: false) else {
            return
        }
        keyDown.flags = flags
        keyUp.flags = flags
        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)
    }

    private struct PasteboardItemSnapshot {
        let dataByType: [(NSPasteboard.PasteboardType, Data)]
    }

    private func snapshotPasteboard(_ pasteboard: NSPasteboard) -> [PasteboardItemSnapshot] {
        guard let items = pasteboard.pasteboardItems else { return [] }
        return items.map { item in
            let pairs = item.types.compactMap { type -> (NSPasteboard.PasteboardType, Data)? in
                guard let data = item.data(forType: type) else { return nil }
                return (type, data)
            }
            return PasteboardItemSnapshot(dataByType: pairs)
        }
    }

    private func restorePasteboard(_ snapshot: [PasteboardItemSnapshot], to pasteboard: NSPasteboard) {
        pasteboard.clearContents()
        guard !snapshot.isEmpty else { return }
        let restoredItems: [NSPasteboardItem] = snapshot.map { snap in
            let item = NSPasteboardItem()
            for (type, data) in snap.dataByType {
                item.setData(data, forType: type)
            }
            return item
        }
        pasteboard.writeObjects(restoredItems)
    }
}
