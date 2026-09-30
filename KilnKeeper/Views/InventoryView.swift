import SwiftUI

/// The player's collection of fired pieces. Sell individually or all at
/// once for coins. Every row does something real — no dead UI.
struct InventoryView: View {
    @StateObject private var game = GameState.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.07, green: 0.05, blue: 0.10).ignoresSafeArea()
                if game.inventory.isEmpty {
                    emptyState
                } else {
                    List {
                        ForEach(game.inventory) { piece in
                            pieceRow(piece)
                        }
                    }
                    .scrollContentBackground(.hidden)
                }
            }
            .navigationTitle("Glass Pieces")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        SoundManager.shared.play(.click)
                        dismiss()
                    }
                    .foregroundColor(Color(hex: 0xFFD60A))
                }
                if !game.inventory.isEmpty {
                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            _ = game.sellAll()
                            SoundManager.shared.play(.win)
                            Haptics.success()
                        } label: {
                            Text("Sell all (\(game.inventoryValue)¢)")
                                .font(.subheadline.bold())
                                .foregroundColor(Color(hex: 0xFFD60A))
                        }
                    }
                }
            }
        }
        .tint(Color(hex: 0xFFD60A))
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "archivebox")
                .font(.system(size: 48))
                .foregroundColor(.white.opacity(0.3))
            Text("No pieces yet")
                .font(.headline)
                .foregroundColor(.white.opacity(0.7))
            Text("Tap a glowing finished piece on a shelf to collect it here.")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.5))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
    }

    private func pieceRow(_ piece: KilnPiece) -> some View {
        HStack(spacing: 12) {
            // Glass swatch: radial glow in the piece color.
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [piece.color.swiftUIColor, piece.color.swiftUIColor.opacity(0.25)],
                            center: .center, startRadius: 2, endRadius: 22)
                    )
                    .frame(width: 44, height: 44)
                Circle()
                    .stroke(Color.white.opacity(0.35), lineWidth: 1.5)
                    .frame(width: 44, height: 44)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(piece.title)
                    .font(.headline)
                    .foregroundColor(.white)
                Text(piece.color.rarityName)
                    .font(.caption.bold())
                    .foregroundColor(piece.color.rarityAccent)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(piece.color.rarityAccent.opacity(0.15), in: Capsule())
            }
            Spacer()
            Button {
                let value = game.sell(pieceID: piece.id)
                if value > 0 {
                    SoundManager.shared.play(.complete)
                    Haptics.medium()
                }
            } label: {
                Text("+\(piece.sellValue)¢")
                    .font(.subheadline.bold())
                    .foregroundColor(.black)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Color(hex: 0xFFD60A), in: Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
        .listRowBackground(Color.white.opacity(0.06))
    }
}
