//
//  YesterdayEmptyView.swift
//  Apollo
//

import SwiftUI

struct YesterdayEmptyView: View {
    var body: some View {
        VStack {
            Spacer(minLength: 0)
            Text("Nothing from yesterday.")
                .font(.goudyItalic(18))
                .foregroundStyle(Color.apolloMuted)
                .multilineTextAlignment(.center)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    YesterdayEmptyView()
        .background(Color.apolloBackground)
}
