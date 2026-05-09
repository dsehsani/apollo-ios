//
//  WinInputField.swift
//  Apollo
//
//  Bottom pill input for win creation. Matches Figma node 12839-5931.
//
//  Layout:
//    [pill: 20pt leading | "Win." placeholder | Spacer | size badge pill | send button] 16pt trailing from pill edge
//
//  The size badge is tappable — cycles S → M → L → S.
//  Return key submits the win (calls onSubmit).
//

import SwiftUI

struct WinInputField: View {
    @Binding var text: String
    @Binding var size: WinSize
    let onSubmit: () -> Void

    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: 8) {
            pill
            sendButton
        }
        .padding(.horizontal, 16)
    }

    // MARK: - Pill

    private var pill: some View {
        HStack(spacing: 0) {
            TextField("Win.", text: $text)
                .font(.goudyItalic(20))
                .foregroundStyle(Color.apolloPrimaryText)
                .tint(Color.apolloPrimaryText)
                .submitLabel(.done)
                .focused($isFocused)
                .onSubmit(onSubmit)
                .padding(.leading, 20)
                .frame(maxWidth: .infinity, alignment: .leading)

            sizeBadge
                .padding(.trailing, 8)
        }
        .frame(height: 48)
        .background(Color.apolloSheetSurface)
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .stroke(Color.apolloWinInputBorder, lineWidth: 0.5)
        )
    }

    // MARK: - Size badge

    private var sizeBadge: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.12)) {
                size = size.next
            }
        } label: {
            Text(size.rawValue)
                .font(.goudyItalic(17))
                .foregroundStyle(Color.apolloPrimaryText)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Color.apolloBackground.opacity(0.6))
                .clipShape(Capsule())
                .frame(minWidth: 28, minHeight: 28)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Size: \(size.accessibilityLabel). Tap to change.")
    }

    // MARK: - Send button

    private var sendButton: some View {
        Button(action: onSubmit) {
            ZStack {
                Circle()
                    .fill(Color.apolloPrimaryText)
                    .frame(width: 30, height: 30)
                Image(systemName: "arrow.up")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.apolloBackground)
            }
        }
        .buttonStyle(.plain)
        .opacity(text.trimmingCharacters(in: .whitespaces).isEmpty ? 0.35 : 1)
        .animation(.easeInOut(duration: 0.15), value: text.isEmpty)
        .accessibilityLabel("Add win")
        .disabled(text.trimmingCharacters(in: .whitespaces).isEmpty)
    }
}

#Preview {
    @Previewable @State var text = ""
    @Previewable @State var size: WinSize = .m

    ZStack(alignment: .bottom) {
        Color.apolloBackground.ignoresSafeArea()
        WinInputField(text: $text, size: $size, onSubmit: {})
            .padding(.bottom, 16)
    }
    .preferredColorScheme(.dark)
}
