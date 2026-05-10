//
//  MemoriesView.swift
//  Apollo
//
//  Memories / Calendar screen (PRD §11).
//  Pushed from ProfileView when the user taps the calendar icon.
//

import Kingfisher
import SwiftUI

struct MemoriesView: View {

    @State private var viewModel: MemoriesViewModel
    @State private var photoViewerDay: MemoryDay?

    // Pre-computed UTC "today" components so every tile doesn't hit the clock.
    private let todayComponents: DateComponents = {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        return cal.dateComponents([.year, .month, .day], from: Date())
    }()

    init(userID: UUID, repository: any MemoriesRepositoryProtocol) {
        _viewModel = State(initialValue: MemoriesViewModel(userID: userID, repository: repository))
    }

    var body: some View {
        ZStack(alignment: .top) {
            Color.apolloBackground.ignoresSafeArea()

            switch viewModel.phase {
            case .loading:
                loadingContent
            case .loaded:
                loadedContent
            case .error(let message):
                errorContent(message: message)
            }
        }
        .navigationTitle("Memories")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Memories")
                    .font(.goudyRegular(24))
                    .foregroundStyle(Color.apolloPrimaryText)
            }
        }
        .toolbarBackground(Color.apolloBackground, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .task {
            await viewModel.loadInitial()
            Analytics.track(.memoriesOpened, [
                "total_post_days": viewModel.months.values.map(\.days.count).reduce(0, +),
                "months_of_history": viewModel.months.count
            ])
        }
        .fullScreenCover(item: $photoViewerDay) { day in
            FullScreenPhotoViewer(
                post: bridgedPost(from: day),
                startingIndex: 0,
                onClose: { photoViewerDay = nil }
            )
        }
    }

    // MARK: - Loaded content

    private var loadedContent: some View {
        ScrollView {
            LazyVStack(spacing: 0, pinnedViews: []) {
                ForEach(Array(viewModel.months.enumerated()), id: \.element.id) { idx, month in
                    MonthSectionView(
                        month: month,
                        todayComponents: todayComponents,
                        onTileTap: { day in
                            Analytics.track(.calendarTileTapped, [
                                "date": formattedDate(day.date),
                                "months_ago": idx
                            ])
                            photoViewerDay = day
                        }
                    )
                    .padding(.top, idx == 0 ? 24 : 32)
                    .padding(.bottom, 8)
                    .onAppear {
                        Task { await viewModel.loadOlderIfNeeded(currentMonthIndex: idx) }
                    }
                }

                if viewModel.isLoadingOlder {
                    ProgressView()
                        .tint(Color.apolloCaption)
                        .padding(.vertical, 24)
                }

                Spacer(minLength: 48)
            }
        }
        .scrollIndicators(.hidden)
    }

    // MARK: - Loading skeleton

    private var loadingContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // Skeleton month header
                HStack(spacing: 8) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.apolloSkeleton)
                        .frame(width: 80, height: 26)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.apolloSkeleton)
                        .frame(width: 60, height: 26)
                }
                .padding(.horizontal, 16)
                .padding(.top, 24)
                .padding(.bottom, 12)

                // Skeleton weekday row
                HStack(spacing: 0) {
                    ForEach(0..<7, id: \.self) { _ in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.apolloSkeleton)
                            .frame(height: 10)
                            .frame(maxWidth: .infinity)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 8)

                // Skeleton grid
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 2), count: 7), spacing: 2) {
                    ForEach(0..<35, id: \.self) { _ in
                        Color.apolloSkeleton
                            .aspectRatio(1, contentMode: .fit)
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    }
                }
                .padding(.horizontal, 16)
            }
        }
        .scrollIndicators(.hidden)
    }

    // MARK: - Error

    private func errorContent(message: String) -> some View {
        VStack(spacing: 20) {
            Spacer()
            Text(message)
                .font(.sfPro(15))
                .foregroundStyle(Color.apolloCaption)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Button("Try again") {
                Task { await viewModel.loadInitial() }
            }
            .font(.sfPro(15, weight: .semibold))
            .foregroundStyle(Color.apolloText)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Post bridge

    /// Bridges a MemoryDay into a Post so FullScreenPhotoViewer can display it.
    private func bridgedPost(from day: MemoryDay) -> Post {
        let towerSlots: [PhotoSlot] = day.towerPhotoURLs.enumerated().map { idx, url in
            PhotoSlot(id: UUID(), url: url, index: idx + 1)
        }
        return Post(
            id: day.postID ?? UUID(),
            user: PostUser(id: UUID(), username: "", avatarURL: nil, streak: 0),
            createdAt: day.date,
            caption: day.caption,
            photoCount: 1 + day.towerPhotoURLs.count,
            mainPhotoURL: day.mainPhotoURL,
            towerPhotos: towerSlots,
            winsCount: day.winCount,
            reactions: [],
            commentCount: 0,
            currentUserReaction: nil
        )
    }

    // MARK: - Helpers

    private func formattedDate(_ date: Date) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        fmt.timeZone = TimeZone(identifier: "UTC")!
        return fmt.string(from: date)
    }
}

// MARK: - MemoryMonth collection helper

private extension Collection where Element == MemoryMonth {
    var values: [MemoryMonth] { Array(self) }
}

#Preview {
    NavigationStack {
        MemoriesView(
            userID: UUID(),
            repository: MockMemoriesRepository()
        )
    }
    .preferredColorScheme(.dark)
}
