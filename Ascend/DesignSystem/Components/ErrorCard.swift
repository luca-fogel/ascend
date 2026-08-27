import SwiftUI
import AscendDomain

/// One error presenter for the whole app.
///
/// `AscendError` already carries its own title, symbol, message and whether retrying is honest,
/// so this view switches over nothing.
///
/// The visual treatment is the contrast flip from Refactoring UI p164: a dark tint of the hue as
/// the panel, with coloured text on top, rather than a saturated fill that would grab more
/// attention than most errors deserve. The accent bar across the top is p224.
///
/// The hue comes from `error.severity`: red for a real failure, amber for something the user just
/// needs to do or wait for. *UI Design Principles* p98 names these as distinct notification
/// colours, and rendering both in gold — as this did — makes an ineligible device look no more
/// serious than a goal that needs three more words.
struct ErrorCard: View {
    let error: AscendError
    var onRetry: (@MainActor () -> Void)?
    var onUseTemplate: (@MainActor () -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.sm) {
                Image(systemName: error.symbolName)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(accentColor.opacity(0.85))
                Text(error.title)
                    .textStyle(TypeSize.body, .semibold)
                    .foregroundStyle(Theme.Colors.primaryText)
            }
            if let message = error.errorDescription {
                // Left-aligned, not centred: it runs to more than three lines (p128).
                Text(message)
                    .textStyle(TypeSize.caption)
                    .foregroundStyle(Theme.Colors.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if error.isRetryable && onRetry != nil || error.allowsTemplateFallback && onUseTemplate != nil {
                HStack(spacing: Theme.Spacing.lg) {
                    // A retry is only offered when retrying could actually work; a button that
                    // always fails erodes trust faster than no button.
                    if error.isRetryable, let onRetry {
                        TertiaryButton(title: "Try again", action: onRetry)
                    }
                    if error.allowsTemplateFallback, let onUseTemplate {
                        TertiaryButton(title: "Use a template", action: onUseTemplate)
                    }
                }
            }
        }
        .card(.medium, accent: accentColor, surface: Theme.Colors.tint(ramp))
    }

    private var ramp: ColorRamp {
        error.severity == .error ? Palette.health : Palette.gold
    }

    private var accentColor: Color {
        error.severity == .error ? Theme.Colors.hp : Theme.Colors.gold
    }
}

/// The empty state.
///
/// "Don't overlook empty states" (p234): this is a user's first interaction with a feature, so it
/// gets a graphic, a left-aligned explanation, and an emphasised call to action rather than a
/// grey sentence apologising for having no data.
///
/// The icon sits inside a tinted container — "Everything has an intended size" (p208). An SF
/// Symbol blown up to 40pt for a hero slot reads chunky and under-detailed; keeping the glyph
/// near its drawn size and filling the space with a shape is the fix.
struct EmptyStateCard: View {
    var symbolName: String = "map"
    var title: String = "No quests yet"
    var message: String = "Add a goal and Ascend will break it into a roadmap you can actually start tomorrow."
    var actionTitle: String = "Create a goal"
    var onCreate: (@MainActor () -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.base) {
            IconBadge(systemName: symbolName)
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text(title)
                    .textStyle(TypeSize.headline, .semibold)
                    .foregroundStyle(Theme.Colors.primaryText)
                Text(message)
                    .textStyle(TypeSize.caption)
                    .foregroundStyle(Theme.Colors.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let onCreate {
                PrimaryButton(title: actionTitle, action: onCreate)
                    .padding(.top, Theme.Spacing.xs)
            }
        }
        .card(.medium, padding: Theme.Spacing.xl)
    }
}
