//
//  EmojiPickerSheet.swift
//  Apollo
//
//  Lets the user pick any custom emoji. iOS doesn't expose a way to force the emoji
//  keyboard, so we present a focussed text field and guide the user to tap the globe
//  key. The first emoji scalar found in the typed text is extracted and returned.
//

import SwiftUI

struct EmojiPickerSheet: View {
    var onSelect: (String) -> Void
    var onDismiss: () -> Void

    @State private var inputText = ""
    @FocusState private var isFieldFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            dragPill

            Spacer(minLength: 0)

            VStack(spacing: 16) {
                Text("Choose any emoji")
                    .font(.sfPro(16, weight: .medium))
                    .foregroundStyle(Color.apolloPrimaryText)

                Text("Tap the 🌐 key on your keyboard to open the emoji panel, then pick one.")
                    .font(.sfPro(13))
                    .foregroundStyle(Color.apolloReactorMuted)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                TextField("", text: $inputText)
                    .font(.system(size: 32))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(Color.apolloSurface)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal, 32)
                    .focused($isFieldFocused)
                    .onChange(of: inputText) { _, newValue in
                        if let emoji = extractFirstEmoji(from: newValue) {
                            onSelect(emoji)
                        }
                    }
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.apolloBackground)
        .onAppear {
            isFieldFocused = true
        }
    }

    private var dragPill: some View {
        HStack {
            Spacer()
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.sfPro(12, weight: .medium))
                    .foregroundStyle(Color.apolloReactorMuted)
                    .frame(width: 20, height: 20)
                    .background(Circle().fill(Color.apolloSurface))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close")
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
    }

    /// Returns the first emoji-presentation scalar as a String, or nil if none found.
    private func extractFirstEmoji(from text: String) -> String? {
        for scalar in text.unicodeScalars {
            let props = scalar.properties
            if props.isEmojiPresentation || (props.isEmoji && scalar.value > 127) {
                // Compose with variation selector 16 to ensure emoji presentation.
                var cluster = String(scalar)
                if !props.isEmojiPresentation {
                    cluster += "\u{FE0F}"
                }
                return cluster
            }
        }
        return nil
    }
}

#Preview {
    EmojiPickerSheet(onSelect: { _ in }, onDismiss: {})
        .preferredColorScheme(.dark)
}
