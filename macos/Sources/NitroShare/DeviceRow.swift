import SwiftUI

struct DeviceRow: View {
    @Environment(AppModel.self) private var model
    let device: Device

    @State private var isHovered = false
    @State private var isTargeted = false

    var body: some View {
        Button {
            MenuPanel.close()
            model.chooseAndSend(to: device)
        } label: {
            HStack(spacing: 10) {
                RowIcon(symbol: device.symbolName, isHighlighted: isHovered || isTargeted)

                VStack(alignment: .leading, spacing: 1) {
                    Text(device.displayName)
                        .lineLimit(1)
                    Group {
                        if isTargeted {
                            Text("Release to send")
                        } else if let address = device.address {
                            Text(address)
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }

                Spacer(minLength: 0)

                if isHovered && !isTargeted {
                    Text("Send…")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .transition(.opacity)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .contentShape(Rectangle())
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(background)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(Color.accentColor, lineWidth: isTargeted ? 2 : 0)
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.12)) { isHovered = hovering }
        }
        .dropDestination(for: URL.self) { urls, _ in
            model.send(urls, to: device)
            return true
        } isTargeted: { targeted in
            withAnimation(.easeOut(duration: 0.12)) { isTargeted = targeted }
        }
        .help(Text("Click to choose files, or drop files here to send them to \(device.displayName)"))
    }

    private var background: AnyShapeStyle {
        if isTargeted {
            return AnyShapeStyle(Color.accentColor.opacity(0.15))
        }
        return isHovered ? AnyShapeStyle(.quaternary) : AnyShapeStyle(.clear)
    }
}
