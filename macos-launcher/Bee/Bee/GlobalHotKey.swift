//
//  GlobalHotKey.swift
//  Bee
//
//  Registers global keyboard shortcuts using the Carbon Hot Key API.
//  These shortcuts work even when the app is not in focus.
//

import AppKit
import Carbon

/// Manages global keyboard shortcuts that work system-wide.
///
/// Uses the Carbon Hot Key API which is the standard way to register
/// global shortcuts on macOS. SwiftUI's `.keyboardShortcut()` only
/// works when the app is in focus.
final class GlobalHotKey {
    /// Shared instance for app-wide access.
    static let shared = GlobalHotKey()

    private var hotKeyRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?
    private var callback: (() -> Void)?

    private init() {}

    /// Register Cmd+Shift+B as a global hotkey to show the app.
    ///
    /// - Parameter callback: Action to perform when the hotkey is pressed
    func registerShowAppHotKey(callback: @escaping () -> Void) {
        self.callback = callback

        // Key code for 'B' is 11
        // Modifiers: cmdKey (256) + shiftKey (512) = 768
        let keyCode: UInt32 = 11 // 'B'
        let modifiers = UInt32(cmdKey | shiftKey)

        var hotKeyID = EventHotKeyID()
        hotKeyID.signature = OSType(0x4245_4545) // "BEES" in hex
        hotKeyID.id = 1

        // Register the hotkey
        let status = RegisterEventHotKey(
            keyCode,
            modifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )

        guard status == noErr else {
            print("Failed to register global hotkey: \(status)")
            return
        }

        // Install event handler
        var eventSpec = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        InstallEventHandler(
            GetApplicationEventTarget(),
            { _, event, userData -> OSStatus in
                guard let userData else { return OSStatus(eventNotHandledErr) }
                let hotKey = Unmanaged<GlobalHotKey>.fromOpaque(userData).takeUnretainedValue()
                hotKey.handleHotKeyEvent(event)
                return noErr
            },
            1,
            &eventSpec,
            Unmanaged.passUnretained(self).toOpaque(),
            &eventHandler
        )
    }

    private func handleHotKeyEvent(_ event: EventRef?) {
        guard event != nil else { return }

        var hotKeyID = EventHotKeyID()
        let status = GetEventParameter(
            event,
            UInt32(kEventParamDirectObject),
            UInt32(typeEventHotKeyID),
            nil,
            MemoryLayout<EventHotKeyID>.size,
            nil,
            &hotKeyID
        )

        guard status == noErr, hotKeyID.id == 1 else { return }

        // Execute callback on main thread
        DispatchQueue.main.async { [weak self] in
            self?.callback?()
        }
    }

    /// Unregister the global hotkey.
    func unregister() {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }
        if let eventHandler {
            RemoveEventHandler(eventHandler)
            self.eventHandler = nil
        }
        callback = nil
    }

    deinit {
        unregister()
    }
}
