import AppKit

extension NSWindow {
    /// Center the window on the screen with the mouse pointer, which is where
    /// the user is looking when they pick a menu item or share from Finder
    func centerOnActiveScreen() {
        let mouse = NSEvent.mouseLocation
        guard let screen = NSScreen.screens.first(where: { NSMouseInRect(mouse, $0.frame, false) }) ?? NSScreen.main else {
            center()
            return
        }
        let visible = screen.visibleFrame
        setFrameOrigin(NSPoint(
            x: visible.midX - frame.width / 2,
            // Slightly above center, like the system's own panels
            y: visible.midY - frame.height / 2 + visible.height / 10
        ))
    }

    /// Keep a panel on screen when the app is deactivated. NSPanel hides on
    /// deactivation by default, and as a menu bar app NitroShare is deactivated
    /// as soon as Finder (or the app that opened a Share sheet) regains focus.
    func keepVisibleWhenInactive() {
        hidesOnDeactivate = false
        level = .floating
        collectionBehavior.insert([.moveToActiveSpace, .fullScreenAuxiliary])
    }
}

/// Open panel for choosing items to send, shown in front of other apps
@MainActor
enum ItemPicker {
    /// Shown as a sheet of `window` when given, otherwise as a floating panel
    static func choose(
        title: String,
        prompt: String,
        attachedTo window: NSWindow? = nil,
        completion: @escaping @MainActor ([URL]) -> Void
    ) {
        let panel = NSOpenPanel()
        panel.title = title
        panel.message = title
        panel.prompt = prompt
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = true
        panel.canCreateDirectories = false

        let handler: (NSApplication.ModalResponse) -> Void = { response in
            let urls = panel.urls
            guard response == .OK, !urls.isEmpty else { return }
            MainActor.assumeIsolated {
                completion(urls)
            }
        }

        NSApp.activate()
        if let window {
            panel.beginSheetModal(for: window, completionHandler: handler)
            return
        }
        panel.keepVisibleWhenInactive()
        panel.centerOnActiveScreen()
        panel.begin(completionHandler: handler)
        panel.orderFrontRegardless()
    }
}
