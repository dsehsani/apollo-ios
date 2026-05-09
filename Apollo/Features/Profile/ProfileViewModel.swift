//
//  ProfileViewModel.swift
//  Apollo
//
//  @Observable view model for ProfileView (PRD §06).
//

import Foundation
import Observation

@Observable
final class ProfileViewModel {

    enum Phase {
        case loading
        case loaded(ProfileUser, ProfilePost?)
        case error(String)
    }

    private(set) var phase: Phase = .loading
    var featuredPhotoIndex: Int = 0

    private let userID: UUID
    private let repository: any ProfileRepositoryProtocol

    init(userID: UUID, repository: any ProfileRepositoryProtocol = MockProfileRepository()) {
        self.userID = userID
        self.repository = repository
    }

    func load() async {
        phase = .loading
        do {
            let (user, post) = try await repository.fetchProfile(userID: userID)
            phase = .loaded(user, post)
        } catch {
            phase = .error("Couldn't load profile. Try again.")
        }
    }

    func refresh() async {
        do {
            let (user, post) = try await repository.fetchProfile(userID: userID)
            phase = .loaded(user, post)
        } catch {
            phase = .error("Couldn't load profile. Try again.")
        }
    }

    func setFeaturedPhoto(_ index: Int) {
        featuredPhotoIndex = index
    }
}
