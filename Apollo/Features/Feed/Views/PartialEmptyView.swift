//
//  PartialEmptyView.swift
//  Apollo
//

import SwiftUI

struct PartialEmptyView: View {
    var body: some View {
        Text("Your friends haven't posted yet.")
            .font(.goudyItalic(16))
            .foregroundStyle(Color.apolloMuted)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 48)
    }
}

#Preview {
    PartialEmptyView()
        .background(Color.apolloBackground)
}
