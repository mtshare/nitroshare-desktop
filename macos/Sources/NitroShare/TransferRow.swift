import SwiftUI

struct TransferRow: View {
    @Environment(AppModel.self) private var model
    let transfer: Transfer
    /// Larger layout used in the NitroShare window
    var isLarge = false

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: isLarge ? 12 : 10) {
            RowIcon(symbol: symbol, tint: tint, diameter: isLarge ? 36 : 28)

            VStack(alignment: .leading, spacing: isLarge ? 4 : 3) {
                Text(title)
                    .font(isLarge ? .body.weight(.medium) : .body)
                    .lineLimit(1)

                if !transfer.isFinished {
                    ProgressView(value: Double(transfer.progress), total: 100)
                        .progressViewStyle(.linear)
                        .controlSize(isLarge ? .regular : .small)
                }

                Text(subtitle)
                    .font(isLarge ? .callout : .caption)
                    .foregroundStyle(transfer.state == .failed ? AnyShapeStyle(.red) : AnyShapeStyle(.secondary))
                    .lineLimit(2)
                    .monospacedDigit()
            }

            Spacer(minLength: 0)

            accessory
        }
        .padding(.horizontal, isLarge ? 10 : 8)
        .padding(.vertical, isLarge ? 8 : 5)
        .contentShape(Rectangle())
        .background(
            RoundedRectangle(cornerRadius: isLarge ? 10 : 8, style: .continuous)
                .fill(isHovered ? AnyShapeStyle(.quaternary) : AnyShapeStyle(.clear))
        )
        .onHover { isHovered = $0 }
        .contextMenu { contextMenu }
        .animation(.default, value: transfer.state)
    }

    private var buttonDiameter: CGFloat { isLarge ? 24 : 18 }

    @ViewBuilder
    private var accessory: some View {
        if !transfer.isFinished {
            CircleButton(symbol: "xmark", help: "Cancel", diameter: buttonDiameter) {
                model.cancel(transfer)
            }
        } else {
            HStack(spacing: isLarge ? 6 : 4) {
                if transfer.direction == .receive && transfer.state == .succeeded {
                    CircleButton(symbol: "magnifyingglass", help: "Show in Finder", diameter: buttonDiameter) {
                        model.revealReceivedFiles()
                    }
                }
                if isHovered {
                    CircleButton(symbol: "xmark", help: "Remove", diameter: buttonDiameter) {
                        model.dismiss(transfer)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var contextMenu: some View {
        if !transfer.isFinished {
            Button("Cancel Transfer") {
                model.cancel(transfer)
            }
        } else {
            if transfer.direction == .receive && transfer.state == .succeeded {
                Button("Show in Finder") {
                    model.revealReceivedFiles()
                }
            }
            Button("Remove from List") {
                model.dismiss(transfer)
            }
        }
    }

    private var title: String {
        switch transfer.direction {
        case .send:
            return String(localized: "To \(transfer.displayDeviceName)")
        case .receive:
            return String(localized: "From \(transfer.displayDeviceName)")
        }
    }

    private var symbol: String {
        switch transfer.state {
        case .succeeded:
            return "checkmark"
        case .failed:
            return "exclamationmark"
        default:
            return transfer.direction == .send ? "arrow.up" : "arrow.down"
        }
    }

    private var tint: Color {
        switch transfer.state {
        case .succeeded:
            return .green
        case .failed:
            return .red
        default:
            return .accentColor
        }
    }

    private var subtitle: String {
        switch transfer.state {
        case .connecting:
            return String(localized: "Connecting…")
        case .inProgress:
            let speed = Int64(transfer.speed).formatted(.byteCount(style: .file))
            guard transfer.speed > 0 else {
                return "\(transfer.progress)%"
            }
            let seconds = transfer.bytesRemaining / transfer.speed
            let remaining = Duration.seconds(seconds).formatted(.units(allowed: [.hours, .minutes, .seconds], width: .abbreviated, maximumUnitCount: 2))
            return String(localized: "\(speed)/s — \(remaining) remaining")
        case .failed:
            return transfer.error.isEmpty ? String(localized: "Failed") : transfer.displayError
        case .succeeded:
            return transfer.direction == .send ? String(localized: "Sent") : String(localized: "Received")
        }
    }
}

/// Borderless circular button used for row actions
struct CircleButton: View {
    let symbol: String
    let help: LocalizedStringKey
    var diameter: CGFloat = 18
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: diameter / 2, weight: .bold))
                .foregroundStyle(.secondary)
                .frame(width: diameter, height: diameter)
                .background(Circle().fill(.quaternary))
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .help(Text(help))
    }
}
