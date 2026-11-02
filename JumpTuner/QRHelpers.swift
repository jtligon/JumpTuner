// QRHelpers.swift

import SwiftUI
import CoreImage.CIFilterBuiltins
import AVFoundation

// MARK: - QR generation

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

// MARK: - Payload parsing

private struct QRPayload: Decodable {
    let n: String
    let d: JumpParams
}

func parsePresetPayload(_ string: String) throws -> Preset {
    let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
    let data = Data(trimmed.utf8)
    if let payload = try? JSONDecoder().decode(QRPayload.self, from: data) {
        return Preset(name: payload.n, params: payload.d)
    }
    let params = try JumpParams.decoded(from: trimmed)
    return Preset(name: "Imported", params: params)
}

// MARK: - QR share sheet

struct QRShareSheet: UIViewControllerRepresentable {
    let image: UIImage
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [image], applicationActivities: nil)
    }
    func updateUIViewController(_ uvc: UIActivityViewController, context: Context) {}
}

// MARK: - Camera scanner (UIView)

final class ScannerContainerView: UIView {
    var onScan:  ((String) -> Void)?
    var onError: ((String) -> Void)?

    private var session: AVCaptureSession?
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var hasScanned = false

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window != nil { requestAndStart() } else { stop() }
    }

    private func requestAndStart() {
        hasScanned = false
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            setupSession()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    if granted { self?.setupSession() }
                    else { self?.onError?("Camera access is required to scan QR codes.") }
                }
            }
        default:
            onError?("Camera access denied. Enable it in Settings → JumpTuner → Camera.")
        }
    }

    private func setupSession() {
        guard session == nil,
              let device = AVCaptureDevice.default(for: .video),
              let input  = try? AVCaptureDeviceInput(device: device) else {
            onError?("Unable to access the camera.")
            return
        }

        let s = AVCaptureSession()
        guard s.canAddInput(input) else { return }
        s.addInput(input)

        let output = AVCaptureMetadataOutput()
        guard s.canAddOutput(output) else { return }
        s.addOutput(output)
        output.setMetadataObjectsDelegate(self, queue: .main)
        output.metadataObjectTypes = [.qr]

        let p = AVCaptureVideoPreviewLayer(session: s)
        p.videoGravity = .resizeAspectFill
        p.frame = bounds
        layer.insertSublayer(p, at: 0)

        session = s
        previewLayer = p
        DispatchQueue.global(qos: .userInitiated).async { s.startRunning() }
    }

    func stop() {
        session?.stopRunning()
        session = nil
        previewLayer?.removeFromSuperlayer()
        previewLayer = nil
        hasScanned = false
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        previewLayer?.frame = bounds
    }
}

extension ScannerContainerView: AVCaptureMetadataOutputObjectsDelegate {
    func metadataOutput(_ output: AVCaptureMetadataOutput,
                        didOutput objects: [AVMetadataObject],
                        from connection: AVCaptureConnection) {
        guard !hasScanned,
              let obj   = objects.first as? AVMetadataMachineReadableCodeObject,
              let value = obj.stringValue else { return }
        hasScanned = true
        session?.stopRunning()
        onScan?(value)
        // Resume after a short pause so the user can scan again if import failed
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in
            self?.hasScanned = false
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                self?.session?.startRunning()
            }
        }
    }
}

// MARK: - QRScannerView (SwiftUI wrapper)

struct QRScannerView: UIViewRepresentable {
    var onScan:  (String) -> Void
    var onError: (String) -> Void

    func makeUIView(context: Context) -> ScannerContainerView {
        let v = ScannerContainerView()
        v.onScan  = onScan
        v.onError = onError
        return v
    }

    func updateUIView(_ uiView: ScannerContainerView, context: Context) {}
}

// MARK: - PresetQRView

struct PresetQRView: View {
    let preset: Preset
    var onImport: ((Preset) -> Void)? = nil

    @State private var showShare     = false
    @State private var selectedTab   = 0       // 0 = scan, 1 = paste
    @State private var importText    = ""
    @State private var importError: String?    = nil
    @State private var importSuccess           = false
    @State private var cameraError: String?    = nil
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
                    Picker("Import method", selection: $selectedTab) {
                        Label("Scan", systemImage: "qrcode.viewfinder").tag(0)
                        Label("Paste JSON", systemImage: "doc.on.clipboard").tag(1)
                    }
                    .pickerStyle(.segmented)
                    .padding(.vertical, 4)
                    .onChange(of: selectedTab) { _, _ in
                        importError = nil
                        importSuccess = false
                    }

                    if selectedTab == 0 {
                        scannerTab
                    } else {
                        pasteTab
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

    // MARK: Scanner tab

    @ViewBuilder
    private var scannerTab: some View {
        if let err = cameraError {
            VStack(spacing: 12) {
                Image(systemName: "camera.slash")
                    .font(.system(size: 36))
                    .foregroundColor(.secondary)
                Text(err)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                .buttonStyle(.bordered)
            }
            .frame(maxWidth: .infinity)
            .padding()
        } else {
            ZStack {
                QRScannerView(
                    onScan:  { handleScanned($0) },
                    onError: { cameraError = $0 }
                )
                .frame(height: 240)
                .cornerRadius(12)
                .clipped()

                // Targeting reticle
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.white.opacity(0.75), lineWidth: 2)
                    .frame(width: 140, height: 140)

                if importSuccess {
                    ZStack {
                        Color.black.opacity(0.6).cornerRadius(12)
                        VStack(spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 44))
                                .foregroundColor(.green)
                            Text("Preset imported!")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(.white)
                        }
                    }
                }
            }
            .frame(height: 240)

            if let err = importError {
                Label(err, systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding(.vertical, 2)
            }

            Text("Point at a JumpTuner QR code to import a preset.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    // MARK: Paste tab

    @ViewBuilder
    private var pasteTab: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Paste a JumpTuner JSON preset below:")
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
            if importSuccess {
                Label("Preset imported!", systemImage: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundColor(.green)
            }
            Button("Import") {
                handleScanned(importText)
            }
            .buttonStyle(.borderedProminent)
            .disabled(importText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
    }

    // MARK: Shared import handler

    private func handleScanned(_ value: String) {
        importError = nil
        importSuccess = false
        guard !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        do {
            let imported = try parsePresetPayload(value)
            onImport?(imported)
            importSuccess = true
            importError = nil
            if selectedTab == 0 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { dismiss() }
            }
        } catch {
            importError = "Invalid preset data — make sure you're scanning a JumpTuner QR code."
        }
    }
}

#Preview {
    PresetQRView(preset: Preset(name: "Preview Preset", params: .defaults))
}
