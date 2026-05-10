//
//  PhoneSignInButtonView.swift
//  Apollo
//
//  Outlined dark-pill button on the SignInView that navigates to PhoneEntryView.
//  1pt stroke apolloMuted, fill apolloBackground, SF Symbol phone.fill + label.
//

import SwiftUI

struct PhoneSignInButtonView: View {
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 10) {
                Image(systemName: "phone.fill")
                    .font(.system(size: 17))
                    .foregroundStyle(Color.apolloPrimaryText)

                Text("Continue with phone")
                    .font(.sfPro(17, weight: .medium))
                    .foregroundStyle(Color.apolloPrimaryText)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .background(Color.apolloBackground, in: RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.apolloMuted, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 16)
    }
}
