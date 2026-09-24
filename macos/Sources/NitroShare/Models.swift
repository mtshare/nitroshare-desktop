import Foundation

struct Device: Decodable, Identifiable, Hashable, Sendable {
    let uuid: String
    let name: String
    let deviceEnumeratorName: String
    let addresses: [String]?

    var id: String { uuid }

    /// Enumerators append their name (e.g. " [mDNS]") to the device name
    var displayName: String {
        name.replacing(/\s*\[[^\]]*\]$/, with: "")
    }

    var address: String? {
        addresses?.first { !$0.contains(":") } ?? addresses?.first
    }

    var symbolName: String {
        let lowered = name.lowercased()
        if lowered.contains("iphone") || lowered.contains("android") || lowered.contains("phone") {
            return "iphone"
        }
        if lowered.contains("ipad") || lowered.contains("tablet") {
            return "ipad"
        }
        if lowered.contains("imac") || lowered.contains("mac mini") || lowered.contains("studio") || lowered.contains("pc") {
            return "desktopcomputer"
        }
        return "laptopcomputer"
    }
}

struct Transfer: Decodable, Identifiable, Hashable, Sendable {
    enum Direction: String, Decodable, Sendable {
        case send, receive
    }

    enum State: String, Decodable, Sendable {
        case connecting, inProgress, failed, succeeded
    }

    let id: String
    let direction: Direction
    let state: State
    let progress: Int
    let speed: Double
    let bytesRemaining: Double
    let deviceName: String
    let error: String

    var isFinished: Bool { state == .failed || state == .succeeded }

    var displayDeviceName: String {
        deviceName.replacing(/\s*\[[^\]]*\]$/, with: "")
    }
}

struct Status: Decodable, Sendable {
    let version: String
    let deviceName: String
    let deviceUuid: String
}

/// Arbitrary JSON value, used for setting values of varying types
enum JSONValue: Decodable, Hashable, Sendable {
    case null
    case bool(Bool)
    case number(Double)
    case string(String)
    case array([JSONValue])

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode(Double.self) {
            self = .number(value)
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode([JSONValue].self) {
            self = .array(value)
        } else {
            self = .null
        }
    }

    var string: String? {
        if case .string(let value) = self { return value }
        return nil
    }

    var int: Int? {
        if case .number(let value) = self { return Int(value) }
        return nil
    }

    var bool: Bool? {
        if case .bool(let value) = self { return value }
        return nil
    }

    var strings: [String]? {
        if case .array(let values) = self { return values.compactMap(\.string) }
        return nil
    }
}

struct SettingEntry: Decodable, Sendable {
    let name: String
    let title: String
    let type: Int
    let category: String
    let value: JSONValue
}

/// Names of the settings registered by the core and its plugins
enum SettingName {
    static let deviceName = "DeviceName"
    static let transferDirectory = "TransferDirectory"
    static let transferPort = "TransferPort"
    static let broadcastPort = "BroadcastPort"
    static let broadcastInterval = "BroadcastInterval"
    static let broadcastExpiry = "BroadcastExpiry"
    static let tlsEnabled = "TlsEnabled"
    static let tlsCaCertificate = "TlsCaCertificate"
    static let tlsCertificate = "TlsCertificate"
    static let tlsPrivateKey = "TlsPrivateKey"
    static let tlsPrivateKeyPassphrase = "TlsPrivateKeyPassphrase"
    static let staticDevices = "StaticDevices"
}
