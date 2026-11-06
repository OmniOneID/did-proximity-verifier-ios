//
/*
 * Copyright 2026 OmniOne.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

import SwiftUI
import AVFoundation
import MdocReader

struct DeviceEngagementScreen: View {
    @Environment(AppModel.self) private var model
    @Environment(\.scenePhase) private var scenePhase
    @State private var scanner = QRScannerController()
    @State private var dialog: DialogContent?
    @State private var hasHandedOff = false
    @State private var rejectedCode: String?

    var body: some View {
        ZStack {
            ZStack {
                Color.Palette.cameraBackdrop
                CameraPreview(session: scanner.captureSession)
                ScanCutout {
                    Text("Please scan the QR code inside the square.")
                        .font(AppFont.regular(14))
                        .foregroundStyle(.white.opacity(0.9))
                        .frame(maxWidth: .infinity)
                }
            }
            .ignoresSafeArea()
            #if targetEnvironment(simulator)
            .contentShape(Rectangle())
            .onTapGesture { handOff(qrString: "mdoc:simulated", validate: false) }
            #endif

            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    Spacer(minLength: 0)
                    Button { close() } label: {
                        Icons.close(size: 26)
                            .foregroundStyle(.white)
                            .frame(width: 40, height: 40)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Close")
                    .accessibilityIdentifier("closeButton")
                }
                .padding(.horizontal, 16)
                .frame(height: Metrics.appBarHeight)

                Text("Device Engagement")
                    .font(AppFont.semibold(22))
                    .foregroundStyle(.white)
                    .padding(.top, 4)

                Spacer(minLength: 0)
            }
        }
        .preferredColorScheme(.dark)
        .errorDialog($dialog) { content in
            if content.dismissesScreen { model.dismissScanner() }
            else { scanner.resume() }
        }
        .task { await start() }
        .onDisappear { scanner.stop() }
        // Going to the background closes this screen (AppModel.handleBackground), but onDisappear
        // may only arrive after the app is back - by then the camera has resumed behind Home.
        .onChange(of: scenePhase) { _, phase in
            if phase == .background { scanner.stop() }
        }
    }

    private func start() async {
        switch await scanner.prepare() {
        case .ready:
            scanner.onCode = { code in handOff(qrString: code, validate: true) }
            scanner.onUnavailable = { presentUnavailable() }
            scanner.start()
        case .denied:
            dialog = DialogContent(
                message: "Camera access is required to scan the QR code. Enable the camera permission in system settings and try again.",
                dismissesScreen: true)
        case .unavailable:
            #if targetEnvironment(simulator)
            break
            #else
            presentUnavailable()
            #endif
        }
    }

    private func presentUnavailable() {
        guard !hasHandedOff, dialog == nil else { return }
        dialog = DialogContent(
            message: "The camera is unavailable. Close other apps using the camera and try again.",
            dismissesScreen: true)
    }

    private func handOff(qrString: String, validate: Bool) {
        // A code read after the screen was closed must not start a session from wherever the app is.
        guard !hasHandedOff, model.isScannerPresented else { return }
        if validate {
            guard qrString != rejectedCode else { return }
            do {
                _ = try EngagementPayload.parse(qrString: qrString)
            } catch {
                rejectedCode = qrString
                scanner.pause()
                dialog = DialogContent(message: VerifierError.invalidEngagement.message ?? "")
                return
            }
        }
        hasHandedOff = true
        scanner.stop()
        model.startSession(qrString: qrString)
    }

    private func close() {
        scanner.stop()
        model.dismissScanner()
    }
}

struct ScanCutout<Caption: View>: View {
    var size: CGFloat = 220
    var captionGap: CGFloat = 20
    @ViewBuilder var caption: Caption

    private static var bracketLength: CGFloat { 44 }
    private static var bracketRadius: CGFloat { 6 }
    private static var bracketWidth: CGFloat { 2 }

    var body: some View {
        ZStack {
            Color.black.opacity(0.7)
                .mask {
                    Rectangle()
                        .overlay {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .frame(width: size, height: size)
                                .blendMode(.destinationOut)
                        }
                        .compositingGroup()
                }

            ZStack {
                bracket(rotation: 0).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                bracket(rotation: 90).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                bracket(rotation: 180).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                bracket(rotation: 270).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
            }
            .frame(width: size, height: size)
        }
        .overlay(alignment: .center) {
            caption.alignmentGuide(VerticalAlignment.center) { d in
                d[.top] - (size / 2 + captionGap)
            }
        }
        .allowsHitTesting(false)
    }

    private func bracket(rotation: Double) -> some View {
        let length = Self.bracketLength
        let inset = Self.bracketWidth / 2
        let radius = Self.bracketRadius
        return Path { path in
            path.move(to: CGPoint(x: inset, y: length))
            path.addLine(to: CGPoint(x: inset, y: inset + radius))
            path.addQuadCurve(to: CGPoint(x: inset + radius, y: inset),
                              control: CGPoint(x: inset, y: inset))
            path.addLine(to: CGPoint(x: length, y: inset))
        }
        .stroke(Color.white, style: StrokeStyle(lineWidth: Self.bracketWidth, lineCap: .butt))
        .frame(width: length, height: length)
        .rotationEffect(.degrees(rotation))
    }
}

// MARK: - Camera

@MainActor
final class QRScannerController: NSObject, AVCaptureMetadataOutputObjectsDelegate {
    enum Readiness { case ready, denied, unavailable }

    let captureSession = AVCaptureSession()
    var onCode: ((String) -> Void)?
    var onUnavailable: (() -> Void)?

    private let queue = DispatchQueue(label: "verifier.qr-scanner")
    private var isConfigured = false
    private var isPaused = false
    private var observers: [NSObjectProtocol] = []

    func prepare() async -> Readiness {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            break
        case .notDetermined:
            guard await AVCaptureDevice.requestAccess(for: .video) else { return .denied }
        case .denied, .restricted:
            return .denied
        @unknown default:
            return .denied
        }
        return configure() ? .ready : .unavailable
    }

    private func configure() -> Bool {
        if isConfigured { return true }
        guard let device = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device) else { return false }

        captureSession.beginConfiguration()
        defer { captureSession.commitConfiguration() }
        guard captureSession.canAddInput(input) else { return false }
        captureSession.addInput(input)

        let output = AVCaptureMetadataOutput()
        guard captureSession.canAddOutput(output) else { return false }
        captureSession.addOutput(output)
        output.setMetadataObjectsDelegate(self, queue: .main)
        output.metadataObjectTypes = [.qr]
        observeInterruptions()
        isConfigured = true
        return true
    }

    private func observeInterruptions() {
        let center = NotificationCenter.default
        observers.append(center.addObserver(forName: AVCaptureSession.runtimeErrorNotification,
                                            object: captureSession, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.onUnavailable?() }
        })
        observers.append(center.addObserver(forName: AVCaptureSession.wasInterruptedNotification,
                                            object: captureSession, queue: .main) { [weak self] note in
            guard let raw = note.userInfo?[AVCaptureSessionInterruptionReasonKey] as? Int,
                  let reason = AVCaptureSession.InterruptionReason(rawValue: raw) else { return }
            switch reason {
            case .videoDeviceInUseByAnotherClient,
                 .videoDeviceNotAvailableWithMultipleForegroundApps,
                 .videoDeviceNotAvailableDueToSystemPressure:
                MainActor.assumeIsolated { self?.onUnavailable?() }
            case .videoDeviceNotAvailableInBackground, .audioDeviceInUseByAnotherClient:
                break
            @unknown default:
                break
            }
        })
    }

    deinit {
        for observer in observers { NotificationCenter.default.removeObserver(observer) }
    }

    func start() {
        guard isConfigured else { return }
        isPaused = false
        queue.async { [captureSession] in
            if !captureSession.isRunning { captureSession.startRunning() }
        }
    }

    func stop() {
        queue.async { [captureSession] in
            if captureSession.isRunning { captureSession.stopRunning() }
        }
    }

    func pause() { isPaused = true }
    func resume() { isPaused = false }

    nonisolated func metadataOutput(_ output: AVCaptureMetadataOutput,
                                    didOutput metadataObjects: [AVMetadataObject],
                                    from connection: AVCaptureConnection) {
        guard let code = metadataObjects
                .compactMap({ $0 as? AVMetadataMachineReadableCodeObject })
                .first(where: { $0.type == .qr })?
                .stringValue else { return }
        Task { @MainActor in
            guard !self.isPaused else { return }
            self.onCode?(code)
        }
    }
}

struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ uiView: PreviewView, context: Context) { }

    final class PreviewView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
    }
}
