import SwiftUI

enum ArcadeTheme {
    static let background = Color(red: 0.055, green: 0.067, blue: 0.063)
    static let surface = Color(red: 0.10, green: 0.118, blue: 0.11)
    static let lime = Color(red: 0.81, green: 0.96, blue: 0.43)
    static let muted = Color(red: 0.59, green: 0.64, blue: 0.60)
    static let line = Color.white.opacity(0.09)
    static let colors: [Color] = [lime, Color(red: 0.72, green: 0.66, blue: 0.98), Color(red: 0.98, green: 0.71, blue: 0.45)]
}

struct PrimaryButton: View {
    let title: String
    let symbol: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: symbol)
                .font(.system(.headline, design: .rounded))
                .frame(maxWidth: .infinity, minHeight: 54)
                .foregroundStyle(ArcadeTheme.background)
                .background(ArcadeTheme.lime, in: RoundedRectangle(cornerRadius: 18))
        }
        .buttonStyle(.plain)
    }
}

struct BrandHeader: View {
    var body: some View {
        HStack(spacing: 9) {
            Image(systemName: "gamecontroller.fill")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(ArcadeTheme.lime)
            Text("HTML ARCADE")
                .font(.system(size: 12, weight: .heavy, design: .rounded))
                .tracking(2)
            Spacer()
            Circle().fill(ArcadeTheme.lime).frame(width: 6, height: 6)
            Text("PRESS PLAY")
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .tracking(1)
                .foregroundStyle(ArcadeTheme.muted)
        }
        .padding(.top, 16)
        .padding(.bottom, 20)
        .accessibilityElement(children: .combine)
    }
}
