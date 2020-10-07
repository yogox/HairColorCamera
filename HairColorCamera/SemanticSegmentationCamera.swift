//
//  SemanticSegmentationCamera.swift
//  HairColorCamera
//
//  Created by yogox on 2020/10/07.
//  Copyright © 2020 Yogox Galaxy. All rights reserved.
//

import SwiftUI
import AVFoundation


extension AVCaptureDevice.Position: CaseIterable {
    public static var allCases: [AVCaptureDevice.Position] {
        return [
            .front,
            .back,
        ]
    }
    
    mutating func toggle() {
        self = self == .front ? .back : .front
    }
}

class SemanticSegmentationCamera: NSObject, AVCapturePhotoCaptureDelegate, ObservableObject {
    typealias CameraPosition = AVCaptureDevice.Position

    @Published var image: UIImage?
    @Published var previewLayer: [CameraPosition: AVCaptureVideoPreviewLayer] = [:]
    private var captureDevice: AVCaptureDevice!
    private var captureSession: [CameraPosition: AVCaptureSession] = [:]
    private var dataOutput: [CameraPosition: AVCapturePhotoOutput] = [:]
    private var currentCameraPosition: CameraPosition
    
    override init() {
        currentCameraPosition = .back
        super.init()
        for cameraPosition in CameraPosition.allCases {
            previewLayer[cameraPosition] = AVCaptureVideoPreviewLayer()
            captureSession[cameraPosition] = AVCaptureSession()
            setupSession(cameraPosition: cameraPosition)
        }
        captureSession[currentCameraPosition]?.startRunning()
    }
    
    private func setupDevice(cameraPosition: CameraPosition = .back) {
        if let availableDevice = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera],
            mediaType: AVMediaType.video,
            position: cameraPosition
        ).devices.first {
            captureDevice = availableDevice
        }
    }
    
    private func setupSession(cameraPosition: CameraPosition = .back) {
        setupDevice(cameraPosition: cameraPosition)
        
        let captureSession = self.captureSession[cameraPosition]!
        captureSession.beginConfiguration()
        captureSession.sessionPreset = .photo
        
        do {
            let captureDeviceInput = try AVCaptureDeviceInput(device: captureDevice)
            captureSession.addInput(captureDeviceInput)
        } catch {
            print(error.localizedDescription)
        }
        
        let previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        self.previewLayer[cameraPosition] = previewLayer
        
        dataOutput[cameraPosition] = AVCapturePhotoOutput()
        guard let photoOutput = dataOutput[cameraPosition] else {
            return
        }
        if captureSession.canAddOutput(photoOutput) {
            captureSession.addOutput(photoOutput)
            
            photoOutput.isDepthDataDeliveryEnabled = photoOutput.isDepthDataDeliverySupported
            
            // SemanticSegmentationMatteの設定
            photoOutput.enabledSemanticSegmentationMatteTypes = photoOutput.availableSemanticSegmentationMatteTypes
        }
        
        captureSession.commitConfiguration()
    }
    
    func switchCamera() {
        captureSession[currentCameraPosition]?.stopRunning()
        currentCameraPosition.toggle()
        captureSession[currentCameraPosition]?.startRunning()
    }
    
    func takePhoto() {
        let settings = AVCapturePhotoSettings(format: [AVVideoCodecKey: AVVideoCodecType.hevc])
        settings.isDepthDataDeliveryEnabled = true
        
        // SemanticSegmentationMatteの設定
        settings.enabledSemanticSegmentationMatteTypes = dataOutput[currentCameraPosition]?.availableSemanticSegmentationMatteTypes ?? [AVSemanticSegmentationMatte.MatteType]()
        
        dataOutput[currentCameraPosition]?.capturePhoto(with: settings, delegate: self)
    }
    
    // MARK: - AVCapturePhotoCaptureDelegate
    func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishProcessingPhoto photo: AVCapturePhoto,
        error: Error?
    ) {
        // 元写真を取得
        guard let imageData = photo.fileDataRepresentation(),
              let ciImage = CIImage(data: imageData)
        else { return }
        
        var photoImage = ciImage
        
        // skin, hair, teethのsemanticSegmentationMatteを取得
        if let hairMatte = photo.semanticSegmentationMatte(for: .hair)
           , let _ = photo.semanticSegmentationMatte(for: .skin)
           , let _ = photo.semanticSegmentationMatte(for: .teeth)
        {
            // CIImageを作成
            let hairImage = CIImage(semanticSegmentationMatte: hairMatte, options: [.auxiliarySemanticSegmentationHairMatte: true])
            
            // 自作カスタムフィルターで肌の色を変更
            let matteFilter = CIChangeHairColor()
            matteFilter.inputImage = photoImage
            matteFilter.hairMatteImage = hairImage
            photoImage = matteFilter.outputImage!
        }
        
        // 画像の向きを決め打ち修正
        photoImage = photoImage.oriented(.right)
        // Imageクラスでも描画されるようにCGImage経由でUIImageに変換
        let context = CIContext(options: nil)
        let cgImage = context.createCGImage(photoImage, from: photoImage.extent)
        self.image = UIImage(cgImage: cgImage!)
    }
}
