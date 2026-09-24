import SwiftUI

/// Contents of the menu bar window, styled after Control Center
struct MenuPanel: View {
    @Environment(AppModel.self) private var model
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
                .padding(.horizontal, 14)
                .padding(.top, 12)
                .padding(.bottom, 10)

            Divider()
                .padding(.horizontal, 14)

            ScrollView {
                VStack(alignment: .leading, spacing: 2) {
                    devicesSection
                    if !model.transfers.isEmpty {
                        transfersSection
                    }
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 8)
            }
            .scrollBounceBehavior(.basedOnSize)
            .frame(maxHeight: 440)

            Divider()
                .padding(.horizontal, 14)

            footer
                .padding(.horizontal, 6)
                .padding(.vertical, 6)
        }
        .frame(width: 340)
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "arrow.up.arrow.down")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 30, height: 30)
                .background(Circle().fill(.tint))

            VStack(alignment: .leading, spacing: 1) {
                Text("NitroShare")
                    .font(.headline)
                Group {
                    switch model.connection {
                    case .starting:
                        Text("Starting…")
                    case .unavailable:
                        Text("Not available")
                    case .connected:
                        Text("Visible as “\(model.status?.deviceName ?? "")”")
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            }

            Spacer()

            if model.connection == .starting {
                ProgressView()
                    .controlSize(.small)
            }
        }
    }

    // MARK: Devices

    @ViewBuilder
    private var devicesSection: some View {
        SectionTitle("Nearby Devices")

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
            ForEach(model.devices) { device in
                DeviceRow(device: device)
            }
        }
    }

    // MARK: Transfers

    @ViewBuilder
    private var transfersSection: some View {
        HStack {
            SectionTitle("Transfers")
            Spacer()
            if model.transfers.contains(where: \.isFinished) {
                Button("Clear") {
                    model.clearFinished()
                }
                .buttonStyle(.plain)
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.trailing, 8)
                .padding(.top, 10)
            }
        }

        ForEach(model.transfers.reversed()) { transfer in
            TransferRow(transfer: transfer)
        }
    }

    // MARK: Footer

    private var footer: some View {
        VStack(spacing: 0) {
            MenuRow(title: "Open Received Files") {
                model.revealReceivedFiles()
            }
            MenuRow(title: "Settings…") {
                NSApp.activate()
                openSettings()
            }
            MenuRow(title: "Quit NitroShare") {
                NSApp.terminate(nil)
            }
        }
    }
}

// MARK: - Components

struct SectionTitle: View {
    let title: LocalizedStringKey

    init(_ title: LocalizedStringKey) {
        self.title = title
    }

    var body: some View {
        Text(title)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 8)
            .padding(.top, 10)
            .padding(.bottom, 4)
    }
}

struct EmptyState: View {
    let symbol: String
    let title: LocalizedStringKey
    let message: LocalizedStringKey

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: symbol)
                .font(.system(size: 26, weight: .light))
                .foregroundStyle(.secondary)
                .symbolEffect(.variableColor.iterative, options: .repeating, isActive: symbol == "dot.radiowaves.left.and.right")
                .padding(.bottom, 2)
            Text(title)
                .font(.callout.weight(.medium))
            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 24)
        .padding(.vertical, 18)
    }
}

/// Circular symbol used at the leading edge of rows, as in Control Center
struct RowIcon: View {
    let symbol: String
    var tint: Color = .accentColor
    var isHighlighted = true

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(isHighlighted ? .white : .primary)
            .frame(width: 28, height: 28)
            .background(
                Circle().fill(isHighlighted ? AnyShapeStyle(tint) : AnyShapeStyle(.quaternary))
            )
    }
}

/// Plain full-width menu item with a hover highlight
struct MenuRow: View {
    let title: LocalizedStringKey
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Text(title)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .contentShape(Rectangle())
                .background(
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(isHovered ? AnyShapeStyle(.quaternary) : AnyShapeStyle(.clear))
                )
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}
