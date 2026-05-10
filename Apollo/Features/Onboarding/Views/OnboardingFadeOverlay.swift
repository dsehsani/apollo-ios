//
//  OnboardingFadeOverlay.swift
//  Apollo
//
//  Reusable bottom-up LinearGradient fade from transparent to apolloBackground.
//  Used on all three onboarding screens.
//

import SwiftUI

struct OnboardingFadeOverlay: View {
    var body: some View {
        LinearGradient(
            stops: [
                .init(color: Color.apolloBackground.opacity(0), location: 0),
                .init(color: Color.apolloBackground, location: 1)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .allowsHitTesting(false)
    }
}
