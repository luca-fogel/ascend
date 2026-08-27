import UIKit
import AscendDomain

/// Physical feedback for an action.
///
/// *UI Design Principles* (Filipiuk, p282): a microinteraction exists to confirm that something
/// the user did actually happened. Every completion in this app changed numbers on screen but
/// gave no acknowledgement at the moment of the tap — and on a phone, the fastest available
/// acknowledgement is not visual.
///
/// Scaled to the size of the event: a tap is light, a level-up is a success chime, a defeat is a
/// warning. Nothing here fires more than once per action, because feedback that fires constantly
/// stops being feedback.
enum Haptics {
    private static let light = UIImpactFeedbackGenerator(style: .light)
    private static let notice = UINotificationFeedbackGenerator()

    /// A step or habit completed.
    static func completion() {
        light.prepare()
        light.impactOccurred(intensity: 0.7)
    }

    /// A level-up, a milestone unlocking, or a boss falling.
    static func celebration() {
        notice.notificationOccurred(.success)
    }

    /// HP lost, or an action refused.
    static func setback() {
        notice.notificationOccurred(.warning)
    }

    /// The strongest signal in the app, reserved for the one event that undoes progress.
    static func defeat() {
        notice.notificationOccurred(.error)
    }

    /// Chooses the right feedback for a completion from what the engine reported, so a call site
    /// cannot pick the wrong one.
    static func forOutcome(_ outcome: CompletionOutcome) {
        if outcome.bossDefeated || !outcome.levelUps.isEmpty || outcome.unlockedMilestoneTitle != nil {
            celebration()
        } else {
            completion()
        }
    }
}
