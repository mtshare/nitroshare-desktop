import AppKit
import SwiftUI

/// AirDrop-style window for choosing which device to send files to. Shown
/// when files arrive from the Share menu, "Open With" or the Dock icon.
@MainActor
final class SharePanel {
    static let shared = SharePanel()

    private var panel: NSPanel?

    func present(_ urls: [URL]) {
        let files = urls.filter(\.isFileURL)
        guard !files.isEmpty else { return }

        close()

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 300),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.title = String(localized: "Share with NitroShare")
        panel.titlebarAppearsTransparent = true
        panel.titleVisibility = .hidden
        panel.isMovableByWindowBackground = true
        panel.isReleasedWhenClosed = false
        panel.level = .floating
        panel.contentView = NSHostingView(
            rootView: ShareView(files: files) { [weak self] in self?.close() }
                .environment(AppModel.shared)
        )
        panel.center()

        self.panel = panel
        NSApp.activate()
        panel.makeKeyAndOrderFront(nil)
    }

    func close() {
        panel?.close()
        panel = nil
    }
}

private struct ShareView: View {
    @Environment(AppModel.self) private var model
    let files: [URL]
    let dismiss: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            summary
                .padding(.top, 34)
                .padding(.horizontal, 24)

            Divider()
                .padding(.top, 16)

            devices
                .frame(maxWidth: .infinity, minHeight: 150)

            HStack {
                Spacer()
                Button("Cancel", role: .cancel, action: dismiss)
                    .keyboardShortcut(.cancelAction)
            }
            .padding(16)
        }
        .frame(width: 480)
        .background(.regularMaterial)
    }

    private var summary: some View {
        HStack(spacing: 12) {
            Image(nsImage: icon)
                .resizable()
                .frame(width: 48, height: 48)
            VStack(alignment: .leading, spacing: 2) {
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
            VStack(spacing: 8) {
                Image(systemName: "dot.radiowaves.left.and.right")
                    .font(.system(size: 30, weight: .light))
                    .foregroundStyle(.secondary)
                    .symbolEffect(.variableColor.iterative, options: .repeating)
                Text("Looking for devices…")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 28)
        } else {
            ScrollView(.horizontal) {
                HStack(alignment: .top, spacing: 8) {
                    ForEach(model.devices) { device in
                        DeviceTile(device: device) {
                            model.send(files, to: device)
                            dismiss()
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 18)
                .frame(minWidth: 480)
            }
            .scrollIndicators(.never)
        }
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
        return size > 0 ? size.formatted(.byteCount(style: .file)) : String(localized: "Choose a device")
    }
}

private struct DeviceTile: View {
    let device: Device
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: device.symbolName)
                    .font(.system(size: 26, weight: .regular))
                    .foregroundStyle(.white)
                    .frame(width: 64, height: 64)
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
                    .scaleEffect(isHovered ? 1.06 : 1)

                Text(device.displayName)
                    .font(.caption)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .frame(width: 84)
            }
            .padding(6)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isHovered ? AnyShapeStyle(.quaternary) : AnyShapeStyle(.clear))
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.spring(duration: 0.2)) { isHovered = hovering }
        }
    }
}
