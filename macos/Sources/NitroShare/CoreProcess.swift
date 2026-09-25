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

        Self.stopOrphanedCores()

        let process = Process()
        process.executableURL = executable
        // Launch at login is handled natively with SMAppService; the core
        // quits by itself if this app exits without stopping it
        process.arguments = ["--plugin-blacklist", "autostart", "--exit-with-parent"]
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

    /// A core left running by a previous launch that was force quit or crashed
    /// (or by a version without --exit-with-parent) would make the new core
    /// exit as "already running", leaving this app talking to a core that
    /// lacks its Local Network permission. Cores whose parent has gone are
    /// reparented to launchd (pid 1).
    private static func stopOrphanedCores() {
        let pkill = Process()
        pkill.executableURL = URL(filePath: "/usr/bin/pkill")
        pkill.arguments = ["-x", "-P", "1", "-U", String(getuid()), "nitroshare-cli"]
        pkill.standardOutput = FileHandle.nullDevice
        pkill.standardError = FileHandle.nullDevice
        do {
            try pkill.run()
            pkill.waitUntilExit()
            // pkill exits with 0 only when a process was signalled
            if pkill.terminationStatus == 0 {
                // Give the core time to release its ports
                Thread.sleep(forTimeInterval: 1)
            }
        } catch {
            NSLog("Unable to look for orphaned NitroShare cores: \(error)")
        }
    }

    private static func openLog() -> FileHandle {
        let manager = FileManager.default
        try? manager.createDirectory(at: logURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        manager.createFile(atPath: logURL.path, contents: nil)
        return (try? FileHandle(forWritingTo: logURL)) ?? FileHandle.nullDevice
    }
}
