import AppKit
import SwiftUI

@MainActor
final class PromptMeterSettingsWindow: NSObject, NSWindowDelegate {
    static let shared = PromptMeterSettingsWindow()

    private var window: NSWindow?
    private let state = PromptMeterSettingsState()

    private override init() {}

    func show(model: PromptMeterModel, selectedTab: SettingsTab = .general) {
        state.selectedTab = selectedTab

        if window == nil {
            window = makeWindow(model: model)
        }

        NSApp.activate(ignoringOtherApps: true)
        centerWindowOnMainScreen()
        window?.makeKeyAndOrderFront(nil)
    }

    private func makeWindow(model: PromptMeterModel) -> NSWindow {
        let window = NSWindow(
            contentRect: NSRect(
                x: 0,
                y: 0,
                width: SettingsLayout.windowWidth,
                height: SettingsLayout.windowHeight
            ),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "PromptMeter"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isReleasedWhenClosed = false
        window.contentViewController = NSHostingController(rootView: PromptMeterSettingsView(model: model, state: state))
        window.delegate = self
        return window
    }

    func windowWillClose(_ notification: Notification) {
        guard let closingWindow = notification.object as? NSWindow,
              closingWindow === window else {
            return
        }

        closingWindow.contentViewController = nil
        closingWindow.delegate = nil
        window = nil
    }

    private func centerWindowOnMainScreen() {
        guard let window else { return }

        let screenFrame = NSScreen.main?.visibleFrame ?? NSScreen.screens.first?.visibleFrame
        guard let screenFrame else {
            window.center()
            return
        }

        let origin = NSPoint(
            x: screenFrame.midX - window.frame.width / 2,
            y: screenFrame.midY - window.frame.height / 2
        )
        window.setFrameOrigin(origin)
    }
}
