//
//  OnePixelBleCameraApp.swift
//  OnePixelBleCamera
//
//  Created by Arnaud Boudou on 21/03/2026.
//

import SwiftUI

@main
struct OnePixelBleCameraApp: App {
    @State private var viewModel = CameraViewViewModel(bleManager: BleCameraManager.shared)

    var body: some Scene {
        WindowGroup {
            CameraView(viewModel: viewModel)
        }
    }
}
