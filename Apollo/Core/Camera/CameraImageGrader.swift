//
//  CameraImageGrader.swift
//  Apollo
//
//  Pure-function Core Image pipeline. Applies a subtle film-grade look to
//  captured images before they are compressed and uploaded.
//
//  Grade spec:
//    +60 K warmth  — CITemperatureAndTint (neutral 6500 K → target 6440 K)
//    Shadow lift   — input 0.0 → output 8/255
//    Highlight ceil — input 1.0 → output 248/255
//    Contrast      — mild S-curve flattened ~8%
//    Saturation    — −6% (0.94 of default)
//

import CoreImage
import CoreImage.CIFilterBuiltins
import UIKit

enum CameraImageGrader {

    static func grade(_ source: UIImage) -> UIImage {
        guard let ciInput = CIImage(image: source) else { return source }

        // Use a shared CIContext (expensive to create) via lazy static.
        let graded = applyFilters(to: ciInput)

        guard let cgImage = sharedContext.createCGImage(graded, from: ciInput.extent) else {
            return source
        }
        return UIImage(cgImage: cgImage, scale: source.scale, orientation: source.imageOrientation)
    }

    // MARK: - Private

    private static let sharedContext = CIContext(options: [
        .workingColorSpace: CGColorSpaceCreateDeviceRGB(),
        .useSoftwareRenderer: false
    ])

    private static func applyFilters(to image: CIImage) -> CIImage {
        var output = image

        // 1. Warmth +60 K: shift neutral from 6500 K to 6440 K.
        if let tempTint = CIFilter(name: "CITemperatureAndTint") {
            tempTint.setValue(output, forKey: kCIInputImageKey)
            tempTint.setValue(CIVector(x: 6500, y: 0), forKey: "inputNeutral")
            tempTint.setValue(CIVector(x: 6440, y: 0), forKey: "inputTargetNeutral")
            output = tempTint.outputImage ?? output
        }

        // 2. Tone curve: shadow lift 8/255, highlight ceiling 248/255,
        //    S-curve midtone contrast reduced ~8%.
        if let toneCurve = CIFilter(name: "CIToneCurve") {
            toneCurve.setValue(output, forKey: kCIInputImageKey)
            toneCurve.setValue(CIVector(x: 0.00, y: 8.0 / 255.0),  forKey: "inputPoint0")
            toneCurve.setValue(CIVector(x: 0.25, y: 0.275),         forKey: "inputPoint1")
            toneCurve.setValue(CIVector(x: 0.50, y: 0.500),         forKey: "inputPoint2")
            toneCurve.setValue(CIVector(x: 0.75, y: 0.718),         forKey: "inputPoint3")
            toneCurve.setValue(CIVector(x: 1.00, y: 248.0 / 255.0), forKey: "inputPoint4")
            output = toneCurve.outputImage ?? output
        }

        // 3. Saturation −6% (0.94).
        if let colorControls = CIFilter(name: "CIColorControls") {
            colorControls.setValue(output, forKey: kCIInputImageKey)
            colorControls.setValue(0.94 as NSNumber, forKey: kCIInputSaturationKey)
            output = colorControls.outputImage ?? output
        }

        return output
    }
}
