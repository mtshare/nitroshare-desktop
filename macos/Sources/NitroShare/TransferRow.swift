import SwiftUI

struct TransferRow: View {
    @Environment(AppModel.self) private var model
    let transfer: Transfer

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 10) {
            RowIcon(symbol: symbol, tint: tint)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .lineLimit(1)

                if !transfer.isFinished {
                    ProgressView(value: Double(transfer.progress), total: 100)
                        .progressViewStyle(.linear)
                        .controlSize(.small)
                }

                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(transfer.state == .failed ? AnyShapeStyle(.red) : AnyShapeStyle(.secondary))
                    .lineLimit(2)
                    .monospacedDigit()
            }

            Spacer(minLength: 0)

            accessory
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(isHovered ? AnyShapeStyle(.quaternary) : AnyShapeStyle(.clear))
        )
        .onHover { isHovered = $0 }
        .animation(.default, value: transfer.state)
    }

    @ViewBuilder
    private var accessory: some View {
        if !transfer.isFinished {
            CircleButton(symbol: "xmark", help: "Cancel") {
                model.cancel(transfer)
            }
        } else {
            HStack(spacing: 4) {
                if transfer.direction == .receive && transfer.state == .succeeded {
                    CircleButton(symbol: "magnifyingglass", help: "Show in Finder") {
                        model.revealReceivedFiles()
                    }
                }
                if isHovered {
                    CircleButton(symbol: "xmark", help: "Remove") {
                        model.dismiss(transfer)
                    }
                }
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
            return transfer.error.isEmpty ? String(localized: "Failed") : transfer.error
        case .succeeded:
            return transfer.direction == .send ? String(localized: "Sent") : String(localized: "Received")
        }
    }
}

/// Small borderless circular button used for row actions
struct CircleButton: View {
    let symbol: String
    let help: LocalizedStringKey
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(.secondary)
                .frame(width: 18, height: 18)
                .background(Circle().fill(.quaternary))
        }
        .buttonStyle(.plain)
        .help(Text(help))
    }
}
