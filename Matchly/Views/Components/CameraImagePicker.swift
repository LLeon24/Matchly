//
//  CameraImagePicker.swift
//  Matchly
//
//  Captures the same video frame shown in the live preview (not a separate still photo),
//  so review/crop match framing with no extra zoom.
//

import AVFoundation
import CoreImage
import SwiftUI
import UIKit

struct CameraImagePicker: UIViewControllerRepresentable {
    @Environment(\.dismiss) private var dismiss
    var cameraDevice: UIImagePickerController.CameraDevice = .front
    var onImagePicked: (UIImage) -> Void

    static var isAvailable: Bool {
        AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front) != nil
    }

    func makeUIViewController(context: Context) -> CameraViewController {
        let controller = CameraViewController()
        controller.initialPosition = cameraDevice == .rear ? .back : .front
        controller.onCancel = { dismiss() }
        controller.onUsePhoto = { image in
            onImagePicked(image)
            dismiss()
        }
        return controller
    }

    func updateUIViewController(_ uiViewController: CameraViewController, context: Context) {}

    /// Sample buffer matches the live preview (including front-camera mirroring on the connection).
    static func profilePhoto(fromPreviewFrame image: UIImage) -> UIImage {
        image.fixedOrientation()
    }
}

// MARK: - Camera UI

final class CameraViewController: UIViewController {
    var initialPosition: AVCaptureDevice.Position = .front
    var onCancel: (() -> Void)?
    var onUsePhoto: ((UIImage) -> Void)?

    private enum Mode {
        case live
        case review(UIImage)
    }

    private let session = AVCaptureSession()
    private let sessionQueue = DispatchQueue(label: "com.matchly.profile-camera.session")
    private let videoDataOutput = AVCaptureVideoDataOutput()
    private let sampleBufferStore = ProfileCameraSampleBufferStore()

    private var previewLayer: AVCaptureVideoPreviewLayer!
    private var currentInput: AVCaptureDeviceInput?
    private var currentPosition: AVCaptureDevice.Position = .front
    private var mode: Mode = .live

    private let previewContainer = UIView()
    private let reviewImageView = UIImageView()
    private let closeButton = UIButton(type: .system)
    private let shutterButton = UIButton(type: .custom)
    private let flipButton = UIButton(type: .system)
    private let retakeButton = UIButton(type: .system)
    private let usePhotoButton = UIButton(type: .system)
    private let reviewBar = UIView()
    private let liveControlsBar = UIView()

    private let ciContext = CIContext(options: [.useSoftwareRenderer: false])

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        currentPosition = initialPosition
        configureUI()
        checkAuthorizationAndConfigureSession()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = previewContainer.bounds
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        sessionQueue.async { [weak self] in
            guard let self, self.session.isRunning else { return }
            self.session.stopRunning()
        }
    }

    // MARK: - UI

    private func configureUI() {
        previewContainer.translatesAutoresizingMaskIntoConstraints = false
        previewContainer.backgroundColor = .black
        view.addSubview(previewContainer)

        previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.videoGravity = .resizeAspectFill
        previewContainer.layer.addSublayer(previewLayer)

        reviewImageView.translatesAutoresizingMaskIntoConstraints = false
        reviewImageView.contentMode = .scaleAspectFill
        reviewImageView.clipsToBounds = true
        reviewImageView.isHidden = true
        previewContainer.addSubview(reviewImageView)

        liveControlsBar.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(liveControlsBar)

        reviewBar.translatesAutoresizingMaskIntoConstraints = false
        reviewBar.isHidden = true
        view.addSubview(reviewBar)

        configureButton(closeButton, title: nil, systemImage: "xmark", size: 22)
        closeButton.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)

        shutterButton.translatesAutoresizingMaskIntoConstraints = false
        shutterButton.backgroundColor = .white
        shutterButton.layer.cornerRadius = 36
        shutterButton.layer.borderWidth = 4
        shutterButton.layer.borderColor = UIColor.white.withAlphaComponent(0.35).cgColor
        shutterButton.addTarget(self, action: #selector(shutterTapped), for: .touchUpInside)

        configureButton(flipButton, title: nil, systemImage: "arrow.triangle.2.circlepath.camera", size: 22)
        flipButton.addTarget(self, action: #selector(flipTapped), for: .touchUpInside)

        retakeButton.setTitle("Retake", for: .normal)
        retakeButton.titleLabel?.font = .systemFont(ofSize: 17)
        retakeButton.addTarget(self, action: #selector(retakeTapped), for: .touchUpInside)

        usePhotoButton.setTitle("Use Photo", for: .normal)
        usePhotoButton.titleLabel?.font = .systemFont(ofSize: 17, weight: .semibold)
        usePhotoButton.addTarget(self, action: #selector(usePhotoTapped), for: .touchUpInside)

        for item in [closeButton, flipButton, retakeButton, usePhotoButton] {
            item.translatesAutoresizingMaskIntoConstraints = false
        }
        liveControlsBar.addSubview(closeButton)
        liveControlsBar.addSubview(shutterButton)
        liveControlsBar.addSubview(flipButton)
        reviewBar.addSubview(retakeButton)
        reviewBar.addSubview(usePhotoButton)

        NSLayoutConstraint.activate([
            previewContainer.topAnchor.constraint(equalTo: view.topAnchor),
            previewContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            previewContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            previewContainer.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            reviewImageView.topAnchor.constraint(equalTo: previewContainer.topAnchor),
            reviewImageView.leadingAnchor.constraint(equalTo: previewContainer.leadingAnchor),
            reviewImageView.trailingAnchor.constraint(equalTo: previewContainer.trailingAnchor),
            reviewImageView.bottomAnchor.constraint(equalTo: previewContainer.bottomAnchor),

            liveControlsBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            liveControlsBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            liveControlsBar.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            liveControlsBar.heightAnchor.constraint(equalToConstant: 120),

            reviewBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            reviewBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            reviewBar.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            reviewBar.heightAnchor.constraint(equalToConstant: 72),

            closeButton.leadingAnchor.constraint(equalTo: liveControlsBar.leadingAnchor, constant: 24),
            closeButton.centerYAnchor.constraint(equalTo: shutterButton.centerYAnchor),

            shutterButton.centerXAnchor.constraint(equalTo: liveControlsBar.centerXAnchor),
            shutterButton.topAnchor.constraint(equalTo: liveControlsBar.topAnchor, constant: 12),
            shutterButton.widthAnchor.constraint(equalToConstant: 72),
            shutterButton.heightAnchor.constraint(equalToConstant: 72),

            flipButton.trailingAnchor.constraint(equalTo: liveControlsBar.trailingAnchor, constant: -24),
            flipButton.centerYAnchor.constraint(equalTo: shutterButton.centerYAnchor),

            retakeButton.leadingAnchor.constraint(equalTo: reviewBar.leadingAnchor, constant: 24),
            retakeButton.centerYAnchor.constraint(equalTo: reviewBar.centerYAnchor),

            usePhotoButton.trailingAnchor.constraint(equalTo: reviewBar.trailingAnchor, constant: -24),
            usePhotoButton.centerYAnchor.constraint(equalTo: reviewBar.centerYAnchor),
        ])
    }

    private func configureButton(_ button: UIButton, title: String?, systemImage: String?, size: CGFloat) {
        if let systemImage {
            let config = UIImage.SymbolConfiguration(pointSize: size, weight: .medium)
            button.setImage(UIImage(systemName: systemImage, withConfiguration: config), for: .normal)
        } else if let title {
            button.setTitle(title, for: .normal)
        }
        button.tintColor = .white
    }

    private func setMode(_ newMode: Mode) {
        mode = newMode
        switch newMode {
        case .live:
            reviewImageView.isHidden = true
            previewLayer.isHidden = false
            liveControlsBar.isHidden = false
            reviewBar.isHidden = true
            sessionQueue.async { [weak self] in
                guard let self, !self.session.isRunning else { return }
                self.session.startRunning()
            }
        case .review(let image):
            reviewImageView.image = image
            reviewImageView.isHidden = false
            previewLayer.isHidden = true
            liveControlsBar.isHidden = true
            reviewBar.isHidden = false
        }
    }

    // MARK: - Actions

    @objc private func closeTapped() {
        onCancel?()
    }

    @objc private func shutterTapped() {
        let buffer = sampleBufferStore.copyLatestSampleBuffer()

        let rotationAngle = videoDataOutput.connection(with: .video)?.videoRotationAngle ?? 0
        guard let buffer,
              let image = Self.image(from: buffer, context: ciContext, rotationAngle: rotationAngle) else { return }

        let processed = CameraImagePicker.profilePhoto(fromPreviewFrame: image)
        setMode(.review(processed))
    }

    @objc private func flipTapped() {
        let next: AVCaptureDevice.Position = currentPosition == .front ? .back : .front
        sessionQueue.async { [weak self] in
            self?.switchCamera(to: next)
        }
    }

    @objc private func retakeTapped() {
        setMode(.live)
    }

    @objc private func usePhotoTapped() {
        guard case .review(let image) = mode else { return }
        onUsePhoto?(image)
    }

    // MARK: - Session

    private func checkAuthorizationAndConfigureSession() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            configureSession()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                guard granted else {
                    DispatchQueue.main.async { self?.onCancel?() }
                    return
                }
                self?.configureSession()
            }
        default:
            onCancel?()
        }
    }

    private func configureSession() {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            self.session.beginConfiguration()
            if self.session.canSetSessionPreset(.high) {
                self.session.sessionPreset = .high
            } else {
                self.session.sessionPreset = .photo
            }

            defer {
                self.session.commitConfiguration()
                self.updateConnectionMirroring()
                if !self.session.isRunning {
                    self.session.startRunning()
                }
            }

            self.applyCameraInput(position: self.currentPosition)

            self.videoDataOutput.videoSettings = [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
            ]
            self.videoDataOutput.alwaysDiscardsLateVideoFrames = true
            let sampleDelegate = self.sampleBufferStore
            self.videoDataOutput.setSampleBufferDelegate(sampleDelegate, queue: self.sessionQueue)

            if self.session.canAddOutput(self.videoDataOutput) {
                self.session.addOutput(self.videoDataOutput)
            }
        }
    }

    private func applyCameraInput(position: AVCaptureDevice.Position) {
        if let currentInput {
            session.removeInput(currentInput)
            self.currentInput = nil
        }

        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input) else {
            return
        }

        session.addInput(input)
        currentInput = input
        currentPosition = position

        do {
            try device.lockForConfiguration()
            if device.isFocusModeSupported(.continuousAutoFocus) {
                device.focusMode = .continuousAutoFocus
            }
            if device.isExposureModeSupported(.continuousAutoExposure) {
                device.exposureMode = .continuousAutoExposure
            }
            device.videoZoomFactor = 1.0
            device.unlockForConfiguration()
        } catch {
            // Non-fatal.
        }

        DispatchQueue.main.async { [weak self] in
            self?.updateConnectionMirroring()
        }
    }

    private func switchCamera(to position: AVCaptureDevice.Position) {
        session.beginConfiguration()
        applyCameraInput(position: position)
        session.commitConfiguration()
        updateConnectionMirroring()
    }

    private func updateConnectionMirroring() {
        if let previewConnection = previewLayer?.connection,
           previewConnection.isVideoMirroringSupported {
            previewConnection.automaticallyAdjustsVideoMirroring = false
            previewConnection.isVideoMirrored = currentPosition == .front
        }

        if let videoConnection = videoDataOutput.connection(with: .video) {
            if videoConnection.isVideoMirroringSupported {
                videoConnection.automaticallyAdjustsVideoMirroring = false
                videoConnection.isVideoMirrored = currentPosition == .front
            }
            if let previewConnection = previewLayer?.connection,
               videoConnection.isVideoRotationAngleSupported(previewConnection.videoRotationAngle) {
                videoConnection.videoRotationAngle = previewConnection.videoRotationAngle
            }
        }
    }

    private static func image(
        from sampleBuffer: CMSampleBuffer,
        context: CIContext,
        rotationAngle: CGFloat
    ) -> UIImage? {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return nil }
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else { return nil }
        return UIImage(cgImage: cgImage, scale: 1, orientation: uiImageOrientation(forVideoRotationAngle: rotationAngle))
    }

    private static func uiImageOrientation(forVideoRotationAngle angle: CGFloat) -> UIImage.Orientation {
        switch Int(angle.rounded()) % 360 {
        case 90: return .right
        case 180: return .down
        case 270: return .left
        default: return .up
        }
    }
}

/// Holds the latest preview frame on the capture queue (not MainActor-isolated; Swift 6 safe).
private final class ProfileCameraSampleBufferStore: NSObject, @unchecked Sendable {
    private let lock = NSLock()
    private nonisolated(unsafe) var latestSampleBuffer: CMSampleBuffer?

    nonisolated func copyLatestSampleBuffer() -> CMSampleBuffer? {
        lock.lock()
        defer { lock.unlock() }
        return latestSampleBuffer
    }
}

extension ProfileCameraSampleBufferStore: AVCaptureVideoDataOutputSampleBufferDelegate {
    nonisolated func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        lock.lock()
        latestSampleBuffer = sampleBuffer
        lock.unlock()
    }
}
