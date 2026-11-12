import AppKit
import Foundation
import Observation
import SwiftUI

@MainActor
@Observable
public final class AppController {
    public enum SessionState: Equatable {
        case idle
        case needsAccessibility
        case emptySelection
        case streaming
        case ready
        case failed(String)
    }

    public static let shared = AppController()

    public var settings: AppSettings

    public var state: SessionState = .idle
    public var sourceText: String = ""
    public var improvedText: String = ""
    public var selectedMode: RewriteMode
    public var customInstruction: String = ""
    public var appliedInstructionBadge: String?
    public var sourceAppName: String?
    public var sourcePID: pid_t?
    public var backendUsedLabel: String?
    public var statusBanner: String?
    public var isAccessibilityTrusted: Bool = false
    public var modelReadiness: ModelReadiness = .ready(detail: "")

    private var hudPanel: HUDPanel?
    private var settingsWindow: NSWindow?
    private var welcomeWindow: NSWindow?
    private var generationTask: Task<Void, Never>?
    private var permissionPollTask: Task<Void, Never>?

    public init(settings: AppSettings = AppSettings()) {
        self.settings = settings
        self.selectedMode = settings.defaultMode
    }

    public func start() {
        refreshSystemStatus()
        configureHotKey()
        TextImproverService.shared.prewarmIfPossible(extraRules: settings.customStyleRules)

        // Show welcome & permissions onboarding up-front on first launch or whenever Accessibility is missing.
        if !settings.hasCompletedOnboarding || !isAccessibilityTrusted {
            openWelcomeWindow(promptSystemAccessibilityDialog: !settings.hasCompletedOnboarding && !isAccessibilityTrusted)
        }
    }

    public func refreshSystemStatus() {
        isAccessibilityTrusted = TextSelectionService.shared.isAccessibilityTrusted
        modelReadiness = TextImproverService.shared.checkReadiness(preferredBackend: settings.modelBackend)
    }

    public func configureHotKey() {
        HotKeyManager.shared.onTrigger = { [weak self] in
            guard let self else { return }
            Task { @MainActor in
                await self.handleHotKeyTriggered()
            }
        }
        HotKeyManager.shared.register(shortcut: settings.shortcut)
    }

    public func updateShortcut(_ newShortcut: HotKeyShortcut) {
        settings.shortcut = newShortcut
        HotKeyManager.shared.register(shortcut: newShortcut)
    }

    // MARK: - Trigger Flows

    public func handleHotKeyTriggered() async {
        if let panel = hudPanel, panel.isVisible {
            cancelAndDismiss()
            return
        }

        refreshSystemStatus()
        selectedMode = settings.defaultMode
        customInstruction = ""
        appliedInstructionBadge = nil
        statusBanner = nil
        backendUsedLabel = nil

        let mousePoint = NSEvent.mouseLocation

        guard isAccessibilityTrusted else {
            let frontApp = NSWorkspace.shared.frontmostApplication
            let ownPID = ProcessInfo.processInfo.processIdentifier
            if frontApp?.processIdentifier != ownPID {
                sourcePID = frontApp?.processIdentifier
                sourceAppName = frontApp?.localizedName
            }
            sourceText = ""
            improvedText = ""
            state = .needsAccessibility
            showHUD(near: mousePoint)
            startAccessibilityPolling()
            return
        }

        if let captured = await TextSelectionService.shared.captureSelection() {
            sourceText = captured.text
            sourceAppName = captured.sourceAppName
            sourcePID = captured.sourcePID
            improvedText = ""
            showHUD(near: captured.anchorPoint)
            startGeneration()
        } else {
            let frontApp = NSWorkspace.shared.frontmostApplication
            let ownPID = ProcessInfo.processInfo.processIdentifier
            sourcePID = (frontApp?.processIdentifier == ownPID) ? nil : frontApp?.processIdentifier
            sourceAppName = (frontApp?.processIdentifier == ownPID) ? nil : frontApp?.localizedName
            sourceText = ""
            improvedText = ""
            state = .emptySelection
            showHUD(near: mousePoint)
        }
    }

    public func improveClipboardNow() {
        refreshSystemStatus()
        let frontApp = NSWorkspace.shared.frontmostApplication
        let ownPID = ProcessInfo.processInfo.processIdentifier
        sourcePID = (frontApp?.processIdentifier == ownPID) ? nil : frontApp?.processIdentifier
        sourceAppName = (frontApp?.processIdentifier == ownPID) ? nil : frontApp?.localizedName
        selectedMode = settings.defaultMode
        customInstruction = ""
        appliedInstructionBadge = nil
        statusBanner = nil

        let clip = NSPasteboard.general.string(forType: .string) ?? ""
        if clip.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            sourceText = ""
            improvedText = ""
            state = .emptySelection
            showHUD(near: NSEvent.mouseLocation)
        } else {
            sourceText = clip
            improvedText = ""
            showHUD(near: NSEvent.mouseLocation)
            startGeneration()
        }
    }

    public func loadClipboardIntoManualInput() {
        let clip = NSPasteboard.general.string(forType: .string) ?? ""
        guard !clip.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        sourceText = clip
        startGeneration()
    }

    // MARK: - Generation

    public func startGeneration() {
        let trimmed = sourceText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            state = .emptySelection
            return
        }

        generationTask?.cancel()
        improvedText = ""
        backendUsedLabel = nil
        state = .streaming

        let currentSource = sourceText
        let currentMode = selectedMode
        let currentCustom = customInstruction.trimmingCharacters(in: .whitespacesAndNewlines)
        appliedInstructionBadge = currentCustom.isEmpty ? nil : currentCustom
        let preferredBackend = settings.modelBackend
        let extraRules = settings.customStyleRules
        let temp = settings.temperature

        generationTask = Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                let output = try await TextImproverService.shared.streamImprovement(
                    sourceText: currentSource,
                    mode: currentMode,
                    customInstruction: currentCustom,
                    preferredBackend: preferredBackend,
                    extraRules: extraRules,
                    temperature: temp,
                    onPartial: { [weak self] partial in
                        self?.improvedText = partial
                    }
                )
                guard !Task.isCancelled else { return }
                self.improvedText = output.text
                self.backendUsedLabel = output.backendUsed
                self.state = .ready
            } catch is CancellationError {
                return
            } catch {
                guard !Task.isCancelled else { return }
                self.state = .failed(error.localizedDescription)
            }
        }
    }

    public func selectMode(_ mode: RewriteMode) {
        selectedMode = mode
        if !sourceText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            startGeneration()
        }
    }

    // MARK: - Actions

    public func acceptAndReplace() {
        guard state == .ready, !improvedText.isEmpty else { return }
        let finalOutput = improvedText
        let pid = sourcePID

        generationTask?.cancel()
        permissionPollTask?.cancel()
        hudPanel?.orderOut(nil)

        Task { @MainActor in
            if pid != nil, TextSelectionService.shared.isAccessibilityTrusted {
                _ = await TextSelectionService.shared.replaceSelection(with: finalOutput, targetPID: pid)
            } else {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(finalOutput, forType: .string)
            }
            self.state = .idle
        }
    }

    public func copyResultAndClose() {
        let textToCopy = improvedText.isEmpty ? sourceText : improvedText
        guard !textToCopy.isEmpty else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(textToCopy, forType: .string)
        cancelAndDismiss()
    }

    public func cancelAndDismiss() {
        generationTask?.cancel()
        permissionPollTask?.cancel()
        hudPanel?.orderOut(nil)
        state = .idle

        if let pid = sourcePID,
           let app = NSRunningApplication(processIdentifier: pid) {
            app.activate()
        }
    }

    public func promptAccessibility() {
        TextSelectionService.shared.requestAccessibilityPermission()
        TextSelectionService.shared.openAccessibilitySettings()
        startAccessibilityPolling()
    }

    public func startOnboardingPermissionPolling() {
        startAccessibilityPolling()
    }

    public func completeOnboarding() {
        settings.hasCompletedOnboarding = true
        permissionPollTask?.cancel()
        welcomeWindow?.orderOut(nil)
    }

    private func startAccessibilityPolling() {
        permissionPollTask?.cancel()
        permissionPollTask = Task { @MainActor [weak self] in
            for _ in 0..<120 {
                try? await Task.sleep(for: .seconds(1))
                guard let self, !Task.isCancelled else { return }
                let trusted = TextSelectionService.shared.isAccessibilityTrusted
                self.isAccessibilityTrusted = trusted
                self.modelReadiness = TextImproverService.shared.checkReadiness(
                    preferredBackend: self.settings.modelBackend
                )
                if trusted, self.state == .needsAccessibility {
                    self.state = .emptySelection
                    break
                }
            }
        }
    }

    // MARK: - Windows

    private func showHUD(near point: NSPoint) {
        if hudPanel == nil {
            let panel = HUDPanel(rootView: HUDView(controller: self))
            panel.onKeyAction = { [weak self] command in
                guard let self else { return false }
                switch command {
                case .acceptReplace:
                    if self.state == .ready {
                        self.acceptAndReplace()
                        return true
                    }
                    return false
                case .cancel:
                    self.cancelAndDismiss()
                    return true
                case .copyResult:
                    if !self.improvedText.isEmpty {
                        self.copyResultAndClose()
                        return true
                    }
                    return false
                case .regenerate:
                    if !self.sourceText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        self.startGeneration()
                        return true
                    }
                    return false
                case .toggleDiff:
                    self.settings.showDiff.toggle()
                    return true
                case .selectMode(let mode):
                    self.selectMode(mode)
                    return true
                }
            }
            hudPanel = panel
        }
        hudPanel?.present(near: point)
    }

    public func openWelcomeWindow(promptSystemAccessibilityDialog: Bool = false) {
        refreshSystemStatus()

        if let existing = welcomeWindow {
            NSApp.activate(ignoringOtherApps: true)
            existing.makeKeyAndOrderFront(nil)
            if promptSystemAccessibilityDialog {
                TextSelectionService.shared.requestAccessibilityPermission()
            }
            return
        }

        let window = WelcomeWindow(
            contentRect: NSRect(x: 0, y: 0, width: 600, height: 550),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "Welcome to itww"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = true
        window.isReleasedWhenClosed = false
        window.backgroundColor = NSColor(red: 0.024, green: 0.024, blue: 0.028, alpha: 1.0)
        window.standardWindowButton(.closeButton)?.isHidden = true
        window.standardWindowButton(.miniaturizeButton)?.isHidden = true
        window.standardWindowButton(.zoomButton)?.isHidden = true
        window.contentView = NSHostingView(rootView: WelcomeView(controller: self))
        window.center()
        welcomeWindow = window

        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)

        if promptSystemAccessibilityDialog {
            TextSelectionService.shared.requestAccessibilityPermission()
        }
    }

    public func openSettingsWindow() {
        refreshSystemStatus()
        if let existing = settingsWindow {
            NSApp.activate(ignoringOtherApps: true)
            existing.makeKeyAndOrderFront(nil)
            return
        }

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 490),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "itww Settings"
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(rootView: SettingsView(controller: self))
        window.center()
        settingsWindow = window

        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }
}

public final class WelcomeWindow: NSWindow {
    override public var canBecomeKey: Bool { true }
    override public var canBecomeMain: Bool { true }
}
