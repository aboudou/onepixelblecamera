//
//  CameraView.swift
//  OnePixelBleCamera
//
//  Created by Arnaud Boudou on 21/03/2026.
//

import SwiftUI

struct CameraView: View {
    var viewModel: CameraViewViewModel
    
    @State private var shareItem: ShareableImage?
    
    private let pixelColumns = Array(repeating: GridItem(.fixed(CameraViewViewModel.pixelSize), spacing: 0), count: CameraViewViewModel.width)

    private var statusColor: Color {
        switch self.viewModel.cameraStatus {
            case .disconnected: Color.red
            case .readyToCapture: Color.blue
            case .capturing: Color.green
        }
    }
    
    var body: some View {
        HStack (spacing: 16) {
            // Action button
            Button(action: {
                self.viewModel.takePhoto()
            },
                   label: {
                    Image(systemName: "camera")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .padding(10)
                        .frame(width: 50, height: 50)
            })
            .disabled(!self.viewModel.isConnected || self.viewModel.cameraStatus != .readyToCapture)
            .buttonBorderShape(.circle)
            .buttonStyle(.borderedProminent)
            .frame(width: 120)

            Spacer()
            
            VStack(spacing: 4) {
                // Pixel grid
                self.imageGrid

                VStack(spacing: 8) {
                    Text("Scanning in progress, please be patient")
                        .font(.system(size: 18))

                    ProgressView(value: Double(self.viewModel.currentPixel) / Double(self.viewModel.cameraData.count))
                        .frame(width: 300)

                    Text("Pixel \(self.viewModel.currentPixel + 1) of \(self.viewModel.cameraData.count)")
                        .font(.system(size: 15))
                }
                .frame(alignment: .center)
                .opacity(self.viewModel.cameraStatus == .capturing ? 1 : 0)
            }
        }
        .frame(maxHeight: .infinity)
        .overlay(alignment: .topLeading) {
            // Connect / disconnect button
            HStack {
                Button(self.viewModel.isConnected ? "Disconnect" : "Connect") {
                    if self.viewModel.isConnected {
                        self.viewModel.disconnectFromCamera()
                    } else {
                        self.viewModel.connectToCamera()
                    }
                }
                .buttonBorderShape(.capsule)
                .buttonStyle(.bordered)
                .disabled(self.viewModel.cameraStatus == .capturing || self.viewModel.isConnecting)
                
                if self.viewModel.isConnecting {
                    ProgressView()
                        .frame(width: 20, height: 20)
                } else {
                    Circle()
                        .fill(self.statusColor)
                        .frame(width: 20, height: 20)
                }
                
                // Share button
                Button(action: {
                    if let image = self.viewModel.renderCameraDataToImage() {
                        self.shareItem = ShareableImage(image: image)
                    }
                },
                       label: {
                        Image(systemName: "square.and.arrow.up")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 25, height: 25)
                })

            }
        }
        .overlay(alignment: .bottomLeading) {
            // Black and white levels steppers
            VStack {
                Stepper {
                    Text("Black level:\n\(Int(self.viewModel.blackLevel))")
                } onIncrement: {
                    self.viewModel.blackLevel += 10
                    self.viewModel.blackLevel = min(self.viewModel.blackLevel, 510)
                    self.viewModel.stretchContrast()
                } onDecrement: {
                    self.viewModel.blackLevel -= 10
                    self.viewModel.blackLevel = max(self.viewModel.blackLevel, 0)
                    self.viewModel.stretchContrast()
                }

                Stepper {
                    Text("White level:\n\(Int(self.viewModel.whiteLevel))")
                } onIncrement: {
                    self.viewModel.whiteLevel += 10
                    self.viewModel.whiteLevel = min(self.viewModel.whiteLevel, 1023)
                    self.viewModel.stretchContrast()
                } onDecrement: {
                    self.viewModel.whiteLevel -= 10
                    self.viewModel.whiteLevel = max(self.viewModel.whiteLevel, 513)
                    self.viewModel.stretchContrast()
                }
            }
            .frame(width: 200)
            
        }
        .padding()
        .sheet(item: $shareItem) { item in
            ActivityViewController(activityItems: [item.image])
        }
        .alert("Connection Error", isPresented: Binding(
            get: { self.viewModel.connectionError != nil },
            set: { if !$0 { self.viewModel.connectionError = nil } }
        ), presenting: self.viewModel.connectionError) { _ in
            Button("OK") { self.viewModel.connectionError = nil }
        } message: { error in
            Text(error)
        }
    }
    
    @ViewBuilder
    private var imageGrid: some View {
        LazyVGrid(columns: self.pixelColumns, spacing: 0) {
            ForEach(Array(self.viewModel.cameraData.enumerated()), id: \.offset) { index, value in
                Rectangle()
                    .fill(Color(
                        red: Double(value) / 1023.0,
                        green: Double(value) / 1023.0,
                        blue: Double(value) / 1023.0)
                    )
                    .frame(width: CameraViewViewModel.pixelSize, height: CameraViewViewModel.pixelSize)
                    .id(index)
            }
        }
    }
}

// MARK: - Identifiable wrapper for sharing an image via .sheet(item:)
private struct ShareableImage: Identifiable {
    let id = UUID()
    let image: UIImage
}

// MARK: - UIActivityViewController wrapper
struct ActivityViewController: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

