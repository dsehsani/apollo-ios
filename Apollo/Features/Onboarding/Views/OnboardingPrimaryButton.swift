//
//  OnboardingPrimaryButton.swift
//  Apollo
//
//  Shared #f3f3f3 pill CTA button used on all 3 onboarding screens.
//  Figma: 370×44, cornerRadius 10, x=16, top=753.
//

import SwiftUI

struct OnboardingPrimaryButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.sfPro(20, weight: .medium))
                .foregroundStyle(Color(red: 0x08 / 255, green: 0x08 / 255, blue: 0x08 / 255))
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(Color.apolloPrimaryText, in: RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 16)
    }
}

#Preview {
    ZStack {
        Color.apolloBackground.ignoresSafeArea()
        OnboardingPrimaryButton(title: "Get Started") {}
    }
}
