// PresetsView.swift

import SwiftUI

struct PresetsView: View {
    @ObservedObject var store: PresetStore
    @Binding var params: JumpParams
    @Binding var selectedQRPreset: Preset?
    @State private var presetName = ""

    var body: some View {
        CollapsibleSection(title: "Presets", icon: "star.fill",
                           accentColor: SectionTheme.presets) {
            // Save row
            HStack {
                TextField("Preset name…", text: $presetName)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 13))
                Button("Save") {
                    guard !presetName.isEmpty else { return }
                    store.save(Preset(name: presetName, params: params))
                    presetName = ""
                }
                .buttonStyle(.borderedProminent)
                .tint(SectionTheme.presets)
                .disabled(presetName.isEmpty)
                .font(.system(size: 13))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            if store.presets.isEmpty {
                Text("No presets saved yet")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 10)
            }

            ForEach(store.presets) { preset in
                VStack(spacing: 0) {
                    HStack {
                        Text(preset.name)
                            .font(.system(size: 13))
                        Spacer()
                        Button("Load") { params = preset.params }
                            .font(.system(size: 12))
                            .buttonStyle(.bordered)
                            .tint(SectionTheme.presets)

                        Button { selectedQRPreset = preset } label: {
                            Image(systemName: "qrcode")
                        }
                        .buttonStyle(.bordered)
                        .tint(SectionTheme.presets)

                        Button { store.delete(id: preset.id) } label: {
                            Image(systemName: "trash")
                        }
                        .buttonStyle(.bordered)
                        .tint(.red)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)

                    Divider().padding(.leading, 16)
                }
            }
        }
    }
}

#Preview {
    let store = PresetStore()
    return ScrollView {
        PresetsView(
            store: store,
            params: .constant(.defaults),
            selectedQRPreset: .constant(nil)
        )
        .padding(.horizontal, 12)
        .padding(.top, 10)
    }
}
