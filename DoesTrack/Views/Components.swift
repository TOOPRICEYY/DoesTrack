import SwiftUI
import UIKit

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

extension Color {
    /// Single source of truth for the replica palette. The per-file
    /// `private let` aliases below each view file point here.
    static let appBackground = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.07, green: 0.09, blue: 0.13, alpha: 1)
            : UIColor(red: 0.93, green: 0.95, blue: 0.99, alpha: 1)
    })
    /// Card/surface color: white in light mode, dark slate in dark mode.
    static let appSurface = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.14, green: 0.16, blue: 0.22, alpha: 1)
            : .white
    })
    static let appBlue = Color(red: 0.05, green: 0.50, blue: 1.0)
}
