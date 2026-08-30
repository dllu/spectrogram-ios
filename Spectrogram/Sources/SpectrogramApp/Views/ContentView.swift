import SwiftUI
import UIKit

struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.openURL) private var openURL
    @StateObject private var session = SpectrogramSession()

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                ControlBar(session: session)

                SpectrogramPane(session: session)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                if let selection = session.selection {
                    SpectrumDetailView(session: session, selection: selection)
                        .frame(height: min(max(240, geometry.size.height * 0.38), 340))
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                if session.phase == .permissionDenied {
                    Button("Open Settings") {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            openURL(url)
                        }
                    }
                    .font(.subheadline.weight(.semibold))
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity)
                    .background(.bar)
                }
            }
        }
        .background(.black)
        .preferredColorScheme(.dark)
        .animation(.easeInOut(duration: 0.2), value: session.selection?.id)
        .onAppear {
            session.startIfNeeded()
        }
        .onChange(of: scenePhase) { newPhase in
            session.handleSceneActive(newPhase == .active)
        }
    }
}
