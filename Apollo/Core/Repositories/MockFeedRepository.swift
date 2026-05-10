//
//  MockFeedRepository.swift
//  Apollo
//
//  In-memory fixtures used while the real Supabase schema is being built. Provides
//  realistic data shaped exactly like the PRD describes plus toggleable forced states
//  for previews (.empty / .partial / .yesterdayEmpty / .error).
//

import Foundation

final class MockFeedRepository: FeedRepository, @unchecked Sendable {

    enum ForcedState: Sendable {
        case loaded
        case empty
        case partial
        case yesterdayEmpty
        case error
    }

    let currentUserID: UUID
    private let forced: ForcedState
    private let lock = NSLock()
    private var todayPosts: [Post]
    private var yesterdayPosts: [Post]

    init(forceState: ForcedState = .loaded) {
        self.forced = forceState
        let me = MockFeedRepository.me
        self.currentUserID = me.id

        switch forceState {
        case .loaded:
            self.todayPosts = MockFeedRepository.makeTodayPosts(currentUser: me)
            self.yesterdayPosts = MockFeedRepository.makeYesterdayPosts(currentUser: me)
        case .empty:
            self.todayPosts = []
            self.yesterdayPosts = []
        case .partial:
            self.todayPosts = [MockFeedRepository.makeOwnPost(currentUser: me)]
            self.yesterdayPosts = []
        case .yesterdayEmpty:
            self.todayPosts = MockFeedRepository.makeTodayPosts(currentUser: me)
            self.yesterdayPosts = []
        case .error:
            self.todayPosts = []
            self.yesterdayPosts = []
        }
    }

    // MARK: - FeedRepository

    func fetchFeed(tab: FeedTab, cursor: FeedCursor?, limit: Int) async throws -> FeedPage {
        try await Task.sleep(nanoseconds: 350_000_000)
        if forced == .error {
            throw FeedRepositoryError.network
        }

        let source = lock.withLock { tab == .now ? todayPosts : yesterdayPosts }
        let sorted = source.sorted { $0.createdAt > $1.createdAt }
        let filtered: [Post]
        if let cursor {
            filtered = sorted.filter {
                $0.createdAt < cursor.createdAt
                    || ($0.createdAt == cursor.createdAt && $0.id != cursor.id)
            }
        } else {
            filtered = sorted
        }

        let page = Array(filtered.prefix(limit))
        let nextCursor: FeedCursor?
        if filtered.count > limit, let last = page.last {
            nextCursor = FeedCursor(createdAt: last.createdAt, id: last.id)
        } else {
            nextCursor = nil
        }

        let ownPostExists = sorted.contains(where: { $0.user.id == currentUserID })
        return FeedPage(
            posts: page,
            nextCursor: nextCursor,
            hasMore: nextCursor != nil,
            ownPostExists: ownPostExists
        )
    }

    func dailyQuote() async throws -> Quote {
        try await Task.sleep(nanoseconds: 80_000_000)
        let pool: [String] = [
            "Small wins, every day, become a life.",
            "Show up — that's the whole game.",
            "The streak is the strategy.",
            "Be the friend who keeps going.",
            "Today is one rep."
        ]
        let day = Calendar.current.ordinality(of: .day, in: .year, for: Date()) ?? 0
        let text = pool[day % pool.count]
        return Quote(text: text, date: Calendar.current.startOfDay(for: Date()))
    }

    func addReaction(postID: UUID, emoji: String) async throws {
        try await Task.sleep(nanoseconds: 250_000_000)
        lock.withLock {
            mutate(postID: postID) { post in
                post.reactions.removeAll { $0.userID == currentUserID }
                post.reactions.append(
                    Reaction(
                        id: UUID(),
                        postID: postID,
                        userID: currentUserID,
                        username: MockFeedRepository.me.username,
                        avatarURL: MockFeedRepository.me.avatarURL,
                        emoji: emoji,
                        createdAt: Date()
                    )
                )
                post.currentUserReaction = emoji
            }
        }
    }

    func removeReaction(postID: UUID) async throws {
        try await Task.sleep(nanoseconds: 200_000_000)
        lock.withLock {
            mutate(postID: postID) { post in
                post.reactions.removeAll { $0.userID == currentUserID }
                post.currentUserReaction = nil
            }
        }
    }

    func fetchReactionsBreakdown(postID: UUID) async throws -> [Reaction] {
        try await Task.sleep(nanoseconds: 150_000_000)
        return lock.withLock {
            (todayPosts + yesterdayPosts).first(where: { $0.id == postID })?.reactions ?? []
        }
    }

    func fetchReactionSummaries(forPostIDs postIDs: [UUID]) async throws -> [PostReactionSummary] {
        try await Task.sleep(nanoseconds: 80_000_000)
        let allPosts = lock.withLock { todayPosts + yesterdayPosts }
        return postIDs.compactMap { id in
            guard let post = allPosts.first(where: { $0.id == id }) else { return nil }
            let counts = Dictionary(grouping: post.reactions, by: { $0.emoji }).mapValues { $0.count }
            guard !counts.isEmpty else { return nil }
            return PostReactionSummary(
                postID: id,
                countsByEmoji: counts,
                currentUserEmoji: post.currentUserReaction
                    ?? post.reactions.first(where: { $0.userID == currentUserID })?.emoji
            )
        }
    }

    func deletePost(postID: UUID) async throws {
        try await Task.sleep(nanoseconds: 200_000_000)
        lock.withLock {
            todayPosts.removeAll { $0.id == postID }
            yesterdayPosts.removeAll { $0.id == postID }
        }
    }

    func reportPost(postID: UUID, reason: String) async throws {
        try await Task.sleep(nanoseconds: 200_000_000)
    }

    func reactionUpdatesStream() -> AsyncStream<ReactionUpdate> {
        AsyncStream { continuation in
            let task = Task { [weak self] in
                try? await Task.sleep(nanoseconds: 6_000_000_000)
                guard let self, !Task.isCancelled else {
                    continuation.finish()
                    return
                }
                // Simulate a remote user reacting to the first loaded post.
                let targetID = lock.withLock {
                    todayPosts.first(where: { $0.user.id != currentUserID })?.id
                }
                if let targetID {
                    let newReaction = Reaction(
                        id: UUID(),
                        postID: targetID,
                        userID: MockFeedRepository.friends[4].id,
                        username: MockFeedRepository.friends[4].username,
                        avatarURL: MockFeedRepository.friends[4].avatarURL,
                        emoji: "🦾",
                        createdAt: Date()
                    )
                    continuation.yield(.added(newReaction))
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    func newPostsStream(tab: FeedTab) -> AsyncStream<Post> {
        AsyncStream { continuation in
            let task = Task { [weak self] in
                try? await Task.sleep(nanoseconds: 12_000_000_000)
                guard let self, !Task.isCancelled else {
                    continuation.finish()
                    return
                }
                if tab == .now, self.forced == .loaded {
                    let injected = MockFeedRepository.makeIncomingPost()
                    self.lock.withLock {
                        self.todayPosts.insert(injected, at: 0)
                    }
                    continuation.yield(injected)
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    // MARK: - Mutation helper

    private func mutate(postID: UUID, transform: (inout Post) -> Void) {
        if let idx = todayPosts.firstIndex(where: { $0.id == postID }) {
            transform(&todayPosts[idx])
        } else if let idx = yesterdayPosts.firstIndex(where: { $0.id == postID }) {
            transform(&yesterdayPosts[idx])
        }
    }

    // MARK: - Fixtures

    static let me = PostUser(
        id: UUID(uuidString: "00000000-0000-0000-0000-0000000000aa")!,
        username: "darius",
        avatarURL: URL(string: "https://images.unsplash.com/photo-1502685104226-ee32379fefbe?w=400"),
        streak: 12
    )

    private static let friends: [PostUser] = [
        PostUser(
            id: UUID(uuidString: "00000000-0000-0000-0000-0000000000b1")!,
            username: "jayden",
            avatarURL: URL(string: "https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?w=400"),
            streak: 28
        ),
        PostUser(
            id: UUID(uuidString: "00000000-0000-0000-0000-0000000000b2")!,
            username: "rildy",
            avatarURL: URL(string: "https://images.unsplash.com/photo-1529626455594-4ff0802cfb7e?w=400"),
            streak: 7
        ),
        PostUser(
            id: UUID(uuidString: "00000000-0000-0000-0000-0000000000b3")!,
            username: "mira",
            avatarURL: URL(string: "https://images.unsplash.com/photo-1544005313-94ddf0286df2?w=400"),
            streak: 41
        ),
        PostUser(
            id: UUID(uuidString: "00000000-0000-0000-0000-0000000000b4")!,
            username: "leo",
            avatarURL: URL(string: "https://images.unsplash.com/photo-1527980965255-d3b416303d12?w=400"),
            streak: 3
        ),
        PostUser(
            id: UUID(uuidString: "00000000-0000-0000-0000-0000000000b5")!,
            username: "apollo",
            avatarURL: URL(string: "https://images.unsplash.com/photo-1444703686981-a3abbc4d4fe3?w=400"),
            streak: 88
        ),
    ]

    private static func photo(_ raw: String) -> URL? {
        URL(string: raw)
    }

    private static func slots(_ urls: [String]) -> [PhotoSlot] {
        urls.enumerated().map { idx, raw in
            PhotoSlot(id: UUID(), url: photo(raw), index: idx)
        }
    }

    /// Build tower slots (index 1…) with optional per-slot captions. Pass fewer captions
    /// than urls to leave trailing slots without a caption.
    private static func slotsWithCaptions(_ urls: [String], captions: [String?]) -> [PhotoSlot] {
        urls.enumerated().map { idx, raw in
            let cap = captions.indices.contains(idx) ? captions[idx] : nil
            return PhotoSlot(id: UUID(), url: photo(raw), index: idx + 1, caption: cap)
        }
    }

    // Branch: multi-line per-photo caption stack (own post)
    private static func makeOwnPost(currentUser: PostUser) -> Post {
        let now = Date()
        return Post(
            id: UUID(uuidString: "11111111-1111-1111-1111-1111111111aa")!,
            user: currentUser,
            createdAt: now.addingTimeInterval(-30 * 60),
            caption: "",
            mainPhotoCaption: "Morning run before the sun got mean 🏃",
            photoCount: 2,
            mainPhotoURL: photo("https://images.unsplash.com/photo-1546484959-f9a381d1330d?w=1080"),
            towerPhotos: slotsWithCaptions(
                ["https://images.unsplash.com/photo-1503342217505-b0a15ec3261c?w=1080",
                 "https://images.unsplash.com/photo-1489824904134-891ab64532f1?w=1080"],
                captions: ["Meal prepped for the week", "Hit the gym after work 💪"]
            ),
            winsCount: 2,
            reactions: [],
            commentCount: 0,
            currentUserReaction: nil
        )
    }

    private static func makeTodayPosts(currentUser: PostUser) -> [Post] {
        let now = Date()
        let cal = Calendar.current
        func at(_ hour: Int, _ minute: Int) -> Date {
            cal.date(bySettingHour: hour, minute: minute, second: 0, of: now) ?? now
        }

        return [
            // Branch: multi-line per-photo caption stack (4 photos, 4 captions)
            Post(
                id: UUID(uuidString: "22222222-0000-0000-0000-000000000001")!,
                user: friends[0],
                createdAt: at(6, 30),
                caption: "",
                mainPhotoCaption: "4 miles in, sunrise out 🌅",
                photoCount: 4,
                mainPhotoURL: photo("https://images.unsplash.com/photo-1486218119243-13883505764c?w=1080"),
                towerPhotos: slotsWithCaptions(
                    ["https://images.unsplash.com/photo-1530549387789-4c1017266635?w=1080",
                     "https://images.unsplash.com/photo-1502082553048-f009c37129b9?w=1080",
                     "https://images.unsplash.com/photo-1469474968028-56623f02e42e?w=1080"],
                    captions: ["Ice bath after", "Meal prepped for the day", nil]
                ),
                winsCount: 4,
                reactions: [],
                commentCount: 0,
                currentUserReaction: nil
            ),
            // Branch: single per-photo caption
            Post(
                id: UUID(uuidString: "22222222-0000-0000-0000-000000000002")!,
                user: friends[2],
                createdAt: at(8, 15),
                caption: "",
                mainPhotoCaption: "Shipped the redesign. Two months of iteration. Worth it.",
                photoCount: 1,
                mainPhotoURL: photo("https://images.unsplash.com/photo-1517048676732-d65bc937f952?w=1080"),
                towerPhotos: [],
                winsCount: 1,
                reactions: [
                    Reaction(id: UUID(), postID: UUID(), userID: friends[0].id, username: friends[0].username, avatarURL: friends[0].avatarURL, emoji: "👑", createdAt: at(8, 16)),
                ],
                commentCount: 2,
                currentUserReaction: nil
            ),
            // Branch: no captions at all (caption area hidden)
            Post(
                id: UUID(uuidString: "22222222-0000-0000-0000-000000000003")!,
                user: currentUser,
                createdAt: at(9, 05),
                caption: "",
                photoCount: 2,
                mainPhotoURL: photo("https://images.unsplash.com/photo-1554415707-6e8cfc93fe23?w=1080"),
                towerPhotos: slots([
                    "https://images.unsplash.com/photo-1512314889357-e157c22f938d?w=1080"
                ]),
                winsCount: 2,
                reactions: [
                    Reaction(id: UUID(), postID: UUID(), userID: friends[1].id, username: friends[1].username, avatarURL: friends[1].avatarURL, emoji: "❤️", createdAt: at(9, 7)),
                ],
                commentCount: 1,
                currentUserReaction: nil
            ),
            // Branch: partial per-photo captions (some photos captioned, some not)
            Post(
                id: UUID(uuidString: "22222222-0000-0000-0000-000000000004")!,
                user: friends[1],
                createdAt: at(10, 22),
                caption: "",
                mainPhotoCaption: "Finally cooked something I'd serve to a friend",
                photoCount: 3,
                mainPhotoURL: photo("https://images.unsplash.com/photo-1473093295043-cdd812d0e601?w=1080"),
                towerPhotos: slotsWithCaptions(
                    ["https://images.unsplash.com/photo-1551183053-bf91a1d81141?w=1080",
                     "https://images.unsplash.com/photo-1525755662778-989d0524087e?w=1080"],
                    captions: [nil, "Garlic prawn pasta 🍤"]
                ),
                winsCount: 3,
                reactions: [],
                commentCount: 0,
                currentUserReaction: nil
            ),
            // Branch: legacy post.caption fallback (no per-photo captions)
            Post(
                id: UUID(uuidString: "22222222-0000-0000-0000-000000000005")!,
                user: friends[3],
                createdAt: at(11, 48),
                caption: "Read 30 pages before lunch. Slow win is still a win.",
                photoCount: 1,
                mainPhotoURL: photo("https://images.unsplash.com/photo-1457369804613-52c61a468e7d?w=1080"),
                towerPhotos: [],
                winsCount: 1,
                reactions: [
                    Reaction(id: UUID(), postID: UUID(), userID: friends[2].id, username: friends[2].username, avatarURL: friends[2].avatarURL, emoji: "❤️", createdAt: at(11, 50)),
                    Reaction(id: UUID(), postID: UUID(), userID: friends[0].id, username: friends[0].username, avatarURL: friends[0].avatarURL, emoji: "❤️", createdAt: at(11, 51)),
                ],
                commentCount: 0,
                currentUserReaction: nil
            ),
            // Branch: no caption at all (completely empty — action buttons full-width)
            Post(
                id: UUID(uuidString: "22222222-0000-0000-0000-000000000006")!,
                user: friends[4],
                createdAt: at(7, 02),
                caption: "",
                photoCount: 1,
                mainPhotoURL: photo("https://images.unsplash.com/photo-1505693416388-ac5ce068fe85?w=1080"),
                towerPhotos: [],
                winsCount: 1,
                reactions: [
                    Reaction(id: UUID(), postID: UUID(), userID: friends[0].id, username: friends[0].username, avatarURL: friends[0].avatarURL, emoji: "🔥", createdAt: at(7, 4)),
                    Reaction(id: UUID(), postID: UUID(), userID: friends[3].id, username: friends[3].username, avatarURL: friends[3].avatarURL, emoji: "🔥", createdAt: at(7, 5)),
                    Reaction(id: UUID(), postID: UUID(), userID: friends[1].id, username: friends[1].username, avatarURL: friends[1].avatarURL, emoji: "👑", createdAt: at(7, 6)),
                    Reaction(id: UUID(), postID: UUID(), userID: friends[2].id, username: friends[2].username, avatarURL: friends[2].avatarURL, emoji: "❤️", createdAt: at(7, 7)),
                ],
                commentCount: 8,
                currentUserReaction: "🔥"
            ),
        ]
    }

    private static func makeYesterdayPosts(currentUser: PostUser) -> [Post] {
        let cal = Calendar.current
        let yesterday = cal.date(byAdding: .day, value: -1, to: Date()) ?? Date()
        func at(_ hour: Int, _ minute: Int) -> Date {
            cal.date(bySettingHour: hour, minute: minute, second: 0, of: yesterday) ?? yesterday
        }

        return [
            Post(
                id: UUID(uuidString: "33333333-0000-0000-0000-000000000001")!,
                user: friends[0],
                createdAt: at(20, 14),
                caption: "",
                mainPhotoCaption: "Closed the gym. PR on bench.",
                photoCount: 2,
                mainPhotoURL: photo("https://images.unsplash.com/photo-1517836357463-d25dfeac3438?w=1080"),
                towerPhotos: slotsWithCaptions(
                    ["https://images.unsplash.com/photo-1534438327276-14e5300c3a48?w=1080"],
                    captions: ["Bedtime fully earned 💤"]
                ),
                winsCount: 2,
                reactions: [
                    Reaction(id: UUID(), postID: UUID(), userID: friends[2].id, username: friends[2].username, avatarURL: friends[2].avatarURL, emoji: "👑", createdAt: at(20, 20))
                ],
                commentCount: 3,
                currentUserReaction: nil
            ),
            Post(
                id: UUID(uuidString: "33333333-0000-0000-0000-000000000002")!,
                user: friends[2],
                createdAt: at(18, 47),
                caption: "",
                mainPhotoCaption: "Walk + sunset + zero phone for an hour.",
                photoCount: 1,
                mainPhotoURL: photo("https://images.unsplash.com/photo-1500530855697-b586d89ba3ee?w=1080"),
                towerPhotos: [],
                winsCount: 1,
                reactions: [],
                commentCount: 0,
                currentUserReaction: nil
            ),
        ]
    }

    private static func makeIncomingPost() -> Post {
        Post(
            id: UUID(),
            user: friends[3],
            createdAt: Date(),
            caption: "",
            mainPhotoCaption: "Just now: pulled off my first proper handstand.",
            photoCount: 1,
            mainPhotoURL: photo("https://images.unsplash.com/photo-1518611012118-696072aa579a?w=1080"),
            towerPhotos: [],
            winsCount: 1,
            reactions: [],
            commentCount: 0,
            currentUserReaction: nil
        )
    }
}

private extension NSLock {
    func withLock<T>(_ body: () -> T) -> T {
        lock(); defer { unlock() }
        return body()
    }
}
