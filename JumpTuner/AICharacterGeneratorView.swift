// AICharacterGeneratorView.swift
// Sheet that lets the user describe a character and generates it via Claude.

import SwiftUI

private let apiKeyDefaultsKey = "anthropic_api_key"

struct AICharacterGeneratorView: View {

    let onGenerate: (CharacterSkin) -> Void

    @State private var description: String = ""
    @State private var apiKey: String = UserDefaults.standard.string(forKey: apiKeyDefaultsKey) ?? ""
    @State private var isGenerating = false
    @State private var errorMessage: String?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("Describe what you want your character to look like — color, style, features.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    TextField("e.g. a chubby green alien with three eyes",
                              text: $description, axis: .vertical)
                        .lineLimit(3...6)
                } header: {
                    Text("Character description")
                }

                Section {
                    SecureField("sk-ant-…", text: $apiKey)
                        .textContentType(.password)
                        .autocorrectionDisabled()
                        .onChange(of: apiKey) { _, v in
                            UserDefaults.standard.set(v, forKey: apiKeyDefaultsKey)
                        }
                } header: {
                    Text("Anthropic API key")
                } footer: {
                    Text("Your key is stored only on this device and never shared.")
                        .font(.caption)
                }

                if let msg = errorMessage {
                    Section {
                        Label(msg, systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                            .font(.subheadline)
                    }
                }
            }
            .navigationTitle("AI Character")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isGenerating {
                        ProgressView().progressViewStyle(.circular)
                    } else {
                        Button("Generate") { generate() }
                            .disabled(description.trimmingCharacters(in: .whitespaces).isEmpty)
                            .bold()
                    }
                }
            }
        }
    }

    private func generate() {
        errorMessage = nil
        isGenerating = true
        let desc = description
        let key  = apiKey
        Task {
            defer { isGenerating = false }
            do {
                let aiParams = try await AICharacterService.generate(description: desc, apiKey: key)
                let skin = CharacterSkin(id: "ai-\(UUID().uuidString)",
                                         name: aiParams.name) {
                    AICharacterNode(params: aiParams)
                }
                await MainActor.run {
                    onGenerate(skin)
                    dismiss()
                }
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}

#Preview {
    AICharacterGeneratorView { _ in }
}
