//
//  PostActionSheet.swift
//  Apollo
//
//  iOS confirmationDialog modeling the ··· action sheet for own vs others' posts.
//

import SwiftUI

enum PostActionSheetIntent: Identifiable, Hashable {
    case editOwn(Post)
    case shareStripOwn(Post)
    case deleteOwn(Post)
    case shareOthers(Post)
    case reportOthers(Post)

    var id: String {
        switch self {
        case .editOwn(let p): return "edit-\(p.id)"
        case .shareStripOwn(let p): return "share-strip-\(p.id)"
        case .deleteOwn(let p): return "delete-\(p.id)"
        case .shareOthers(let p): return "share-\(p.id)"
        case .reportOthers(let p): return "report-\(p.id)"
        }
    }
}

struct PostActionSheet: ViewModifier {
    var post: Post?
    var isOwnPost: Bool
    @Binding var isPresented: Bool
    var onIntent: (PostActionSheetIntent) -> Void

    func body(content: Content) -> some View {
        content.confirmationDialog(
            "Post options",
            isPresented: $isPresented,
            titleVisibility: .hidden
        ) {
            if let post {
                if isOwnPost {
                    Button("Edit post") { onIntent(.editOwn(post)) }
                    Button("Share strip") { onIntent(.shareStripOwn(post)) }
                    Button("Delete post", role: .destructive) {
                        onIntent(.deleteOwn(post))
                    }
                } else {
                    Button("Share post") { onIntent(.shareOthers(post)) }
                    Button("Report", role: .destructive) {
                        onIntent(.reportOthers(post))
                    }
                }
                Button("Cancel", role: .cancel) {}
            }
        }
    }
}

extension View {
    func postActionSheet(
        post: Post?,
        isOwnPost: Bool,
        isPresented: Binding<Bool>,
        onIntent: @escaping (PostActionSheetIntent) -> Void
    ) -> some View {
        modifier(PostActionSheet(post: post, isOwnPost: isOwnPost, isPresented: isPresented, onIntent: onIntent))
    }
}
