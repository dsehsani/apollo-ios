//
//  ReportFlowPlaceholder.swift
//  Apollo
//
//  Placeholder for the Report Flow modal.
//

import SwiftUI

struct ReportFlowPlaceholder: View {
    var post: Post
    var onClose: () -> Void

    var body: some View {
        VStack {
            Spacer()
            Text("Report Flow")
                .font(.goudyItalic(20))
                .foregroundStyle(Color.apolloText)
            Spacer()
            Button("Close", action: onClose)
                .foregroundStyle(Color.apolloText)
                .padding()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.apolloBackground)
        .presentationDetents([.medium])
    }
}
