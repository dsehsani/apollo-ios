//
//  DebugFileLogger.swift
//  Apollo
//
//  Temporary HTTP debug instrumentation for the Cursor debug session.
//  Sends one JSON payload per log entry via POST to the local Cursor debug
//  ingest endpoint (the ingest server appends each request to the session's
//  NDJSON log file). Best-effort — failures are silently dropped so the
//  app behaviour is never affected.
//
//  REMOVE this file (and all DebugFileLog.log call-sites) after the camera
//  save bug is fixed and verified.
//

import Foundation

enum DebugFileLog {
    static let endpoint = URL(string: "http://127.0.0.1:7809/ingest/f2764775-e9ec-4875-ad36-b763e1f86c68")!
    static let sessionID = "ad90ff"

    /// Best-effort log via HTTP POST to the local Cursor debug endpoint.
    static func log(
        _ hypothesisId: String,
        _ location: String,
        _ message: String,
        _ data: [String: Any] = [:]
    ) {
        var payload: [String: Any] = [
            "sessionId": sessionID,
            "hypothesisId": hypothesisId,
            "location": location,
            "message": message,
            "timestamp": Int(Date().timeIntervalSince1970 * 1000),
        ]
        if !data.isEmpty {
            payload["data"] = sanitize(data)
        }
        guard let body = try? JSONSerialization.data(withJSONObject: payload, options: []) else {
            return
        }
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(sessionID, forHTTPHeaderField: "X-Debug-Session-Id")
        request.httpBody = body
        request.timeoutInterval = 2
        URLSession.shared.dataTask(with: request) { _, _, _ in }.resume()
    }

    private static func sanitize(_ dict: [String: Any]) -> [String: Any] {
        var out: [String: Any] = [:]
        for (k, v) in dict {
            if JSONSerialization.isValidJSONObject([v]) {
                out[k] = v
            } else {
                out[k] = String(describing: v)
            }
        }
        return out
    }
}
