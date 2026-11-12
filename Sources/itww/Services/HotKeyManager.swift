import Carbon.HIToolbox
import Foundation

@MainActor
public final class HotKeyManager {
    public static let shared = HotKeyManager()

    private static let hotKeySignature: OSType = 0x4954_5757 // 'ITWW'
    private static let hotKeyID: UInt32 = 1

    private var eventHandlerRef: EventHandlerRef?
    private var hotKeyRef: EventHotKeyRef?
    private var currentShortcut: HotKeyShortcut?
    public var onTrigger: (@MainActor () -> Void)?
    public private(set) var isPaused: Bool = false

    private init() {
        installHandlerIfNeeded()
    }

    public func register(shortcut: HotKeyShortcut) {
        currentShortcut = shortcut
        guard !isPaused else { return }
        applyRegistration(shortcut)
    }

    public func pause() {
        isPaused = true
        unregisterActiveHotKey()
    }

    public func resume() {
        isPaused = false
        if let currentShortcut {
            applyRegistration(currentShortcut)
        }
    }

    private func applyRegistration(_ shortcut: HotKeyShortcut) {
        installHandlerIfNeeded()
        unregisterActiveHotKey()

        let gID = EventHotKeyID(signature: Self.hotKeySignature, id: Self.hotKeyID)
        var newRef: EventHotKeyRef?
        let status = RegisterEventHotKey(
            shortcut.keyCode,
            shortcut.carbonModifiers,
            gID,
            GetApplicationEventTarget(),
            0,
            &newRef
        )
        if status == noErr {
            hotKeyRef = newRef
        }
    }

    private func unregisterActiveHotKey() {
        if let existing = hotKeyRef {
            UnregisterEventHotKey(existing)
            hotKeyRef = nil
        }
    }

    private func installHandlerIfNeeded() {
        guard eventHandlerRef == nil else { return }

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        let callback: EventHandlerUPP = { _, eventRef, _ in
            guard let eventRef else { return OSStatus(eventNotHandledErr) }
            var incomingID = EventHotKeyID()
            let err = GetEventParameter(
                eventRef,
                EventParamName(kEventParamDirectObject),
                EventParamType(typeEventHotKeyID),
                nil,
                MemoryLayout<EventHotKeyID>.size,
                nil,
                &incomingID
            )
            guard err == noErr,
                  incomingID.signature == HotKeyManager.hotKeySignature,
                  incomingID.id == HotKeyManager.hotKeyID else {
                return OSStatus(eventNotHandledErr)
            }

            Task { @MainActor in
                HotKeyManager.shared.onTrigger?()
            }
            return noErr
        }

        var handler: EventHandlerRef?
        InstallEventHandler(
            GetApplicationEventTarget(),
            callback,
            1,
            &eventType,
            nil,
            &handler
        )
        eventHandlerRef = handler
    }
}
