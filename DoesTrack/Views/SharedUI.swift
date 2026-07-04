import SwiftUI

struct ModelCard<Content: View>: View {
    var background: Color = .white
    var stroke: Color = .black.opacity(0.10)
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
                    .frame(width: 56, height: 56)
                    .background(Color.appBlue.opacity(0.12), in: RoundedRectangle(cornerRadius: 16))
                VStack(alignment: .leading, spacing: 5) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text(subtitle)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if !tag.isEmpty {
                    Text(tag)
                        .font(.caption.bold())
                        .foregroundStyle(.orange)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(.orange.opacity(0.12), in: Capsule())
                }
                Image(systemName: "chevron.right")
                    .foregroundStyle(.secondary)
            }
            .padding()
            .background(.white, in: RoundedRectangle(cornerRadius: 18))
            .overlay {
                RoundedRectangle(cornerRadius: 18).stroke(.black.opacity(0.10))
            }
        }
        .buttonStyle(.plain)
    }
}

struct DividerWithText: View {
    var text: String

    var body: some View {
        HStack {
            Rectangle().fill(.black.opacity(0.12)).frame(height: 1)
            Text(text).foregroundStyle(.secondary)
            Rectangle().fill(.black.opacity(0.12)).frame(height: 1)
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
            Rectangle().fill(.black.opacity(0.12)).frame(height: 1)
        }
    }
}
