//
//  BleCameraManager.swift
//  OnePixelBleCamera
//
//  Created by Arnaud Boudou on 21/03/2026.
//

import UIKit
import CoreBluetooth

enum CameraStatus: UInt8 {
    case readyToCapture = 0
    case capturing = 1
    case disconnected = 2
}

@MainActor
protocol BleCameraManagerDelegate: AnyObject {
    func didReceivePixelData(index: Int?, value: Int?)
    func didUpdateStatus(status: CameraStatus)
    func didEncounterConnectionError(message: String)
}

class BleCameraManager: NSObject {
    
    static let shared = BleCameraManager()

    private let cameraServiceUUID = CBUUID(string: "688c6011-fa63-429b-bea4-18517d46c9ee")
    private let statusCharacteristicUUID = CBUUID(string: "cbedefb3-b8ec-4656-b7db-96271f7f33d2")
    private let currentPixelCharacteristicUUID = CBUUID(string: "081458cb-264d-4b7f-8007-4e0cfbbe2300")
    private let bleQueue = DispatchQueue(label: "com.onePixelBleCamera.ble")

    @MainActor private var scanTimeoutTask: Task<Void, Never>?
    @MainActor private var pendingScan = false
    private var cameraPeripheral: CBPeripheral?
    private var statusCharacteristic: CBCharacteristic?
    private var currentPixelCharacteristic: CBCharacteristic?
    private lazy var manager = CBCentralManager(delegate: self, queue: bleQueue)

    weak var delegate: BleCameraManagerDelegate?
    
    override private init() {}

    @MainActor
    func connectToCamera() {
        self.scanTimeoutTask?.cancel()
        if self.manager.state == .poweredOn {
            self.manager.scanForPeripherals(withServices: [self.cameraServiceUUID], options: nil)
        } else {
            // Manager not ready yet; scan will start when .poweredOn fires
            self.pendingScan = true
        }
        self.scanTimeoutTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(15))
            guard !Task.isCancelled, let self else { return }
            self.pendingScan = false
            self.manager.stopScan()
            self.delegate?.didEncounterConnectionError(message: "No camera found. Make sure the camera is powered on and nearby.")
        }
    }
    
    @MainActor
    func disconnectFromCamera() {
        self.pendingScan = false
        self.scanTimeoutTask?.cancel()
        self.scanTimeoutTask = nil
        self.manager.stopScan()
        guard let cameraPeripheral = self.cameraPeripheral else { return }
        if let statusCharacteristic = self.statusCharacteristic {
            cameraPeripheral.setNotifyValue(false, for: statusCharacteristic)
        }
        if let currentPixelCharacteristic = self.currentPixelCharacteristic {
            cameraPeripheral.setNotifyValue(false, for: currentPixelCharacteristic)
        }
        self.manager.cancelPeripheralConnection(cameraPeripheral)
    }
    
    func takePhoto() {
        if let cameraPeripheral = self.cameraPeripheral, let statusCharacteristic = self.statusCharacteristic {
            let data = Data([CameraStatus.capturing.rawValue])
            UIApplication.shared.isIdleTimerDisabled = true
            cameraPeripheral.writeValue(data, for: statusCharacteristic, type: .withResponse)
        }
    }
        
    func endCapture() {
        if let cameraPeripheral = self.cameraPeripheral, let statusCharacteristic = self.statusCharacteristic {
            let data = Data([CameraStatus.readyToCapture.rawValue])
            cameraPeripheral.writeValue(data, for: statusCharacteristic, type: .withResponse)
            UIApplication.shared.isIdleTimerDisabled = false
        }
    }
}
    
extension BleCameraManager: CBCentralManagerDelegate {
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        if peripheral.name == "1Pixel Camera" || peripheral.name == "Arduino" {
            Task { @MainActor [weak self] in
                self?.scanTimeoutTask?.cancel()
                self?.scanTimeoutTask = nil
            }
            self.cameraPeripheral = peripheral
            self.cameraPeripheral?.delegate = self
            self.manager.connect(peripheral, options: nil)
            self.manager.stopScan()
        }
    }
    
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
            case .poweredOff:
                Task { @MainActor [weak self] in
                    self?.delegate?.didUpdateStatus(status: .disconnected)
                }
                print("Bluetooth is switched off")

            case .poweredOn:
                Task { @MainActor [weak self] in
                    guard let self, self.pendingScan else { return }
                    self.pendingScan = false
                    self.manager.scanForPeripherals(withServices: [self.cameraServiceUUID], options: nil)
                }
                print("Bluetooth is switched on")

            case .unsupported:
                print("Bluetooth is not supported")

            default:
                print("Unknown state")
        }
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        peripheral.discoverServices([self.cameraServiceUUID])

        print("Connected to \(peripheral.name ?? "Unknown name")")
    }
    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        self.cameraPeripheral = nil
        self.statusCharacteristic = nil
        self.currentPixelCharacteristic = nil
        Task { @MainActor [weak self] in
            self?.delegate?.didUpdateStatus(status: .disconnected)
        }
        print("Disconnected from \(peripheral.name ?? "Unknown name")")
    }
    
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        let message = error?.localizedDescription ?? "Failed to connect to the camera."
        Task { @MainActor [weak self] in
            self?.delegate?.didEncounterConnectionError(message: message)
        }
        print(error as Any)
    }
    
}

extension BleCameraManager: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard let services = peripheral.services else { return }
        
        for service in services {
            peripheral.discoverCharacteristics([statusCharacteristicUUID, currentPixelCharacteristicUUID], for: service)
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard let characteristics = service.characteristics else { return }
        
        self.statusCharacteristic = characteristics.filter({ $0.uuid == statusCharacteristicUUID }).first
        self.currentPixelCharacteristic = characteristics.filter({ $0.uuid == currentPixelCharacteristicUUID }).first

        if let statusCharacteristic = self.statusCharacteristic {
            peripheral.setNotifyValue(true, for: statusCharacteristic)
        }

        // Subscribe to notifications for pixel data
        if let currentPixelCharacteristic = self.currentPixelCharacteristic {
            peripheral.setNotifyValue(true, for: currentPixelCharacteristic)
        }
        
        Task { @MainActor [weak self] in
            self?.delegate?.didUpdateStatus(status: .readyToCapture)
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: (any Error)?) {
        // Read camera status to update GUI accordingly
        if characteristic == self.statusCharacteristic {
            if let data = characteristic.value {
                let value: UInt8 = data[0]
                if let cameraStatus = CameraStatus(rawValue: value) {
                    Task { @MainActor [weak self] in
                        self?.delegate?.didUpdateStatus(status: cameraStatus)
                    }
                }
            }

        } else if characteristic == self.currentPixelCharacteristic {
            if let data = characteristic.value {
                let rawValue: String = String(data: data, encoding: .utf8) ?? ""
                if rawValue.isEmpty { return }
                if rawValue == "EOT" {
                    Task { @MainActor [weak self] in
                        self?.delegate?.didReceivePixelData(index: nil, value: nil)
                    }
                    return
                }
                let parts = rawValue.split(separator: "#")
                guard parts.count == 2, let pixel = Int(parts[0]), let value = Int(parts[1]) else { return }
                Task { @MainActor [weak self] in
                    self?.delegate?.didReceivePixelData(index: pixel, value: value)
                }
            }
        }
    }
}
