//
//  UploadQueue.swift
//  Apollo
//
//  In-memory offline upload queue backed by NWPathMonitor.
//
//  When an upload fails because the device is offline, CameraViewModel
//  calls `enqueue` to hold the pending item silently. When the path
//  becomes satisfied the queue fires `onNetworkRestored` so the view
//  model can drain and retry each item.
//

import Foundation
import Network
import UIKit

final class UploadQueue: @unchecked Sendable {

    struct QueuedItem: Sendable {
        let image: UIImage
        let capturedAt: Date
        let winID: UUID?
        let privateNote: String?
    }

    /// Called on the main actor when the network path becomes satisfied
    /// and the queue is non-empty.
    var onNetworkRestored: (@Sendable ([QueuedItem]) -> Void)?

    private var items: [QueuedItem] = []
    private let monitor = NWPathMonitor()
    private let monitorQueue = DispatchQueue(label: "com.apollo.upload.monitor", qos: .utility)
    private var hasStarted = false

    func start() {
        guard !hasStarted else { return }
        hasStarted = true
        monitor.pathUpdateHandler = { [weak self] path in
            guard let self, path.status == .satisfied else { return }
            let pending: [QueuedItem]
            objc_sync_enter(self)
            pending = self.items
            self.items.removeAll()
            objc_sync_exit(self)
            guard !pending.isEmpty else { return }
            let callback = self.onNetworkRestored
            DispatchQueue.main.async { callback?(pending) }
        }
        monitor.start(queue: monitorQueue)
    }

    func stop() {
        monitor.cancel()
    }

    func enqueue(_ item: QueuedItem) {
        objc_sync_enter(self)
        items.append(item)
        objc_sync_exit(self)
    }

    var isNetworkSatisfied: Bool {
        monitor.currentPath.status == .satisfied
    }

    var count: Int {
        objc_sync_enter(self)
        defer { objc_sync_exit(self) }
        return items.count
    }
}
