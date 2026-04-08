//
//  CameraView+ViewModel.swift
//  OnePixelBleCamera
//
//  Created by Arnaud Boudou on 21/03/2026.
//

import SwiftUI

@Observable
@MainActor
class CameraViewViewModel {
    static let height: Int = 100
    static let width: Int = 160
    static let pixelCount: Int = height * width
    static let pixelSize: CGFloat = 3

    private var bleManager: BleCameraManager
    private var rawCameraData: [Int] = []

    var cameraData: [Int] = (1...pixelCount).map( {_ in Int.random(in: 0...1023)} )
    var currentPixel: Int = 0
    var cameraStatus: CameraStatus = .disconnected
    
    var blackLevel: Int = 0
    var whiteLevel: Int = 1023
    var connectionError: String? = nil
    var isConnecting: Bool = false


    var isConnected: Bool {
        return self.cameraStatus != .disconnected
    }
    
    init(bleManager: BleCameraManager) {
        self.bleManager = bleManager
        self.rawCameraData = self.cameraData
        self.bleManager.delegate = self
    }
    
    func connectToCamera() {
        self.isConnecting = true
        self.bleManager.connectToCamera()
    }
    
    func disconnectFromCamera() {
        self.bleManager.disconnectFromCamera()
    }
    
    func takePhoto() {
        let blank = [Int](repeating: 1023, count: Self.pixelCount)
        self.rawCameraData = blank
        self.cameraData = blank
        self.currentPixel = 0
        self.bleManager.takePhoto()
    }
    
    func stretchContrast() {
        guard let srcMin = rawCameraData.min(), let srcMax = rawCameraData.max(), srcMin < srcMax else { return }
        let srcRange = srcMax - srcMin
        let dstRange = whiteLevel - blackLevel
        cameraData = rawCameraData.map { blackLevel + (($0 - srcMin) * dstRange) / srcRange }
    }
    
    /// Renders cameraData (160×100, values 0–1023) into a grayscale JPEG UIImage.
    func renderCameraDataToImage() -> UIImage? {
        let srcWidth = Self.width
        let srcHeight = Self.height
        guard self.cameraData.count >= srcWidth * srcHeight else { return nil }

        let scale = Int(Self.pixelSize)
        let dstWidth = srcWidth * scale
        let dstHeight = srcHeight * scale
        // Build a scaled pixel buffer, repeating each source pixel across a scale×scale block
        var pixels = [UInt8](repeating: 0, count: dstWidth * dstHeight)
        for y in 0..<srcHeight {
            for x in 0..<srcWidth {
                let gray = UInt8(clamping: self.cameraData[y * srcWidth + x] * 255 / 1023)
                for dy in 0..<scale {
                    for dx in 0..<scale {
                        pixels[(y * scale + dy) * dstWidth + (x * scale + dx)] = gray
                    }
                }
            }
        }
        guard let provider = CGDataProvider(data: Data(pixels) as CFData),
              let cgImage = CGImage(
                width: dstWidth,
                height: dstHeight,
                bitsPerComponent: 8,
                bitsPerPixel: 8,
                bytesPerRow: dstWidth,
                space: CGColorSpaceCreateDeviceGray(),
                bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue),
                provider: provider,
                decode: nil,
                shouldInterpolate: false,
                intent: .defaultIntent
              ) else {
            return nil
        }
        let uiImage = UIImage(cgImage: cgImage)
        guard let jpegData = uiImage.jpegData(compressionQuality: 0.9) else { return nil }
        return UIImage(data: jpegData)
    }
}

// MARK: - BleCameraManagerDelegate
extension CameraViewViewModel: BleCameraManagerDelegate {
    func didReceivePixelData(index: Int?, value: Int?) {
        if let index, let value {
            self.rawCameraData[index] = value
            self.cameraData[index] = value
            self.currentPixel = index
        } else {
            self.bleManager.endCapture()
            self.blackLevel = self.rawCameraData.min() ?? 0
            self.whiteLevel = self.rawCameraData.max() ?? 0
            self.stretchContrast()
        }
    }
    
    func didUpdateStatus(status: CameraStatus) {
        self.cameraStatus = status
        self.isConnecting = false
    }

    func didEncounterConnectionError(message: String) {
        self.connectionError = message
        self.isConnecting = false
    }
}
