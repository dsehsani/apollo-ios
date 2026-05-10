//
//  OnboardingApolloHeader.swift
//  Apollo
//
//  Apollo wordmark row shown at the top of onboarding screens 2 and 3.
//  Figma: Frame 45 at x=16, y=65, w=116, h=40.
//

import SwiftUI

struct OnboardingApolloHeader: View {
    var body: some View {
        HStack {
            Image("ApolloWordmark")
                .resizable()
                .scaledToFit()
                .frame(width: 116, height: 40)
            Spacer()
        }
        .padding(.horizontal, 16)
    }
}
