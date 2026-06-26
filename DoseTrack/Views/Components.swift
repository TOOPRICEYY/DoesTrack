import SwiftUI

extension Color {
    init(hex: String) {
        let cleaned = hex
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "#", with: "")

        var value: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&value)

        let red: Double
        let green: Double
        let blue: Double

        switch cleaned.count {
        case 6:
            red = Double((value & 0xFF0000) >> 16) / 255
            green = Double((value & 0x00FF00) >> 8) / 255
            blue = Double(value & 0x0000FF) / 255
        default:
            red = 0.09
            green = 0.43
            blue = 0.52
        }

        self.init(red: red, green: green, blue: blue)
    }
}

struct StatusChip: View {
    var status: DoseLogStatus?

    var body: some View {
        if let status {
            Label(status.label, systemImage: status.systemImage)
                .font(.caption.weight(.semibold))
                .foregroundStyle(status.tint)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(status.tint.opacity(0.12), in: Capsule())
        } else {
            Label("Due", systemImage: "bell.fill")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.blue)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(.blue.opacity(0.12), in: Capsule())
        }
    }
}

struct EmptyStateView: View {
    var systemImage: String
    var title: String
    var message: String

    var body: some View {
        ContentUnavailableView {
            Label(title, systemImage: systemImage)
        } description: {
            Text(message)
        }
    }
}

struct MetricTile: View {
    var title: String
    var value: String
    var systemImage: String
    var tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: systemImage)
                .font(.title3.weight(.semibold))
                .foregroundStyle(tint)
                .frame(width: 36, height: 36)
                .background(tint.opacity(0.14), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.title2.weight(.bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)

                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.background, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(.quaternary)
        }
    }
}

struct MedicationSwatch: View {
    var colorHex: String

    var body: some View {
        Circle()
            .fill(Color(hex: colorHex))
            .frame(width: 14, height: 14)
            .overlay {
                Circle().stroke(.primary.opacity(0.15))
            }
    }
}

struct PrimaryActionButton: View {
    var title: String
    var systemImage: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
    }
}
