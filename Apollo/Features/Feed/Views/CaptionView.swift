//
//  CaptionView.swift
//  Apollo
//

import SwiftUI

struct CaptionView: View {
    var caption: String
    var isExpanded: Bool
    var onTapMore: () -> Void

    @State private var isTruncated: Bool = false

    private let captionFont: Font = .sfPro(16)
    private let maxWidth: CGFloat = 215
    private let moreMaxWidth: CGFloat = 89

    var body: some View {
        VStack(alignment: .trailing, spacing: 4) {
            Text(caption)
                .font(captionFont)
                .foregroundStyle(Color.apolloCaption)
                .lineLimit(isExpanded ? nil : 2)
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: maxWidth, alignment: .trailing)
                .background(truncationProbe)

            if !isExpanded && isTruncated {
                Button(action: onTapMore) {
                    Text("tap to see more")
                        .font(.sfPro(12))
                        .foregroundStyle(Color.apolloTabInactive)
                        .multilineTextAlignment(.trailing)
                        .frame(maxWidth: moreMaxWidth, alignment: .trailing)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: maxWidth, alignment: .trailing)
    }

    private var truncationProbe: some View {
        GeometryReader { geo in
            Text(caption)
                .font(captionFont)
                .lineLimit(nil)
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: maxWidth, alignment: .trailing)
                .background(
                    GeometryReader { full in
                        Color.clear
                            .onAppear {
                                isTruncated = full.size.height > geo.size.height + 1
                            }
                            .onChange(of: full.size.height) { _, newValue in
                                isTruncated = newValue > geo.size.height + 1
                            }
                    }
                )
                .hidden()
        }
    }
}

#Preview {
    VStack(spacing: 24) {
        CaptionView(
            caption: "Short line.",
            isExpanded: false,
            onTapMore: {}
        )
        CaptionView(
            caption: "A much longer caption that absolutely should overflow two lines so the tap to see more affordance can render below the truncated body — testing the truncation probe.",
            isExpanded: false,
            onTapMore: {}
        )
    }
    .padding()
    .background(Color.apolloBackground)
    .preferredColorScheme(.dark)
}
