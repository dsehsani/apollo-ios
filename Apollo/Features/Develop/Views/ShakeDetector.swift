//
//  ShakeDetector.swift
//  Apollo
//
//  Invisible UIViewRepresentable that uses CMMotionManager to detect a
//  device shake. Threshold: 2.5g sustained for ≥0.3 s. Fires `onShake` once
//  per trigger and goes quiet until reset.
//

import CoreMotion
import SwiftUI

struct ShakeDetector: UIViewRepresentable {
    let active: Bool
    let onShake: () -> Void

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .clear
        view.isUserInteractionEnabled = false
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        if active {
            context.coordinator.start(onShake: onShake)
        } else {
            context.coordinator.stop()
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator {
        private let motion = CMMotionManager()
        private var exceedStart: Date?
        private var fired = false
        private var onShake: (() -> Void)?

        func start(onShake: @escaping () -> Void) {
            guard !motion.isAccelerometerActive else { return }
            self.onShake = onShake
            fired = false
            exceedStart = nil
            motion.accelerometerUpdateInterval = 1.0 / 60.0
            motion.startAccelerometerUpdates(to: .main) { [weak self] data, _ in
                guard let self, let data, !self.fired else { return }
                let g = sqrt(
                    data.acceleration.x * data.acceleration.x +
                    data.acceleration.y * data.acceleration.y +
                    data.acceleration.z * data.acceleration.z
                )
                if g > 2.5 {
                    if let start = self.exceedStart {
                        if Date().timeIntervalSince(start) >= 0.3 {
                            self.fired = true
                            DispatchQueue.main.async { self.onShake?() }
                        }
                    } else {
                        self.exceedStart = Date()
                    }
                } else {
                    self.exceedStart = nil
                }
            }
        }

        func stop() {
            motion.stopAccelerometerUpdates()
            exceedStart = nil
            fired = false
        }
    }
}
