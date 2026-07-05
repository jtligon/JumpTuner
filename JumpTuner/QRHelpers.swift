// QRHelpers.swift

import SwiftUI
import CoreImage.CIFilterBuiltins
import AVFoundation

// MARK: - QR Generation

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

// MARK: - Share Sheet

struct QRShareSheet: UIViewControllerRepresentable {
    let image: UIImage
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [image], applicationActivities: nil)
    }
    func updateUIViewController(_ uvc: UIActivityViewController, context: Context) {}
}

// MARK: - Camera QR Scanner

final class QRScannerCoordinator: NSObject, AVCaptureMetadataOutputObjectsDelegate {
    let session = AVCaptureSession()
    var previewLayer: AVCaptureVideoPreviewLayer?
    var onDetect: ((String) -> Void)?
    private var frozen = false

    func metadataOutput(_ output: AVCaptureMetadataOutput,
                        didOutput metadataObjects: [AVMetadataObject],
                        from connection: AVCaptureConnection) {
        guard !frozen,
              let obj   = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
              let value = obj.stringValue else { return }
        frozen = true
        onDetect?(value)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.frozen = false
        }
    }
}

struct QRScannerView: UIViewRepresentable {
    var onDetect: (String) -> Void

    func makeCoordinator() -> QRScannerCoordinator { QRScannerCoordinator() }

    func makeUIView(context: Context) -> UIView {
        let coordinator = context.coordinator
        coordinator.onDetect = onDetect

        let view = UIView()
        view.backgroundColor = .black

        let session = coordinator.session
        guard let device = AVCaptureDevice.default(for: .video),
              let input  = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input) else { return view }
        session.addInput(input)

        let output = AVCaptureMetadataOutput()
        guard session.canAddOutput(output) else { return view }
        session.addOutput(output)
        output.setMetadataObjectsDelegate(coordinator, queue: .main)
        output.metadataObjectTypes = [.qr]

        let preview = AVCaptureVideoPreviewLayer(session: session)
        preview.videoGravity = .resizeAspectFill
        preview.frame = view.bounds
        view.layer.addSublayer(preview)
        coordinator.previewLayer = preview

        DispatchQueue.global(qos: .userInitiated).async { session.startRunning() }
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.previewLayer?.frame = uiView.bounds
    }

    static func dismantleUIView(_ uiView: UIView, coordinator: QRScannerCoordinator) {
        coordinator.session.stopRunning()
    }
}

struct QRScannerSheet: View {
    var onDetect: (String) -> Void
    @State private var authStatus = AVCaptureDevice.authorizationStatus(for: .video)
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                switch authStatus {
                case .authorized:
                    ZStack {
                        QRScannerView { value in
                            onDetect(value)
                            dismiss()
                        }
                        .ignoresSafeArea()
                        reticle
                    }
                case .notDetermined:
                    Color.clear.onAppear { requestAccess() }
                default:
                    permissionDeniedView
                }
            }
            .navigationTitle("Scan Preset QR")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private var reticle: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height) * 0.62
            ZStack {
                Canvas { ctx, size in
                    ctx.fill(Path(CGRect(origin: .zero, size: size)),
                             with: .color(.black.opacity(0.5)))
                    let hole = Path(RoundedRectangle(cornerRadius: 14).path(in: CGRect(
                        x: (size.width  - side) / 2,
                        y: (size.height - side) / 2,
                        width: side, height: side
                    )))
                    ctx.blendMode = .clear
                    ctx.fill(hole, with: .color(.white))
                }
                .allowsHitTesting(false)

                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color.white, lineWidth: 2.5)
                    .frame(width: side, height: side)

                VStack {
                    Spacer()
                    Text("Point at a JumpTuner QR code")
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.85))
                        .padding(.bottom, 44)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
    }

    private var permissionDeniedView: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "camera.slash.fill")
                .font(.system(size: 52))
                .foregroundColor(.secondary)
            Text("Camera access is required to scan QR codes.\nEnable it in Settings.")
                .font(.system(size: 15))
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal)
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .buttonStyle(.borderedProminent)
            Spacer()
        }
    }

    private func requestAccess() {
        AVCaptureDevice.requestAccess(for: .video) { granted in
            DispatchQueue.main.async {
                authStatus = granted ? .authorized : .denied
            }
        }
    }
}

// MARK: - Preset QR View

private struct QRPayload: Decodable {
    let n: String
    let d: JumpParams
}

struct PresetQRView: View {
    let preset: Preset
    var onImport: ((Preset) -> Void)? = nil

    @State private var showShare   = false
    @State private var showScanner = false
    @State private var importText  = ""
    @State private var importError: String? = nil
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

                Section("Import") {
                    Button {
                        showScanner = true
                    } label: {
                        Label("Scan QR Code", systemImage: "camera.viewfinder")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .padding(.vertical, 4)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Or paste JSON:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        TextEditor(text: $importText)
                            .font(.system(.caption, design: .monospaced))
                            .frame(minHeight: 80)
                        if let err = importError {
                            Text(err)
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                        Button("Import") { importFromText() }
                            .buttonStyle(.bordered)
                            .disabled(importText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
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
            .sheet(isPresented: $showScanner) {
                QRScannerSheet { rawString in
                    handleScannedString(rawString)
                }
            }
        }
    }

    private func importFromText() {
        handleScannedString(importText.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    private func handleScannedString(_ raw: String) {
        importError = nil
        guard let data = raw.data(using: .utf8) else {
            importError = "Invalid data."
            return
        }
        if let payload = try? JSONDecoder().decode(QRPayload.self, from: data) {
            onImport?(Preset(name: payload.n, params: payload.d))
            dismiss()
            return
        }
        if let params = try? JumpParams.decoded(from: raw) {
            onImport?(Preset(name: "Imported", params: params))
            dismiss()
            return
        }
        importError = "Not a valid JumpTuner preset."
    }
}

#Preview {
    PresetQRView(preset: Preset(name: "Preview Preset", params: .defaults))
}
