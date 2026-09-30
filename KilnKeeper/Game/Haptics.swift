import UIKit

enum Haptics {
    /// Master switch, persisted. SettingsView toggles this.
    static var enabled: Bool {
        get { UserDefaults.standard.object(forKey: "kilnkeeper.haptics.enabled") as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: "kilnkeeper.haptics.enabled") }
    }

    static func light() {
        guard enabled else { return }
        DispatchQueue.main.async {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }
    }

    static func medium() {
        guard enabled else { return }
        DispatchQueue.main.async {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }
    }

    static func heavy() {
        guard enabled else { return }
        DispatchQueue.main.async {
            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        }
    }

    static func success() {
        guard enabled else { return }
        DispatchQueue.main.async {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
    }

    static func error() {
        guard enabled else { return }
        DispatchQueue.main.async {
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        }
    }

    static func selection() {
        guard enabled else { return }
        DispatchQueue.main.async {
            UISelectionFeedbackGenerator().selectionChanged()
        }
    }
}
