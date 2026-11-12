import AppKit
import Carbon.HIToolbox
import SwiftUI

public struct WindowDragHandle: NSViewRepresentable {
    public init() {}

    public func makeNSView(context: Context) -> DraggableHandleNSView {
        DraggableHandleNSView()
    }

    public func updateNSView(_ nsView: DraggableHandleNSView, context: Context) {}
}

public final class DraggableHandleNSView: NSView {
    override public var mouseDownCanMoveWindow: Bool { true }

    override public func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    override public func resetCursorRects() {
        addCursorRect(bounds, cursor: .openHand)
    }

    override public func mouseDown(with event: NSEvent) {
        NSCursor.closedHand.push()
        window?.performDrag(with: event)
        NSCursor.pop()
    }
}

@MainActor
public final class HUDPanel: NSPanel {
    public var onKeyAction: ((HUDKeyCommand) -> Bool)?
    private var keyMonitor: Any?

    public enum HUDKeyCommand {
        case acceptReplace
        case cancel
        case copyResult
        case regenerate
        case toggleDiff
        case selectMode(RewriteMode)
    }

    public init<Content: View>(rootView: Content) {
        let initialRect = NSRect(x: 0, y: 0, width: 580, height: 360)
        super.init(
            contentRect: initialRect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        self.isMovable = true
        self.isMovableByWindowBackground = true
        self.isFloatingPanel = true
        self.becomesKeyOnlyIfNeeded = false
        self.level = .floating
        self.backgroundColor = .clear
        self.isOpaque = false
        self.hasShadow = true
        self.hidesOnDeactivate = false
        self.animationBehavior = .utilityWindow
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]

        let hostingView = HUDHostingView(rootView: rootView)
        hostingView.sizingOptions = [.intrinsicContentSize]
        self.contentView = hostingView

        installKeyMonitor()
    }

    override public var canBecomeKey: Bool { true }
    override public var canBecomeMain: Bool { false }

    public func present(near anchorPoint: NSPoint) {
        let targetScreen = NSScreen.screens.first(where: { NSMouseInRect(anchorPoint, $0.frame, false) })
            ?? NSScreen.main
            ?? NSScreen.screens.first

        let panelSize = NSSize(
            width: 580,
            height: max(320, min(contentView?.fittingSize.height ?? 360, 540))
        )

        var origin = NSPoint(
            x: anchorPoint.x - panelSize.width / 2,
            y: anchorPoint.y - panelSize.height - 24
        )

        if let visible = targetScreen?.visibleFrame {
            let margin: CGFloat = 16
            if origin.y < visible.minY + margin {
                let aboveY = anchorPoint.y + 28
                if aboveY + panelSize.height <= visible.maxY - margin {
                    origin.y = aboveY
                } else {
                    origin.y = visible.midY - panelSize.height / 2
                }
            }
            origin.x = min(max(origin.x, visible.minX + margin), visible.maxX - panelSize.width - margin)
            origin.y = min(max(origin.y, visible.minY + margin), visible.maxY - panelSize.height - margin)
        }

        setFrame(NSRect(origin: origin, size: panelSize), display: true)
        NSApp.activate(ignoringOtherApps: true)
        makeKeyAndOrderFront(nil)
    }

    private func installKeyMonitor() {
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, self.isVisible, self.isKeyWindow else { return event }
            if self.handleKeyDown(event) {
                return nil
            }
            return event
        }
    }

    private func handleKeyDown(_ event: NSEvent) -> Bool {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let keyCode = Int(event.keyCode)
        let isEditingTextView = (firstResponder is NSTextView)

        if keyCode == kVK_Escape {
            return onKeyAction?(.cancel) ?? false
        }

        // Cmd + Return always accepts & replaces, even when a text field has focus.
        if (keyCode == kVK_Return || keyCode == kVK_ANSI_KeypadEnter), flags == .command {
            return onKeyAction?(.acceptReplace) ?? false
        }

        // Plain Return accepts & replaces ONLY when no text field / editor is focused.
        // When the custom instruction field is focused, let NSTextField receive Return so .onSubmit runs!
        if (keyCode == kVK_Return || keyCode == kVK_ANSI_KeypadEnter), flags.isEmpty, !isEditingTextView {
            return onKeyAction?(.acceptReplace) ?? false
        }

        if flags == .command {
            switch keyCode {
            case kVK_ANSI_D:
                return onKeyAction?(.toggleDiff) ?? false
            case kVK_ANSI_R:
                return onKeyAction?(.regenerate) ?? false
            case kVK_ANSI_C:
                if !hasTextViewSelection() {
                    return onKeyAction?(.copyResult) ?? false
                }
            case kVK_ANSI_1:
                return onKeyAction?(.selectMode(.improve)) ?? false
            case kVK_ANSI_2:
                return onKeyAction?(.selectMode(.grammar)) ?? false
            case kVK_ANSI_3:
                return onKeyAction?(.selectMode(.concise)) ?? false
            case kVK_ANSI_4:
                return onKeyAction?(.selectMode(.clear)) ?? false
            case kVK_ANSI_5:
                return onKeyAction?(.selectMode(.professional)) ?? false
            default:
                break
            }
        }

        return false
    }

    private func hasTextViewSelection() -> Bool {
        guard let textView = firstResponder as? NSTextView else { return false }
        return textView.selectedRange().length > 0
    }
}

public final class HUDHostingView<Content: View>: NSHostingView<Content> {
    override public var mouseDownCanMoveWindow: Bool { true }
}
