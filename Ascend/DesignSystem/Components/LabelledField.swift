import SwiftUI
import AscendDomain

/// A text input with a persistent label and a focus state.
///
/// Three rules from *UI Design Principles* (Filipiuk), all of which the app was breaking:
///
/// - **Keep the label visible** (p138). The fields here were placeholder-only. A placeholder
///   disappears the moment someone starts typing, so a person who pauses mid-form has nothing
///   left telling them what they were filling in.
/// - **A field should look like a field** (p140). A filled rectangle with no border reads as a
///   button, which is a confusing thing to put in a form. Inputs keep a border even though every
///   panel in the app lost theirs.
/// - **Design every state** (p155). There was no focus state at all — tapping a field changed
///   nothing, so nothing confirmed the tap had landed. Focus now moves the border to the accent
///   colour.
///
/// "(optional)" is spelled out rather than marking required fields with an asterisk, per p160:
/// asterisks are not obvious to everyone, and the useful information is which fields you can
/// skip.
struct LabelledField: View {
    let label: String
    var placeholder: String = ""
    var help: String?
    var isOptional: Bool = false
    var lineLimit: ClosedRange<Int>?
    @Binding var text: String

    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.xs) {
                Text(label)
                    .textStyle(TypeSize.caption, .semibold)
                    .foregroundStyle(Theme.Colors.secondaryText)
                if isOptional {
                    Text("(optional)")
                        .textStyle(TypeSize.micro, .regular)
                        .foregroundStyle(Theme.Colors.tertiaryText)
                }
            }

            Group {
                if let lineLimit {
                    TextField(placeholder, text: $text, axis: .vertical).lineLimit(lineLimit)
                } else {
                    TextField(placeholder, text: $text)
                }
            }
            .textFieldStyle(.plain)
            .focused($isFocused)
            .textStyle(TypeSize.body)
            .foregroundStyle(Theme.Colors.primaryText)
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.vertical, Theme.Spacing.md)
            .frame(minHeight: TapTarget.minimum)
            .background(Theme.Colors.surfaceRaised, in: .rect(cornerRadius: Theme.Radii.md))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radii.md)
                    .strokeBorder(isFocused ? Color(Palette.inputBorderFocused)
                                            : Color(Palette.inputBorder),
                                  lineWidth: isFocused ? 2 : 1)
            )
            .animation(.easeOut(duration: Timing.feedback), value: isFocused)

            if let help {
                Text(help)
                    .textStyle(TypeSize.micro, .regular)
                    .foregroundStyle(Theme.Colors.tertiaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
