// CharacterPickerView.swift
// Sidebar section for choosing a character or adding one from a photo.

import SwiftUI

struct CharacterPickerView: View {
    let skins: [CharacterSkin]
    @Binding var selectedSkin: CharacterSkin
    let onAddPhoto: () -> Void

    var body: some View {
        CollapsibleSection(title: "Characters", icon: "person.2.fill",
                           accentColor: SectionTheme.characters, startExpanded: true) {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 48), spacing: 8)], spacing: 8) {
                ForEach(skins) { skin in
                    CharacterButton(skin: skin, isSelected: skin.id == selectedSkin.id) {
                        selectedSkin = skin
                    }
                }

                Button(action: onAddPhoto) {
                    CharacterTile(isSelected: false) {
                        Image(systemName: "camera.fill")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.secondary)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Add character from photo")
            }
            .padding(.horizontal, 12)
            .padding(.top, 2)
            .padding(.bottom, 12)
        }
    }
}

private struct CharacterTile<Icon: View>: View {
    let isSelected: Bool
    @ViewBuilder let icon: () -> Icon

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(isSelected ? SectionTheme.characters.opacity(0.25) : Color(.tertiarySystemFill))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isSelected ? SectionTheme.characters : Color.clear, lineWidth: 1.5)
                )
            icon()
        }
        .frame(width: 48, height: 48)
    }
}

private struct CharacterButton: View {
    let skin: CharacterSkin
    let isSelected: Bool
    let action: () -> Void

    @State private var thumbnail: UIImage?

    var body: some View {
        Button(action: action) {
            CharacterTile(isSelected: isSelected) {
                if let thumbnail {
                    Image(uiImage: thumbnail)
                        .resizable()
                        .scaledToFit()
                        .padding(5)
                } else {
                    Text(String(skin.name.prefix(1)).uppercased())
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.primary)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(skin.name)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .task(id: skin.id) { thumbnail = skin.makeThumbnail() }
    }
}
