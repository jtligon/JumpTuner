// QRHelpers.swift

import SwiftUI
import CoreImage.CIFilterBuiltins
import AVFoundation

func generateQR(from string: String) -> UIImage? {
    let context = CIContext()
    let filter  = CIFilter.qrCodeGenerator()
    filter.message          = Data(string.utf8)
    filter.correctionLevel  = "M"
    guard let output = filter.outputImage else { return nil }
    let scaled = output.transformed(by: CGAffineTransform(scaleX: 10, y: 10))
    guard let cgImage = context.createCGImage(scaled, from: scaled.extent) else { return nil }
    return UIImage(cgImage: cgImage)
}

struct QRShareSheet: UIViewControllerRepresentable {
    let image: UIImage
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [image], applicationActivities: nil)
    }
    func updateUIViewController(_ uvc: UIActivityViewController, context: Context) {}
}

struct PresetQRView: View {
    let preset: Preset
    @State private var showShare   = false
    @State private var importText  = ""
    @State private var importError = false
    @Environment(\.dismiss) var dismiss

    var qrImage: UIImage? {
        guard let encoded = try? preset.params.encoded() else { return nil }
        let payload = "{\"n\":\"\(preset.name)\",\"d\":\(encoded)}"
        return generateQR(from: payload)
    }

    var body: some View {
        NavigationStack {
            List {
                Section("Export") {
                    if let img = qrImage {
                        VStack(spacing: 12) {
                            Image(uiImage: img)
                                .resizable()
                                .interpolation(.none)
                                .scaledToFit()
                                .frame(maxWidth: 200)
                                .padding(8)
                                .background(Color.white)
                                .cornerRadius(8)
                            Button {
                                showShare = true
                            } label: {
                                Label("Share image", systemImage: "square.and.arrow.up")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                    }
                }
                Section("Import from scan") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Paste scanned JSON below:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        TextEditor(text: $importText)
                            .font(.system(.caption, design: .monospaced))
                            .frame(minHeight: 80)
                        if importError {
                            Text("Invalid preset data.")
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                    }
                }
            }
            .navigationTitle(preset.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(isPresented: $showShare) {
                if let img = qrImage { QRShareSheet(image: img) }
            }
        }
    }
}

// MARK: - QR Scanner

final class QRScannerCoordinator: NSObject, AVCaptureMetadataOutputObjectsDelegate {
    let session = AVCaptureSession()
    weak var previewLayer: AVCaptureVideoPreviewLayer?
    var onScanned: ((String) -> Void)?
    private var isFrozen = false

    override init() {
        super.init()
        guard let device = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input) else { return }
        session.addInput(input)

        let output = AVCaptureMetadataOutput()
        guard session.canAddOutput(output) else { return }
        session.addOutput(output)
        output.setMetadataObjectsDelegate(self, queue: .main)
        output.metadataObjectTypes = [.qr]
    }

    func metadataOutput(_: AVCaptureMetadataOutput,
                        didOutput metadataObjects: [AVMetadataObject],
                        from _: AVCaptureConnection) {
        guard !isFrozen,
              let obj = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
              let str = obj.stringValue else { return }
        isFrozen = true
        onScanned?(str)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.isFrozen = false
        }
    }
}

struct QRScannerCameraView: UIViewRepresentable {
    var onScanned: (String) -> Void
    var isActive: Bool

    func makeCoordinator() -> QRScannerCoordinator { QRScannerCoordinator() }

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .black
        let coordinator = context.coordinator
        coordinator.onScanned = onScanned

        let preview = AVCaptureVideoPreviewLayer(session: coordinator.session)
        preview.videoGravity = .resizeAspectFill
        view.layer.addSublayer(preview)
        coordinator.previewLayer = preview

        let reticle = makeReticle(size: 220)
        view.addSubview(reticle)
        reticle.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            reticle.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            reticle.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -40),
            reticle.widthAnchor.constraint(equalToConstant: 220),
            reticle.heightAnchor.constraint(equalToConstant: 220)
        ])

        if isActive {
            DispatchQueue.global(qos: .userInitiated).async { coordinator.session.startRunning() }
        }
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.previewLayer?.frame = uiView.bounds
        let session = context.coordinator.session
        DispatchQueue.global(qos: .userInitiated).async {
            if self.isActive && !session.isRunning { session.startRunning() }
            else if !self.isActive && session.isRunning { session.stopRunning() }
        }
    }

    private func makeReticle(size: CGFloat) -> UIView {
        let view = UIView()
        view.backgroundColor = .clear
        let cornerLen: CGFloat = 24
        let lw: CGFloat = 3

        // Four corner brackets as CAShapeLayer
        let corners: [(from: CGPoint, corner: CGPoint, to: CGPoint)] = [
            (CGPoint(x: 0, y: cornerLen), CGPoint(x: 0, y: 0), CGPoint(x: cornerLen, y: 0)),
            (CGPoint(x: size - cornerLen, y: 0), CGPoint(x: size, y: 0), CGPoint(x: size, y: cornerLen)),
            (CGPoint(x: 0, y: size - cornerLen), CGPoint(x: 0, y: size), CGPoint(x: cornerLen, y: size)),
            (CGPoint(x: size - cornerLen, y: size), CGPoint(x: size, y: size), CGPoint(x: size, y: size - cornerLen))
        ]
        for pts in corners {
            let path = UIBezierPath()
            path.move(to: pts.from)
            path.addLine(to: pts.corner)
            path.addLine(to: pts.to)
            let layer = CAShapeLayer()
            layer.path = path.cgPath
            layer.strokeColor = UIColor.white.cgColor
            layer.fillColor = UIColor.clear.cgColor
            layer.lineWidth = lw
            layer.lineCap = .round
            view.layer.addSublayer(layer)
        }
        view.layer.cornerRadius = 8
        view.layer.borderColor = UIColor.white.withAlphaComponent(0.25).cgColor
        view.layer.borderWidth = 1
        return view
    }
}

struct QRImportSheet: View {
    var store: PresetStore
    @Binding var params: JumpParams
    @Environment(\.dismiss) private var dismiss

    @State private var authStatus = AVCaptureDevice.authorizationStatus(for: .video)
    @State private var isActive = false
    @State private var errorMessage: String?
    @State private var showPasteFallback = false
    @State private var pasteText = ""
    @State private var pasteError = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                switch authStatus {
                case .authorized:
                    scannerBody
                case .denied, .restricted:
                    deniedBody
                default:
                    requestBody
                }
            }
            .navigationTitle("Scan QR Code")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }.foregroundColor(.white)
                }
            }
        }
        .onAppear { checkPermission() }
    }

    @ViewBuilder private var scannerBody: some View {
        ZStack {
            QRScannerCameraView(onScanned: handleScanned, isActive: isActive)
                .ignoresSafeArea()

            VStack {
                Spacer()
                VStack(spacing: 12) {
                    if let msg = errorMessage {
                        Text(msg)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.red.opacity(0.85))
                            .cornerRadius(8)
                            .transition(.opacity)
                    }
                    Text("Point camera at a JumpTuner QR code")
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.75))
                    Button {
                        isActive = false
                        showPasteFallback = true
                    } label: {
                        Text("Paste JSON instead")
                            .font(.system(size: 13))
                            .foregroundColor(.white.opacity(0.7))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.white.opacity(0.15))
                            .cornerRadius(8)
                    }
                }
                .padding(.bottom, 60)
            }
        }
        .onAppear { isActive = true }
        .onDisappear { isActive = false }
        .sheet(isPresented: $showPasteFallback, onDismiss: { isActive = true }) {
            pasteFallbackView
        }
    }

    @ViewBuilder private var requestBody: some View {
        VStack(spacing: 20) {
            Image(systemName: "camera")
                .font(.system(size: 48))
                .foregroundColor(.white.opacity(0.6))
            Text("Camera access needed to scan QR codes.")
                .font(.system(size: 15))
                .foregroundColor(.white.opacity(0.8))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Button("Allow Camera Access") {
                AVCaptureDevice.requestAccess(for: .video) { granted in
                    DispatchQueue.main.async {
                        authStatus = granted ? .authorized : .denied
                    }
                }
            }
            .buttonStyle(.borderedProminent)
        }
    }

    @ViewBuilder private var deniedBody: some View {
        VStack(spacing: 20) {
            Image(systemName: "camera.fill")
                .font(.system(size: 48))
                .foregroundColor(.white.opacity(0.4))
            Text("Camera access is disabled.\nEnable it in Settings to scan QR codes.")
                .font(.system(size: 15))
                .foregroundColor(.white.opacity(0.7))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .buttonStyle(.bordered)
            .tint(.white)
            Divider().background(Color.white.opacity(0.2)).padding(.horizontal, 32)
            Button("Paste JSON instead") {
                showPasteFallback = true
            }
            .font(.system(size: 13))
            .foregroundColor(.white.opacity(0.7))
        }
        .sheet(isPresented: $showPasteFallback) { pasteFallbackView }
    }

    @ViewBuilder private var pasteFallbackView: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 12) {
                Text("Paste scanned JSON below:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                TextEditor(text: $pasteText)
                    .font(.system(.caption, design: .monospaced))
                    .frame(minHeight: 120)
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.secondary.opacity(0.3)))
                if pasteError {
                    Text("Invalid preset data — check that you pasted a JumpTuner QR payload.")
                        .font(.caption)
                        .foregroundColor(.red)
                }
                Spacer()
            }
            .padding()
            .navigationTitle("Paste JSON")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showPasteFallback = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Import") { importFromPaste() }
                        .disabled(pasteText.isEmpty)
                }
            }
        }
    }

    private func checkPermission() {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        if status == .notDetermined {
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async { authStatus = granted ? .authorized : .denied }
            }
        } else {
            authStatus = status
        }
    }

    private func handleScanned(_ raw: String) {
        isActive = false
        if importPreset(from: raw) {
            dismiss()
        } else {
            withAnimation { errorMessage = "Not a valid JumpTuner QR code" }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                withAnimation { errorMessage = nil }
                isActive = true
            }
        }
    }

    private func importFromPaste() {
        if importPreset(from: pasteText) {
            showPasteFallback = false
            dismiss()
        } else {
            pasteError = true
        }
    }

    @discardableResult
    private func importPreset(from raw: String) -> Bool {
        guard let data = raw.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let paramsJSON = json["d"],
              let paramsData = try? JSONSerialization.data(withJSONObject: paramsJSON),
              let imported = try? JSONDecoder().decode(JumpParams.self, from: paramsData)
        else { return false }
        let name = json["n"] as? String ?? "Imported Preset"
        params = imported
        store.save(Preset(name: name, params: imported))
        return true
    }
}

#Preview {
    PresetQRView(preset: Preset(name: "Preview Preset", params: .defaults))
}
