//
//  DayTileView.swift
//  Apollo
//
//  Single calendar day tile for the Memories screen (PRD §11 §4D).
//
//  States:
//    • Empty: apolloSkeleton (#141414) background, no content.
//    • Has post: featured photo fill, day number top-left, reaction badge bottom-left.
//    • Today: 1pt apolloPrimaryText border regardless of post state.
//

import Kingfisher
import SwiftUI

struct DayTileView: View {
    let dayNumber: Int
    let day: MemoryDay?       // nil → empty slot (day before month start)
    let isToday: Bool
    let onTap: (() -> Void)?

    var body: some View {
        ZStack(alignment: .topLeading) {
            background

            if let day, day.hasPost {
                dayNumberLabel(day.date)
                reactionBadge(count: day.reactionCount)
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .strokeBorder(Color.apolloPrimaryText, lineWidth: isToday ? 1 : 0)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            if let day, day.hasPost {
                onTap?()
            }
        }
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint(day?.hasPost == true ? "Double tap to view." : "")
        .accessibilityAddTraits(day?.hasPost == true ? .isButton : [])
    }

    // MARK: - Background

    @ViewBuilder
    private var background: some View {
        if let day, day.hasPost, let url = day.mainPhotoURL {
            KFImage(url)
                .resizable()
                .placeholder { Color.apolloSkeleton }
                .setProcessor(DownsamplingImageProcessor(size: CGSize(width: 200, height: 200)))
                .cacheOriginalImage()
                .scaledToFill()
                .clipped()
        } else {
            Color.apolloSkeleton
        }
    }

    // MARK: - Day number

    private func dayNumberLabel(_ date: Date) -> some View {
        // Show the day-of-month from the day's UTC date.
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        let d = cal.component(.day, from: date)
        return Text("\(d)")
            .font(.sfPro(10, weight: .semibold))
            .foregroundStyle(Color.apolloPrimaryText)
            .padding(4)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    // MARK: - Reaction badge

    private func reactionBadge(count: Int) -> some View {
        HStack(spacing: 2) {
            Image(systemName: "heart.fill")
                .font(.system(size: 8))
                .foregroundStyle(Color.apolloPrimaryText)
            Text("\(count)")
                .font(.sfPro(9))
                .foregroundStyle(Color.apolloPrimaryText)
        }
        .padding(.horizontal, 3)
        .padding(.vertical, 3)
        .background(Color.black.opacity(0.5))
        .clipShape(Capsule())
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
        .padding(3)
    }

    // MARK: - Accessibility

    private var accessibilityLabel: String {
        guard let day else { return "No post" }
        var utcCal = Calendar(identifier: .gregorian)
        utcCal.timeZone = TimeZone(identifier: "UTC")!
        let monthName = utcCal.monthSymbols[utcCal.component(.month, from: day.date) - 1]
        let dayNum = utcCal.component(.day, from: day.date)
        if day.hasPost {
            return "\(monthName) \(dayNum), \(day.reactionCount) reactions."
        } else {
            return "\(monthName) \(dayNum), no post."
        }
    }
}

// MARK: - Blank tile (filler before month start)

/// An invisible spacer tile used to align the first day of a month to its weekday column.
struct BlankTileView: View {
    var body: some View {
        Color.clear
            .aspectRatio(1, contentMode: .fit)
    }
}

#Preview {
    HStack(spacing: 2) {
        DayTileView(dayNumber: 5, day: nil, isToday: false, onTap: nil)
        DayTileView(
            dayNumber: 6,
            day: MemoryDay(
                id: UUID(), date: Date(), postID: UUID(),
                mainPhotoURL: nil, towerPhotoURLs: [],
                reactionCount: 12, winCount: 3, caption: "test"
            ),
            isToday: true,
            onTap: {}
        )
        DayTileView(dayNumber: 7, day: nil, isToday: false, onTap: nil)
    }
    .padding(16)
    .background(Color.apolloBackground)
    .preferredColorScheme(.dark)
}
