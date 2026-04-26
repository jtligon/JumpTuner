// QRHelpers.swift

import SwiftUI
import CoreImage.CIFilterBuiltins

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

#Preview {
    PresetQRView(preset: Preset(name: "Preview Preset", params: .defaults))
}
