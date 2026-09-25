import AppKit
import SwiftUI

/// The NitroShare window: nearby devices to send files to, as in the AirDrop
/// window in Finder, above the list of transfers. Opened from the menu bar
/// panel, when files are sent, and when NitroShare is opened again while
/// already running.
@MainActor
final class TransfersPanel: NSObject, NSWindowDelegate {
    static let shared = TransfersPanel()

    private(set) var window: NSWindow?

    func show() {
        if let window {
            NSApp.activate()
            window.makeKeyAndOrderFront(nil)
            return
        }

        let controller = NSHostingController(
            rootView: NitroShareWindowView()
                .environment(AppModel.shared)
        )
        controller.sceneBridgingOptions = [.toolbars]

        let window = NSWindow(contentViewController: controller)
        window.title = "NitroShare"
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        window.toolbarStyle = .unified
        window.isReleasedWhenClosed = false
        window.collectionBehavior.insert(.moveToActiveSpace)
        window.contentMinSize = NSSize(width: 460, height: 440)
        window.setContentSize(NSSize(width: 540, height: 580))
        window.delegate = self
        if !window.setFrameUsingName(Self.frameName) {
            window.centerOnActiveScreen()
        }
        window.setFrameAutosaveName(Self.frameName)

        self.window = window
        NSApp.activate()
        window.makeKeyAndOrderFront(nil)
    }

    func windowWillClose(_ notification: Notification) {
        // Rebuild the window next time, so that sheets and scroll positions
        // start fresh
        window = nil
    }

    private static let frameName = "NitroShareWindow"
}

// MARK: - Window contents

/// Files waiting for a device to be chosen
private struct PendingShare: Identifiable {
    let id = UUID()
    let files: [URL]
}

private struct NitroShareWindowView: View {
    @Environment(AppModel.self) private var model

    @State private var pendingShare: PendingShare?
    @State private var isDropTargeted = false

    var body: some View {
        VStack(spacing: 0) {
            DevicesArea(
                chooseFiles: chooseFiles(for:),
                send: { urls, device in model.send(urls, to: device) }
            )

            Divider()

            TransfersArea()
        }
        .frame(minWidth: 460, minHeight: 440)
        .background(Color(nsColor: .windowBackgroundColor))
        .overlay {
            // Files dropped anywhere except on a device are shared like in
            // Finder: the device is chosen afterwards
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(Color.accentColor, lineWidth: 3)
                .padding(4)
                .opacity(isDropTargeted ? 1 : 0)
                .allowsHitTesting(false)
        }
        .dropDestination(for: URL.self) { urls, _ in
            let files = urls.filter(\.isFileURL)
            guard !files.isEmpty else { return false }
            pendingShare = PendingShare(files: files)
            return true
        } isTargeted: { targeted in
            withAnimation(.easeOut(duration: 0.15)) { isDropTargeted = targeted }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    model.revealReceivedFiles()
                } label: {
                    Label("Open Received Files", systemImage: "folder")
                }
                .help(Text("Open Received Files"))
            }
            ToolbarItem(placement: .primaryAction) {
                Button {
                    chooseFiles(for: nil)
                } label: {
                    Label("Send Files…", systemImage: "square.and.arrow.up")
                        .labelStyle(.titleAndIcon)
                }
                .keyboardShortcut("o")
                .help(Text("Choose files to send to a nearby device (⌘O)"))
            }
        }
        .sheet(item: $pendingShare) { share in
            ShareView(files: share.files, isInTitledWindow: false) {
                pendingShare = nil
            }
            .environment(model)
        }
    }

    /// Files and folders can both be chosen. With a device, they are sent to
    /// it right away; otherwise the device is chosen next.
    private func chooseFiles(for device: Device?) {
        let title = device.map { String(localized: "Send to \($0.displayName)") }
            ?? String(localized: "Choose the items to send")
        ItemPicker.choose(
            title: title,
            prompt: device == nil ? String(localized: "Choose") : String(localized: "Send"),
            attachedTo: TransfersPanel.shared.window
        ) { urls in
            if let device {
                model.send(urls, to: device)
            } else {
                pendingShare = PendingShare(files: urls)
            }
        }
    }
}

// MARK: Devices

private struct DevicesArea: View {
    @Environment(AppModel.self) private var model
    let chooseFiles: (Device?) -> Void
    let send: ([URL], Device) -> Void

    var body: some View {
        VStack(spacing: 0) {
            SectionHeader("Nearby Devices")

            Group {
                if model.connection == .unavailable {
                    EmptyState(
                        symbol: "exclamationmark.triangle",
                        title: "NitroShare isn’t responding",
                        message: "The transfer service couldn’t be started. Try quitting and reopening NitroShare."
                    )
                } else if model.devices.isEmpty {
                    EmptyState(
                        symbol: "dot.radiowaves.left.and.right",
                        title: "Looking for devices…",
                        message: "Devices running NitroShare on this network will appear here."
                    )
                } else {
                    // Few devices are ever on a network, so the grid grows
                    // with them instead of scrolling
                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: 112), spacing: 8, alignment: .top)],
                        spacing: 20
                    ) {
                        ForEach(model.devices) { device in
                            DeviceTile(
                                device: device,
                                transfer: activeTransfer(to: device),
                                onDrop: { urls in send(urls, device) },
                                action: { chooseFiles(device) }
                            )
                            .help(Text("Click to choose files, or drop files here to send them to \(device.displayName)"))
                        }
                    }
                    .padding(.horizontal, 20)
                }
            }
            .frame(minHeight: 140)

            Text("Drop files on a device, or click it to choose them.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
                .padding(.top, 24)
                .padding(.bottom, 24)
        }
    }

    /// The latest transfer to the device that is still running
    private func activeTransfer(to device: Device) -> Transfer? {
        model.transfers.last {
            $0.direction == .send && !$0.isFinished && $0.deviceName == device.name
        }
    }
}

// MARK: Transfers

private struct TransfersArea: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(spacing: 0) {
            SectionHeader("Transfers") {
                if model.transfers.contains(where: \.isFinished) {
                    Button("Clear") {
                        model.clearFinished()
                    }
                    .buttonStyle(.borderless)
                    .help(Text("Remove finished transfers from the list"))
                }
            }

            if model.transfers.isEmpty {
                EmptyState(
                    symbol: "arrow.up.arrow.down",
                    title: "No transfers",
                    message: "Files you send or receive will appear here."
                )
                .frame(maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 2) {
                        ForEach(model.transfers.reversed()) { transfer in
                            TransferRow(transfer: transfer, isLarge: true)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.bottom, 12)
                }
                .frame(maxHeight: .infinity)
            }
        }
    }
}

private struct SectionHeader<Accessory: View>: View {
    let title: LocalizedStringKey
    let accessory: Accessory

    init(_ title: LocalizedStringKey, @ViewBuilder accessory: () -> Accessory = { EmptyView() }) {
        self.title = title
        self.accessory = accessory()
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.headline)
            Spacer()
            accessory
        }
        .padding(.horizontal, 22)
        .padding(.top, 20)
        .padding(.bottom, 14)
    }
}
