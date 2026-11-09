import SwiftUI

struct ModelCard<Content: View>: View {
    var background: Color = Color.appSurface
    var stroke: Color = .primary.opacity(0.10)
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(background, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(stroke)
            }
    }
}

struct StackSuggestionRow: View {
    var title: String
    var subtitle: String
    var tag: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: "square.stack.3d.up.fill")
                    .font(.title2)
                    .foregroundStyle(Color.appBlue)
                    .frame(width: 52, height: 52)
                    .background(Color.appBlue.opacity(0.12), in: RoundedRectangle(cornerRadius: 14))
                VStack(alignment: .leading, spacing: 4) {
                    if !tag.isEmpty {
                        Text(tag)
                            .font(.caption2.weight(.bold))
                            .tracking(1.5)
                            .foregroundStyle(.orange)
                    }
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: 8)
                Image(systemName: "chevron.right")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding()
            .background(Color.appSurface, in: RoundedRectangle(cornerRadius: 18))
            .overlay {
                RoundedRectangle(cornerRadius: 18).stroke(.primary.opacity(0.10))
            }
        }
        .buttonStyle(.plain)
    }
}

struct DividerWithText: View {
    var text: String

    var body: some View {
        HStack {
            Rectangle().fill(.primary.opacity(0.12)).frame(height: 1)
            Text(text).foregroundStyle(.secondary)
            Rectangle().fill(.primary.opacity(0.12)).frame(height: 1)
        }
    }
}

struct SectionHeader: View {
    var title: String

    var body: some View {
        HStack {
            Text(title)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.secondary)
                .tracking(3)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
            Rectangle().fill(.primary.opacity(0.12)).frame(height: 1)
        }
    }
}
