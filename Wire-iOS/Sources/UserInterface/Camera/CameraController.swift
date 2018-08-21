////
// Wire
// Copyright (C) 2018 Wire Swiss GmbH
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program. If not, see http://www.gnu.org/licenses/.
//

import Foundation

fileprivate let zmLog = ZMSLog(tag: "UI")

class CameraController {
    
    var currentCamera = SettingsCamera.front {
        willSet { switchInput(to: newValue) }
    }
    
    var previewLayer: AVCaptureVideoPreviewLayer!

    private enum SetupResult { case success, notAuthorized, failed }
    private var setupResult: SetupResult = .success
    
    private var session = AVCaptureSession()
    private let sessionQueue = DispatchQueue(label: "com.wire.camera_controller_session")
    
    private var frontCameraDeviceInput: AVCaptureDeviceInput?
    private var backCameraDeviceInput: AVCaptureDeviceInput?
    
    private let photoOutput = AVCapturePhotoOutput()
    private var captureDelegates = [Int64 : PhotoCaptureDelegate]()
    
    init?() {
        guard !UIDevice.isSimulator else { return nil }
        setupSession()
        previewLayer = AVCaptureVideoPreviewLayer(session: session)
    }
    
    // MARK: - Session Management
    
    private func requestAccess() {
        sessionQueue.suspend()
        AVCaptureDevice.requestAccess(for: .video) { granted in
            self.setupResult = granted ? .success : .notAuthorized
            self.sessionQueue.resume()
        }
    }
    
    private func setupSession() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:       break
        case .notDetermined:    requestAccess()
        default:                setupResult = .notAuthorized
        }
        
        sessionQueue.async(execute: configureSession)
    }
    
    private func configureSession() {
        guard setupResult == .success else { return }
        
        session.beginConfiguration()
        defer { session.commitConfiguration() }
        
        session.sessionPreset = .photo
        
        // SETUP INPUTS
        
        var canAddFrontInput = false
        var canAddBackInput = false
        
        if let device = cameraDevice(for: .front), let input = try? AVCaptureDeviceInput(device: device) {
            frontCameraDeviceInput = input
            canAddFrontInput = session.canAddInput(input)
        }
        
        if let device = cameraDevice(for: .back), let input = try? AVCaptureDeviceInput(device: device) {
            backCameraDeviceInput = input
            canAddBackInput = session.canAddInput(input)
        }
        
        // we need at least one functional input
        guard canAddFrontInput || canAddBackInput else {
            zmLog.error("CameraController could not add any inputs.")
            setupResult = .failed
            return
        }
        
        // TODO: Connect current input or first available.
        connectInput(for: currentCamera)
        
        // SETUP OUTPUTS
        
        guard session.canAddOutput(photoOutput) else {
            zmLog.error("CameraController could not add photo capture output.")
            setupResult = .failed
            return
        }

        session.addOutput(photoOutput)
    }
    
    func startRunning() {
        sessionQueue.async { self.session.startRunning() }
    }
    
    func stopRunning() {
        sessionQueue.async { self.session.stopRunning() }
    }
    
    // MARK: - Device Management
    
    /**
     * The capture device for the given camera position, if available.
     */
    private func cameraDevice(for position: AVCaptureDevice.Position) -> AVCaptureDevice? {
        return AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position)
    }
    
    /**
     * The device input for the given camera, if available.
     */
    private func input(for camera: SettingsCamera) -> AVCaptureDeviceInput? {
        switch camera {
        case .front:    return frontCameraDeviceInput
        case .back:     return backCameraDeviceInput
        }
    }
    
    /**
     * Connects the input for the given camera, if it is available.
     */
    private func connectInput(for camera: SettingsCamera) {
        guard let input = input(for: camera) else { return }
        sessionQueue.async {
            self.session.beginConfiguration()
            self.session.addInput(input)
            self.session.commitConfiguration()
        }
    }
    
    /**
     * Disconnects the current camera and connects the given camera, but only
     * if both camera inputs are available.
     */
    private func switchInput(to camera: SettingsCamera) {
        guard currentCamera != camera,
            let inputToRemove = input(for: currentCamera),
            let inputToAdd = input(for: camera)
            else { return }
        
        sessionQueue.async {
            self.session.beginConfiguration()
            self.session.removeInput(inputToRemove)
            self.session.addInput(inputToAdd)
            self.session.commitConfiguration()
        }
    }
    
    // MARK: - Image Capture
    
    typealias PhotoResult = (data: Data?, error: Error?)
    
    /**
     * Asynchronously attempts to capture a photo within the currently
     * configured session. The result is passed into the given handler
     * callback.
     */
    func capturePhoto(_ handler: @escaping (PhotoResult) -> Void) {
        
        // For iPad split/slide over mode, the session is not running.
        guard session.isRunning else { return }
        
        sessionQueue.async {
            guard let connection = self.photoOutput.connection(with: .video) else { return }
            connection.videoOrientation = self.previewLayer.connection?.videoOrientation ?? .portrait
            connection.automaticallyAdjustsVideoMirroring = false
            connection.isVideoMirrored = false
            
            let settings = AVCapturePhotoSettings(format: [AVVideoCodecKey: AVVideoCodecJPEG,
                                                           AVVideoCompressionPropertiesKey: [AVVideoQualityKey: 0.9]])
            
            let delegate = PhotoCaptureDelegate(settings: settings, handler: handler) {
                self.sessionQueue.async { self.captureDelegates[settings.uniqueID] = nil }
            }
            
            self.captureDelegates[settings.uniqueID] = delegate
            self.photoOutput.capturePhoto(with: settings, delegate: delegate)
        }
    }
    
    /**
     * A PhotoCaptureDelegate is responsible for processing the photo buffers
     * returned from `AVCapturePhotoOutput`. For each photo captured, there is
     * one unique delegate object responsible.
     */
    private class PhotoCaptureDelegate: NSObject, AVCapturePhotoCaptureDelegate {
        
        private let settings: AVCapturePhotoSettings
        private let handler: (PhotoResult) -> Void
        private let completion: () -> Void
        
        init(settings: AVCapturePhotoSettings,
             handler: @escaping (PhotoResult) -> Void,
             completion: @escaping () -> Void)
        {
            self.settings = settings
            self.handler = handler
            self.completion = completion
        }
        
        func photoOutput(_ output: AVCapturePhotoOutput,
                         didFinishProcessingPhoto photoSampleBuffer: CMSampleBuffer?,
                         previewPhoto previewPhotoSampleBuffer: CMSampleBuffer?,
                         resolvedSettings: AVCaptureResolvedPhotoSettings,
                         bracketSettings: AVCaptureBracketedStillImageSettings?,
                         error: Error?)
        {
            defer { completion() }
            
            if let error = error {
                zmLog.error("PhotoCaptureDelegate encountered error while processing photo:\(error.localizedDescription)")
                handler(PhotoResult(nil, error))
                return
            }
            
            guard let buffer = photoSampleBuffer else { return }
            
            let imageData = AVCapturePhotoOutput.jpegPhotoDataRepresentation(
                forJPEGSampleBuffer: buffer,
                previewPhotoSampleBuffer: previewPhotoSampleBuffer)
            
            handler(PhotoResult(imageData, nil))
        }
    }
}


private extension AVCaptureVideoOrientation {
    
    /// The video orientation mmatches against first the device orientation,
    /// then the interface orientation. Must be called on the main thread.
    static var current: AVCaptureVideoOrientation {
        let device = UIDevice.current.orientation
        let ui = UIApplication.shared.statusBarOrientation
        return self.init(deviceOrientation: device) ?? self.init(uiOrientation: ui) ?? .portrait
    }

    init?(deviceOrientation: UIDeviceOrientation) {
        switch deviceOrientation {
        case .landscapeLeft:        self = .landscapeLeft
        case .portrait:             self = .portrait
        case .landscapeRight:       self = .landscapeRight
        case .portraitUpsideDown:   self = .portraitUpsideDown
        default:                    return nil
        }
    }
    
    init?(uiOrientation: UIInterfaceOrientation) {
        switch uiOrientation {
        case .landscapeLeft:        self = .landscapeLeft
        case .portrait:             self = .portrait
        case .landscapeRight:       self = .landscapeRight
        case .portraitUpsideDown:   self = .portraitUpsideDown
        default:                    return nil
        }
    }
}