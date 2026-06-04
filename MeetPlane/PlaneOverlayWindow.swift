import AppKit
import SwiftUI

/// A transparent, borderless, non-interactive full-screen overlay window.
///
/// Properties:
/// - Floats above all other windows (`.floating` level).
/// - `ignoresMouseEvents = true` — clicks and keyboard events pass straight through.
/// - `collectionBehavior` includes `.canJoinAllSpaces` so it appears on every Space/desktop.
/// - `isReleasedWhenClosed = false` — the shared instance is reused across multiple animations.
final class PlaneOverlayWindow: NSWindow {

    /// Shared singleton — always access the window via this property.
    static let shared = PlaneOverlayWindow()

    private init() {
        let screen = NSScreen.main ?? NSScreen.screens[0]
        super.init(
            contentRect: screen.frame,
            styleMask:   [.borderless],
            backing:     .buffered,
            defer:       false
        )
        configure()
    }

    private func configure() {
        backgroundColor            = .clear
        isOpaque                   = false
        level                      = .floating
        ignoresMouseEvents         = true
        collectionBehavior         = [.canJoinAllSpaces, .fullScreenAuxiliary]
        isReleasedWhenClosed       = false
        hasShadow                  = false
        titlebarAppearsTransparent = true
    }

    // MARK: - Public API

    /// Show the plane animation for a real meeting event.
    func show(for event: MeetingEvent) {
        guard let screen = NSScreen.main ?? NSScreen.screens.first else { return }
        setFrame(screen.frame, display: true)

        contentView = NSHostingView(
            rootView: PlaneBannerView(event: event) { [weak self] in
                self?.orderOut(nil)
            }
        )
        makeKeyAndOrderFront(nil)
    }

    /// Show a test animation with placeholder data. No Google auth required.
    func showTestAnimation() {
        show(for: MeetingEvent(
            id:        "test-\(UUID().uuidString)",
            title:     "Test Meeting",
            startTime: Date().addingTimeInterval(5 * 60),
            endTime:   Date().addingTimeInterval(65 * 60),
            meetLink:  nil
        ))
    }
}
