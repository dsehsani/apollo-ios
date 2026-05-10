//
//  CameraLogger.swift
//  Apollo
//
//  Persistent os.Logger for the camera capture + upload + commit pipeline.
//  Messages are visible in Console.app and Xcode's console in all build
//  configurations, including Release builds on a device — no #if DEBUG guards.
//
//  Usage:
//    CameraLog.log.debug("upload started path:\(path)")
//    CameraLog.log.error("RPC failed: \(error.localizedDescription)")
//

import os

enum CameraLog {
    static let log = Logger(subsystem: "DariusEhsani.Apollo", category: "Camera")
}
