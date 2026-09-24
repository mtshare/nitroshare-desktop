import SwiftUI

@main
struct NitroShareApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var model = AppModel.shared

    var body: some Scene {
        MenuBarExtra {
            MenuPanel()
                .environment(model)
        } label: {
            Image(systemName: model.activeTransfers.isEmpty
                  ? "arrow.up.arrow.down.circle"
                  : "arrow.up.arrow.down.circle.fill")
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
                .environment(model)
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        MainActor.assumeIsolated {
            AppModel.shared.start()
        }
    }

    /// Files from "Open With", the Dock icon, or nitroshare://share URLs sent
    /// by the Share extension
    func application(_ application: NSApplication, open urls: [URL]) {
        var files: [URL] = []
        for url in urls {
            if url.isFileURL {
                files.append(url)
            } else if url.scheme == "nitroshare", url.host() == "share" {
                let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
                files += items
                    .filter { $0.name == "path" }
                    .compactMap(\.value)
                    .map { URL(filePath: $0) }
            }
        }
        MainActor.assumeIsolated {
            SharePanel.shared.present(files)
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        MainActor.assumeIsolated {
            AppModel.shared.stop()
        }
    }
}
