import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralSettings()
                .tabItem { Label("General", systemImage: "gearshape") }
            NetworkSettings()
                .tabItem { Label("Network", systemImage: "network") }
            SecuritySettings()
                .tabItem { Label("Security", systemImage: "lock") }
        }
        .frame(width: 500)
        .fixedSize(horizontal: false, vertical: true)
    }
}

// MARK: - General

private struct GeneralSettings: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model

        Form {
            Section {
                CommitTextField(
                    "Device name",
                    value: model.setting(SettingName.deviceName).string ?? ""
                ) { model.setSetting(SettingName.deviceName, to: $0) }
            } footer: {
                Text("Other devices will see this Mac with this name.")
                    .settingsFootnote()
            }

            Section {
                LabeledContent("Save received files to") {
                    FolderPicker(url: model.receiveDirectory) { url in
                        model.setSetting(SettingName.transferDirectory, to: url.path)
                    }
                }
            }

            Section {
                Toggle("Open at login", isOn: $model.launchAtLogin)
            }

            Section {
                LabeledContent("Version", value: model.status?.version ?? "—")
            }
        }
        .formStyle(.grouped)
        .scrollDisabled(true)
    }
}

// MARK: - Network

private struct NetworkSettings: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        Form {
            Section {
                IntegerField("Transfer port", name: SettingName.transferPort)
            } footer: {
                Text("Port used to receive files. Other devices discover it automatically.")
                    .settingsFootnote()
            }

            Section("Discovery") {
                IntegerField("Broadcast port", name: SettingName.broadcastPort)
                IntegerField("Broadcast interval (ms)", name: SettingName.broadcastInterval)
                IntegerField("Device expiry (ms)", name: SettingName.broadcastExpiry)
            }

            Section {
                CommitTextField(
                    "Additional devices",
                    value: (model.setting(SettingName.staticDevices).strings ?? []).joined(separator: ", "),
                    prompt: "192.168.1.20, 192.168.1.21"
                ) { text in
                    let addresses = text
                        .split(separator: ",")
                        .map { $0.trimmingCharacters(in: .whitespaces) }
                        .filter { !$0.isEmpty }
                    model.setSetting(SettingName.staticDevices, to: addresses)
                }
            } footer: {
                Text("Addresses of devices that can’t be discovered automatically, separated by commas.")
                    .settingsFootnote()
            }
        }
        .formStyle(.grouped)
        .scrollDisabled(true)
    }
}

// MARK: - Security

private struct SecuritySettings: View {
    @Environment(AppModel.self) private var model

    private var tlsEnabled: Binding<Bool> {
        Binding(
            get: { model.setting(SettingName.tlsEnabled).bool ?? false },
            set: { model.setSetting(SettingName.tlsEnabled, to: $0) }
        )
    }

    var body: some View {
        Form {
            Section {
                Toggle("Encrypt transfers with TLS", isOn: tlsEnabled)
            } footer: {
                Text("Both devices need certificates signed by the same certificate authority.")
                    .settingsFootnote()
            }

            if tlsEnabled.wrappedValue {
                Section("Certificates") {
                    FileSetting("CA certificate", name: SettingName.tlsCaCertificate)
                    FileSetting("Certificate", name: SettingName.tlsCertificate)
                    FileSetting("Private key", name: SettingName.tlsPrivateKey)
                    SecureCommitField(
                        "Private key passphrase",
                        value: model.setting(SettingName.tlsPrivateKeyPassphrase).string ?? ""
                    ) { model.setSetting(SettingName.tlsPrivateKeyPassphrase, to: $0) }
                }
            }
        }
        .formStyle(.grouped)
        .scrollDisabled(true)
        .animation(.default, value: tlsEnabled.wrappedValue)
    }
}

// MARK: - Controls

/// Text field that only saves when editing ends, so the device isn't
/// re-announced on every keystroke
private struct CommitTextField: View {
    let title: LocalizedStringKey
    let value: String
    var prompt: String?
    let commit: (String) -> Void

    @State private var text = ""
    @FocusState private var isFocused: Bool

    init(_ title: LocalizedStringKey, value: String, prompt: String? = nil, commit: @escaping (String) -> Void) {
        self.title = title
        self.value = value
        self.prompt = prompt
        self.commit = commit
    }

    var body: some View {
        TextField(title, text: $text, prompt: prompt.map { Text($0) })
            .focused($isFocused)
            .onAppear { text = value }
            .onChange(of: value) { if !isFocused { text = value } }
            .onSubmit(save)
            .onChange(of: isFocused) { if !isFocused { save() } }
    }

    private func save() {
        if text != value {
            commit(text)
        }
    }
}

private struct SecureCommitField: View {
    let title: LocalizedStringKey
    let value: String
    let commit: (String) -> Void

    @State private var text = ""
    @FocusState private var isFocused: Bool

    init(_ title: LocalizedStringKey, value: String, commit: @escaping (String) -> Void) {
        self.title = title
        self.value = value
        self.commit = commit
    }

    var body: some View {
        SecureField(title, text: $text)
            .focused($isFocused)
            .onAppear { text = value }
            .onSubmit(save)
            .onChange(of: isFocused) { if !isFocused { save() } }
    }

    private func save() {
        if text != value {
            commit(text)
        }
    }
}

private struct IntegerField: View {
    @Environment(AppModel.self) private var model
    let title: LocalizedStringKey
    let name: String

    init(_ title: LocalizedStringKey, name: String) {
        self.title = title
        self.name = name
    }

    var body: some View {
        CommitTextField(title, value: model.setting(name).int.map(String.init) ?? "") { text in
            if let number = Int(text) {
                model.setSetting(name, to: number)
            }
        }
        .multilineTextAlignment(.trailing)
    }
}

private struct FileSetting: View {
    @Environment(AppModel.self) private var model
    let title: LocalizedStringKey
    let name: String

    init(_ title: LocalizedStringKey, name: String) {
        self.title = title
        self.name = name
    }

    var body: some View {
        let path = model.setting(name).string ?? ""
        LabeledContent(title) {
            HStack {
                Text(path.isEmpty ? String(localized: "None") : URL(filePath: path).lastPathComponent)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Button("Choose…") {
                    let panel = NSOpenPanel()
                    panel.canChooseFiles = true
                    panel.canChooseDirectories = false
                    if panel.runModal() == .OK, let url = panel.url {
                        model.setSetting(name, to: url.path)
                    }
                }
            }
        }
    }
}

/// Folder popup in the style of System Settings: current folder, then "Other…"
private struct FolderPicker: View {
    let url: URL
    let choose: (URL) -> Void

    var body: some View {
        Menu {
            Button {
                NSWorkspace.shared.open(url)
            } label: {
                Label("Show in Finder", systemImage: "folder")
            }
            Divider()
            Button("Other…") {
                let panel = NSOpenPanel()
                panel.canChooseFiles = false
                panel.canChooseDirectories = true
                panel.canCreateDirectories = true
                panel.directoryURL = url
                if panel.runModal() == .OK, let chosen = panel.url {
                    choose(chosen)
                }
            }
        } label: {
            Label {
                Text(FileManager.default.displayName(atPath: url.path))
            } icon: {
                Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
                    .resizable()
                    .frame(width: 16, height: 16)
            }
            .labelStyle(.titleAndIcon)
        }
        .fixedSize()
    }
}

private extension Text {
    func settingsFootnote() -> some View {
        self.font(.caption)
            .foregroundStyle(.secondary)
    }
}
