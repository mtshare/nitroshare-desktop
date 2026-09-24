import Foundation

/// Runs the headless NitroShare core (`nitroshare-cli`) bundled next to this
/// executable and restarts it if it exits unexpectedly.
@MainActor
final class CoreProcess {
    private var process: Process?
    private var isStopping = false

    static let logURL = FileManager.default.homeDirectoryForCurrentUser
        .appending(path: "Library/Logs/NitroShare/core.log")

    func start() {
        isStopping = false
        guard process == nil,
              let executable = Bundle.main.executableURL?
                .deletingLastPathComponent()
                .appending(path: "nitroshare-cli") else {
            return
        }

        let process = Process()
        process.executableURL = executable
        // Launch at login is handled natively with SMAppService
        process.arguments = ["--plugin-blacklist", "autostart"]
        process.standardInput = FileHandle.nullDevice
        let log = Self.openLog()
        process.standardOutput = log
        process.standardError = log
        process.terminationHandler = { [weak self] _ in
            Task { @MainActor in
                self?.process = nil
                guard let self, !self.isStopping else { return }
                try? await Task.sleep(for: .seconds(2))
                self.start()
            }
        }

        do {
            try process.run()
            self.process = process
        } catch {
            NSLog("Unable to launch NitroShare core: \(error)")
        }
    }

    func stop() {
        isStopping = true
        guard let process else { return }
        process.terminate()
        process.waitUntilExit()
        self.process = nil
    }

    private static func openLog() -> FileHandle {
        let manager = FileManager.default
        try? manager.createDirectory(at: logURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        manager.createFile(atPath: logURL.path, contents: nil)
        return (try? FileHandle(forWritingTo: logURL)) ?? FileHandle.nullDevice
    }
}
