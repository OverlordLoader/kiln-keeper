import SwiftUI

/// "While you were away..." — summarizes pieces the kiln finished
/// during offline progress (capped at 8 hours).
struct AwaySummaryView: View {
    let summary: AwaySummary
    let onDismiss: () -> Void

    private var byColor: [(PieceColor, Int)] {
        let grouped = Dictionary(grouping: summary.pieces, by: { $0.color })
        return grouped.map { ($0.key, $0.value.count) }
            .sorted { $0.0.rarityTier > $1.0.rarityTier }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.07, green: 0.05, blue: 0.10).ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 18) {
                        Image(systemName: "moon.stars.fill")
                            .font(.system(size: 52))
                            .foregroundColor(Color(hex: 0xFFD60A))
                            .padding(.top, 24)
                        Text("While you were away…")
                            .font(.title2.bold())
                            .foregroundColor(.white)
                        Text("Your kiln kept firing\(summary.capped ? " (8-hour cap reached)" : "").")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.6))
                            .multilineTextAlignment(.center)

                        VStack(spacing: 10) {
                            ForEach(byColor, id: \.0) { color, count in
                                HStack {
                                    Circle()
                                        .fill(color.swiftUIColor)
                                        .frame(width: 28, height: 28)
                                        .overlay(Circle().stroke(Color.white.opacity(0.35), lineWidth: 1))
                                    Text("\(count)x \(color.displayName)")
                                        .font(.headline)
                                        .foregroundColor(.white)
                                    Spacer()
                                    Text(color.rarityName)
                                        .font(.caption.bold())
                                        .foregroundColor(color.rarityAccent)
                                }
                                .padding(.horizontal, 4)
                            }
                        }
                        .padding()
                        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 16))
                        .padding(.horizontal)

                        VStack(spacing: 4) {
                            Text("\(summary.pieces.count) pieces finished")
                                .font(.headline)
                                .foregroundColor(.white)
                            Text("Collect them from your shelves, then sell for coins in Pieces.")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.55))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 32)
                        }

                        Button {
                            SoundManager.shared.play(.win)
                            Haptics.success()
                            onDismiss()
                        } label: {
                            Text("Collect")
                                .font(.headline)
                                .foregroundColor(.black)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(Color(hex: 0xFFD60A), in: RoundedRectangle(cornerRadius: 14))
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 24)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
        }
        .tint(Color(hex: 0xFFD60A))
    }
}
