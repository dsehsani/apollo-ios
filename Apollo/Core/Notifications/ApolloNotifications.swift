//
//  ApolloNotifications.swift
//  Apollo
//
//  Shared Notification.Name constants for cross-module communication.
//

import Foundation

extension Notification.Name {
    static let apolloFeedShouldRefresh    = Notification.Name("apolloFeedShouldRefresh")
    static let apolloProfileShouldRefresh = Notification.Name("apolloProfileShouldRefresh")
}
