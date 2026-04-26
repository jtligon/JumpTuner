// ContentView.swift

import SwiftUI

struct ContentView: View {
    @StateObject private var store      = PresetStore()
    @State private var params           = JumpParams()
    @State private var selectedQRPreset: Preset?
    @State private var drawerOpen       = true
    @State private var showHelp         = false

    private let drawerWidth: CGFloat = 280

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .trailing) {

                // Full-screen preview — always fills the whole screen
                JumpPreviewView(params: $params)
                    .ignoresSafeArea()

                // Tab to open/close the drawer, pinned to the right edge
                // when the drawer is closed, left edge of drawer when open
                VStack {
                    Spacer()
                    Button {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            drawerOpen.toggle()
                        }
                    } label: {
                        ZStack {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(.ultraThinMaterial)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(Color.white.opacity(0.25), lineWidth: 1)
                                )
                                .frame(width: 28, height: 56)
                            Image(systemName: drawerOpen ? "chevron.right" : "chevron.left")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.white.opacity(0.8))
                        }
                    }
                    .buttonStyle(.plain)
                    .offset(x: drawerOpen ? -(drawerWidth) : 0)
                    Spacer()
                }
                .zIndex(10)

                // Side drawer
                VStack(spacing: 0) {
                    // Header
                    HStack {
                        Text("Jump Tuner")
                            .font(.system(size: 16, weight: .bold))
                        Spacer()
                        Button {
                            params = JumpParams.randomized()
                        } label: {
                            Image(systemName: "dice")
                                .font(.system(size: 14, weight: .semibold))
                                .frame(width: 30, height: 30)
                                .background(Color(.tertiarySystemFill))
                                .clipShape(Circle())
                        }
                        Button {
                            params = JumpParams.defaults
                        } label: {
                            Image(systemName: "arrow.counterclockwise")
                                .font(.system(size: 14, weight: .semibold))
                                .frame(width: 30, height: 30)
                                .background(Color(.tertiarySystemFill))
                                .clipShape(Circle())
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.top, 56)   // below status bar
                    .padding(.bottom, 10)

                    Divider()

                    ScrollView {
                        VStack(spacing: 8) {
                            ParamsEditorView(params: $params)
                            PresetsView(
                                store: store,
                                params: $params,
                                selectedQRPreset: $selectedQRPreset
                            )
                            Spacer(minLength: 20)
                        }
                        .padding(.horizontal, 10)
                        .padding(.top, 10)
                        .padding(.bottom, 40)
                    }
                }
                .frame(width: drawerWidth)
                .background(.ultraThinMaterial)
                .offset(x: drawerOpen ? 0 : drawerWidth)
            }
        }
        .ignoresSafeArea()
        .sheet(item: $selectedQRPreset) { preset in
            PresetQRView(preset: preset)
        }
        .sheet(isPresented: $showHelp) {
            HelpView()
        }
    }
}

#Preview {
    ContentView()
        .ignoresSafeArea()
}
