import AppKit
import Observation
import ServiceManagement

@MainActor
@Observable
final class AppModel {
    enum Connection: Equatable {
        case starting
        case connected
        case unavailable
    }

    static let shared = AppModel()

    private(set) var connection = Connection.starting
    private(set) var devices: [Device] = []
    private(set) var transfers: [Transfer] = []
    private(set) var status: Status?
    private(set) var settings: [String: SettingEntry] = [:]

    private let api = APIClient()
    private let core = CoreProcess()
    private let notifier = Notifier()
    private var pollTask: Task<Void, Never>?
    private var failedPolls = 0
    private var hasLoadedTransfers = false

    var activeTransfers: [Transfer] { transfers.filter { !$0.isFinished } }

    var receiveDirectory: URL {
        let path = settings[SettingName.transferDirectory]?.value.string
            ?? FileManager.default.homeDirectoryForCurrentUser.appending(path: "Downloads").path
        return URL(filePath: path, directoryHint: .isDirectory)
    }

    // MARK: Lifecycle

    func start() {
        notifier.requestAuthorization()
        core.start()
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.refresh()
                try? await Task.sleep(for: .seconds(1))
            }
        }
    }

    func stop() {
        pollTask?.cancel()
        core.stop()
    }

    private func refresh() async {
        do {
            let devices = try await api.call("devices", as: [Device].self)
            let transfers = try await api.call("transferlist", as: [Transfer].self)
            if status == nil {
                status = try await api.call("status", as: Status.self)
                await reloadSettings()
            }

            if hasLoadedTransfers {
                notifier.notifyChanges(from: self.transfers, to: transfers)
            }
            hasLoadedTransfers = true
            // The core also finds this Mac through its own announcements
            self.devices = Self.uniqueDevices(devices).filter { $0.uuid != status?.deviceUuid }
            self.transfers = transfers
            connection = .connected
            failedPolls = 0
        } catch {
            failedPolls += 1
            status = nil
            // Give the core a few seconds to start before reporting a problem
            if failedPolls > 8 {
                connection = .unavailable
            }
        }
    }

    /// The same device can be found by several enumerators (mDNS, broadcast);
    /// keep one entry per device, preferring one that can be connected to
    private static func uniqueDevices(_ devices: [Device]) -> [Device] {
        var byUuid: [String: Device] = [:]
        for device in devices {
            if let existing = byUuid[device.uuid], existing.isReachable || !device.isReachable {
                continue
            }
            byUuid[device.uuid] = device
        }
        return byUuid.values
            .sorted { $0.displayName.localizedStandardCompare($1.displayName) == .orderedAscending }
    }

    // MARK: Transfers

    /// The NitroShare window is shown so the progress can be followed, unless
    /// the caller shows it itself (the share window does, on its devices)
    func send(_ urls: [URL], to device: Device, showingWindow: Bool = true) {
        let items = urls.filter(\.isFileURL).map(\.path)
        guard !items.isEmpty else { return }
        if showingWindow {
            TransfersPanel.shared.show()
        }
        Task {
            _ = try? await api.call("senditems", [
                "device": device.uuid,
                "enumerator": device.deviceEnumeratorName,
                "items": items,
            ])
            await refresh()
        }
    }

    func chooseAndSend(to device: Device) {
        ItemPicker.choose(
            title: String(localized: "Send to \(device.displayName)"),
            prompt: String(localized: "Send")
        ) { [weak self] urls in
            self?.send(urls, to: device)
        }
    }

    /// Choose items first, then the device in the share window
    func chooseAndShare() {
        ItemPicker.choose(
            title: String(localized: "Choose the items to send"),
            prompt: String(localized: "Choose")
        ) { urls in
            SharePanel.shared.present(urls)
        }
    }

    func cancel(_ transfer: Transfer) {
        perform("transfercancel", ["id": transfer.id])
    }

    func dismiss(_ transfer: Transfer) {
        perform("transferdismiss", ["id": transfer.id])
    }

    func clearFinished() {
        perform("transferclear")
    }

    func revealReceivedFiles() {
        NSWorkspace.shared.open(receiveDirectory)
    }

    private func perform(_ action: String, _ params: [String: any Sendable] = [:]) {
        Task {
            _ = try? await api.call(action, params)
            await refresh()
        }
    }

    // MARK: Settings

    func reloadSettings() async {
        guard let entries = try? await api.call("settinglist", as: [SettingEntry].self) else { return }
        settings = Dictionary(entries.map { ($0.name, $0) }, uniquingKeysWith: { first, _ in first })
    }

    func setting(_ name: String) -> JSONValue {
        settings[name]?.value ?? .null
    }

    func setSetting(_ name: String, to value: any Sendable) {
        Task {
            _ = try? await api.call("settingset", ["name": name, "value": value])
            await reloadSettings()
            if name == SettingName.deviceName {
                status = try? await api.call("status", as: Status.self)
            }
        }
    }

    var launchAtLogin: Bool {
        get { SMAppService.mainApp.status == .enabled }
        set {
            do {
                if newValue {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                NSLog("Unable to change login item: \(error)")
            }
        }
    }
}
