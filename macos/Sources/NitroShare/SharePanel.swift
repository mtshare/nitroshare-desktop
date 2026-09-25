import AppKit
import SwiftUI

/// AirDrop-style window for choosing which devices to send files to. Shown
/// when files arrive from the Share menu, "Open With" or the Dock icon.
@MainActor
final class SharePanel: NSObject, NSWindowDelegate {
    static let shared = SharePanel()

    private var panel: NSPanel?

    func present(_ urls: [URL]) {
        let files = urls.filter(\.isFileURL)
        guard !files.isEmpty else { return }

        close()

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 320),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.title = String(localized: "Share with NitroShare")
        panel.titlebarAppearsTransparent = true
        panel.titleVisibility = .hidden
        panel.isMovableByWindowBackground = true
        panel.isReleasedWhenClosed = false
        panel.keepVisibleWhenInactive()
        panel.delegate = self
        // The window follows the height of its content, which grows as
        // devices are found
        let controller = NSHostingController(
            rootView: ShareView(
                files: files,
                dismiss: { [weak self] in self?.close() }
            )
            .environment(AppModel.shared)
        )
        controller.sizingOptions = [.preferredContentSize]
        panel.contentViewController = controller
        panel.setContentSize(controller.view.fittingSize)
        panel.centerOnActiveScreen()

        self.panel = panel
        NSApp.activate()
        panel.makeKeyAndOrderFront(nil)
        panel.orderFrontRegardless()
    }

    func close() {
        panel?.close()
    }

    func windowWillClose(_ notification: Notification) {
        panel = nil
    }
}

/// Summary of the items being shared and the devices to send them to. Several
/// devices can be chosen one after the other, as in AirDrop; each one shows
/// the progress of its transfer. Used in the share window and as a sheet of
/// the NitroShare window.
struct ShareView: View {
    @Environment(AppModel.self) private var model
    let files: [URL]
    /// The share window has a transparent title bar above the content
    var isInTitledWindow = true
    let dismiss: () -> Void

    /// Highest transfer id when the files were sent to each device (by UUID);
    /// the device's transfer is the next one to it
    @State private var sentAfter: [String: Int] = [:]

    var body: some View {
        VStack(spacing: 0) {
            summary
                .padding(.top, isInTitledWindow ? 40 : 24)
                .padding(.horizontal, 24)
                .padding(.bottom, 20)

            Divider()

            devices
                .frame(maxWidth: .infinity, minHeight: 160)

            Divider()

            footer
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
        }
        .frame(width: 520)
        .background(.regularMaterial)
    }

    private var summary: some View {
        HStack(spacing: 14) {
            Image(nsImage: icon)
                .resizable()
                .frame(width: 52, height: 52)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.headline)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
    }

    @ViewBuilder
    private var devices: some View {
        if model.devices.isEmpty {
            VStack(spacing: 10) {
                Image(systemName: "dot.radiowaves.left.and.right")
                    .font(.system(size: 30, weight: .light))
                    .foregroundStyle(.secondary)
                    .symbolEffect(.variableColor.iterative, options: .repeating)
                Text("Looking for devices…")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 32)
        } else {
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 112), spacing: 8, alignment: .top)],
                spacing: 20
            ) {
                ForEach(model.devices) { device in
                    DeviceTile(device: device, transfer: transfer(for: device)) {
                        send(to: device)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 22)
        }
    }

    private var footer: some View {
        HStack(spacing: 12) {
            Text(sentAfter.isEmpty
                 ? "Choose one or more devices."
                 : "You can choose more devices.")
                .font(.callout)
                .foregroundStyle(.secondary)
            Spacer()
            if sentAfter.isEmpty {
                Button("Cancel", role: .cancel, action: dismiss)
                    .keyboardShortcut(.cancelAction)
                    .controlSize(.large)
            } else {
                Button("Done", action: dismiss)
                    .keyboardShortcut(.defaultAction)
                    .controlSize(.large)
            }
        }
    }

    private func transfer(for device: Device) -> Transfer? {
        guard let baseline = sentAfter[device.uuid] else { return nil }
        return model.transfers.first {
            $0.direction == .send && (Int($0.id) ?? 0) > baseline && $0.deviceName == device.name
        }
    }

    private func send(to device: Device) {
        // Choosing a device again while its transfer is running does nothing;
        // once finished, the files are sent again
        if let transfer = transfer(for: device), !transfer.isFinished {
            return
        }
        sentAfter[device.uuid] = model.transfers.compactMap { Int($0.id) }.max() ?? 0
        // The tiles show the progress; a notification tells when it's done
        model.send(files, to: device, showingWindow: false)
    }

    private var icon: NSImage {
        if files.count == 1 {
            return NSWorkspace.shared.icon(forFile: files[0].path)
        }
        return NSWorkspace.shared.icon(for: .item)
    }

    private var title: String {
        files.count == 1
            ? FileManager.default.displayName(atPath: files[0].path)
            : String(localized: "\(files.count) items")
    }

    private var detail: String {
        let size = files.reduce(Int64(0)) { total, url in
            let values = try? url.resourceValues(forKeys: [.totalFileAllocatedSizeKey, .isDirectoryKey])
            return total + Int64(values?.totalFileAllocatedSize ?? 0)
        }
        if size > 0 {
            return size.formatted(.byteCount(style: .file))
        }
        // Folder sizes aren't known without walking their contents
        if files.count == 1, files[0].hasDirectoryPath || (try? files[0].resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true {
            return String(localized: "Folder")
        }
        return String(localized: "Choose a device")
    }
}

/// Large round device button, as in AirDrop. Files can also be dropped on it,
/// and a ring around it shows the progress of a transfer to the device.
struct DeviceTile: View {
    let device: Device
    var transfer: Transfer?
    var onDrop: (([URL]) -> Void)?
    let action: () -> Void
    @State private var isHovered = false
    @State private var isTargeted = false

    private let diameter: CGFloat = 64

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                circle
                    .overlay(progressRing)
                    .overlay(alignment: .bottomTrailing) { badge }
                    .scaleEffect(isHovered || isTargeted ? 1.06 : 1)

                VStack(spacing: 2) {
                    Text(device.displayName)
                        .font(.system(size: 12))
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                    if let status {
                        Text(status)
                            .font(.system(size: 11))
                            .foregroundStyle(transfer?.state == .failed ? AnyShapeStyle(.red) : AnyShapeStyle(.secondary))
                            .monospacedDigit()
                            .lineLimit(1)
                    }
                }
                .frame(width: 96)
            }
            .padding(6)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isHovered ? AnyShapeStyle(.quaternary) : AnyShapeStyle(.clear))
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        // The hover and drop highlights already show which tile is active
        .focusEffectDisabled()
        .onHover { hovering in
            withAnimation(.spring(duration: 0.2)) { isHovered = hovering }
        }
        .dropDestination(for: URL.self) { urls, _ in
            guard let onDrop else { return false }
            onDrop(urls)
            return true
        } isTargeted: { targeted in
            guard onDrop != nil else { return }
            withAnimation(.spring(duration: 0.2)) { isTargeted = targeted }
        }
        .animation(.easeInOut(duration: 0.25), value: transfer?.state)
        .animation(.linear(duration: 0.9), value: transfer?.progress)
    }

    private var circle: some View {
        Image(systemName: device.symbolName)
            .font(.system(size: 26, weight: .regular))
            .foregroundStyle(.white)
            .frame(width: diameter, height: diameter)
            .background(
                Circle().fill(
                    LinearGradient(
                        colors: [Color.accentColor.opacity(0.85), Color.accentColor],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            )
            .shadow(color: .black.opacity(0.15), radius: 3, y: 1)
            .overlay(
                Circle()
                    .strokeBorder(Color.accentColor.opacity(0.5), lineWidth: 4)
                    .padding(-6)
                    .opacity(isTargeted ? 1 : 0)
            )
    }

    /// Track and progress arc just outside the circle while sending
    @ViewBuilder
    private var progressRing: some View {
        if let transfer, !transfer.isFinished {
            ZStack {
                Circle()
                    .stroke(.quaternary, lineWidth: 3)
                if transfer.state == .connecting {
                    // Indeterminate: a short arc spinning around
                    TimelineView(.animation) { context in
                        let angle = context.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 1) * 360
                        Circle()
                            .trim(from: 0, to: 0.2)
                            .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                            .rotationEffect(.degrees(angle))
                    }
                } else {
                    Circle()
                        .trim(from: 0, to: max(0.02, Double(transfer.progress) / 100))
                        .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                }
            }
            .padding(-6)
            .transition(.opacity)
        }
    }

    @ViewBuilder
    private var badge: some View {
        if let transfer, transfer.isFinished {
            let succeeded = transfer.state == .succeeded
            Image(systemName: succeeded ? "checkmark" : "exclamationmark")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 22, height: 22)
                .background(Circle().fill(succeeded ? Color.green : Color.red))
                .overlay(Circle().strokeBorder(.background, lineWidth: 2))
                .offset(x: 2, y: 2)
                .transition(.scale.combined(with: .opacity))
                .help(Text(succeeded ? "Sent" : "Failed"))
        }
    }

    private var status: String? {
        guard let transfer else { return nil }
        switch transfer.state {
        case .connecting:
            return String(localized: "Waiting…")
        case .inProgress:
            return "\(transfer.progress)%"
        case .succeeded:
            return String(localized: "Sent")
        case .failed:
            return String(localized: "Failed")
        }
    }
}
