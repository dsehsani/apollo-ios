//
//  DevelopViewModel.swift
//  Apollo
//
//  Drives the Polaroid Develop Flow. Three phases:
//    .undeveloped  → card is dark and blurred, waiting for gesture
//    .developing   → 2.5 s ease-out reveal of the photo
//    .developed    → photo is sharp; checkmark button visible
//
//  Gesture triggers (from DevelopView):
//    - Shake  (CMMotionManager via ShakeDetector)
//    - Rub    (drag > 60% of card width in DevelopView)
//    - Tap    (reduce-motion accessibility path — instant reveal)
//

import Observation
import SwiftUI

@Observable
@MainActor
final class DevelopViewModel {

    enum Phase: Equatable {
        case undeveloped, developing, developed
    }

    enum TriggerSource {
        case shake, rub, tap
    }

    let image: UIImage
    let win: Win?

    private(set) var phase: Phase = .undeveloped
    private(set) var progress: Double = 0  // 0...1

    private var revealTask: Task<Void, Never>?

    init(image: UIImage, win: Win?) {
        self.image = image
        self.win = win
    }

    func triggerDevelop(source: TriggerSource, reduceMotion: Bool) {
        guard phase == .undeveloped else { return }
        phase = .developing

        if reduceMotion || source == .tap {
            progress = 1.0
            phase = .developed
            return
        }

        let duration: TimeInterval = 2.5
        let fps: Double = 60
        let steps = Int(duration * fps)
        let interval = duration / Double(steps)

        revealTask?.cancel()
        revealTask = Task { [weak self] in
            for step in 1...steps {
                guard !Task.isCancelled else { return }
                // ease-out: t = 1 - (1 - normalised)^3
                let t = Double(step) / Double(steps)
                let eased = 1 - pow(1 - t, 3)
                self?.progress = eased
                try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
            }
            self?.progress = 1.0
            self?.phase = .developed
        }
    }
}
