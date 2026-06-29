// CharacterPhotoFlow.swift
// Photo → Image Playground → CharacterSkin pipeline.
//
// On device with Apple Intelligence:
//   confirmation dialog → camera (primary) or library → Image Playground sheet
// On simulator or devices without Apple Intelligence:
//   library picker → image used directly as sprite (no generation step)
//
// Usage: attach .characterPhotoFlow(isPresented:onSkin:) to any view.

import SwiftUI
import PhotosUI
import ImagePlayground

// MARK: - Public modifier

extension View {
    func characterPhotoFlow(
        isPresented: Binding<Bool>,
        onSkin: @escaping (CharacterSkin) -> Void
    ) -> some View {
        modifier(CharacterPhotoFlowModifier(isPresented: isPresented, onSkin: onSkin))
    }
}

// MARK: - Modifier

private struct CharacterPhotoFlowModifier: ViewModifier {
    @Binding var isPresented: Bool
    let onSkin: (CharacterSkin) -> Void

    // Source selection
    @State private var showingSourceDialog  = false
    @State private var showingCamera        = false
    @State private var showingLibrary       = false

    // Intermediate state
    @State private var sourceImage: UIImage?
    @State private var showingPlayground    = false

    private var playgroundAvailable: Bool { ImagePlaygroundViewController.isAvailable }
    private var cameraAvailable: Bool { UIImagePickerController.isSourceTypeAvailable(.camera) }

    func body(content: Content) -> some View {
        content
            .onChange(of: isPresented) { _, presented in
                guard presented else { return }
                isPresented = false   // reset immediately; we drive our own sheets

                if playgroundAvailable && cameraAvailable {
                    // On-device with AI: ask which source first
                    showingSourceDialog = true
                } else {
                    // Simulator or no Apple Intelligence: go straight to library
                    showingLibrary = true
                }
            }
            // Source picker dialog (device only)
            .confirmationDialog("Add Character", isPresented: $showingSourceDialog) {
                Button("Take Photo") { showingCamera = true }
                Button("Choose from Library") { showingLibrary = true }
                Button("Cancel", role: .cancel) { }
            }
            // Camera (device only)
            .sheet(isPresented: $showingCamera) {
                CameraPickerView(image: $sourceImage)
                    .ignoresSafeArea()
                    .onChange(of: sourceImage) { _, img in
                        if img != nil {
                            showingCamera = false
                            showingPlayground = true
                        }
                    }
            }
            // Photo library
            .photosPicker(
                isPresented: $showingLibrary,
                selection: Binding(
                    get: { nil as PhotosPickerItem? },
                    set: { item in
                        guard let item else { return }
                        Task {
                            if let data  = try? await item.loadTransferable(type: Data.self),
                               let image = UIImage(data: data) {
                                sourceImage = image
                                if playgroundAvailable {
                                    showingPlayground = true
                                } else {
                                    // Simulator / no AI: use image directly
                                    commitImage(image, viaPlayground: false)
                                }
                            }
                        }
                    }
                ),
                matching: .images,
                photoLibrary: .shared()
            )
            // Image Playground (device with Apple Intelligence only)
            .imagePlaygroundSheet(
                isPresented: $showingPlayground,
                concepts: [.text("pixel art game character jumping sprite")],
                sourceImage: sourceImage.map { Image(uiImage: $0) },
                onCompletion: { url in
                    showingPlayground = false
                    handlePlaygroundResult(url: url)
                },
                onCancellation: {
                    showingPlayground = false
                    sourceImage = nil
                }
            )
    }

    // MARK: - Helpers

    private func handlePlaygroundResult(url: URL) {
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }

        guard let data  = try? Data(contentsOf: url),
              let image = UIImage(data: data) else { return }
        commitImage(image, viaPlayground: true)
    }

    private func commitImage(_ image: UIImage, viaPlayground: Bool) {
        let name = viaPlayground ? "Custom" : "Photo"
        // Playground output is already stylised — keep it as a simple sprite.
        // Raw photos get the full Vision / skeletal-rig treatment.
        let skin = viaPlayground
            ? CharacterSkin.generated(image: image, name: name)
            : CharacterSkin.fromPhoto(image: image, name: name)
        onSkin(skin)
        sourceImage = nil
    }
}

// MARK: - Camera picker (UIViewControllerRepresentable)

private struct CameraPickerView: UIViewControllerRepresentable {
    @Binding var image: UIImage?

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate   = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraPickerView
        init(_ parent: CameraPickerView) { self.parent = parent }

        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            parent.image = info[.originalImage] as? UIImage
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
        }
    }
}
