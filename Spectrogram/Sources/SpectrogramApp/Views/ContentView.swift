import SpectrogramCore
import SwiftUI
import UIKit

struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.openURL) private var openURL
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @StateObject private var session = SpectrogramSession()

    private var displayRange: FrequencyRange {
        session.frequencyRange.limited(to: session.history.latest()?.nyquistFrequency ?? 24_000)
    }

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                ControlBar(session: session)

                FrequencyAxisOverlay(
                    minimumFrequency: displayRange.minimum,
                    maximumFrequency: displayRange.maximum
                )

                SpectrogramPane(session: session)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                if let selection = session.selection {
                    SpectrumDetailView(session: session, selection: selection)
                        .frame(height: min(340, max(195, geometry.size.height * (geometry.size.width > geometry.size.height ? 0.55 : 0.38))))
                        .padding(.bottom, geometry.safeAreaInsets.bottom)
                        .background(Color(uiColor: .secondarySystemBackground))
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
                    .padding(.bottom, geometry.safeAreaInsets.bottom)
                    .background(.bar)
                }
            }
            .ignoresSafeArea(.container, edges: .bottom)
        }
        .background(.black)
        .preferredColorScheme(.dark)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: session.selection?.id)
        .onAppear {
            session.startIfNeeded()
        }
        .modifier(SceneActivityObserver(phase: scenePhase, session: session))
    }
}

private struct SceneActivityObserver: ViewModifier {
    let phase: ScenePhase
    let session: SpectrogramSession

    @ViewBuilder func body(content: Content) -> some View {
        if #available(iOS 17.0, *) {
            content.onChange(of: phase) { _, newPhase in
                session.handleSceneActive(newPhase == .active)
            }
        } else {
            legacyBody(content: content)
        }
    }

    @available(iOS, introduced: 16.0, deprecated: 17.0)
    private func legacyBody(content: Content) -> some View {
        content.onChange(of: phase) { newPhase in
            session.handleSceneActive(newPhase == .active)
        }
    }
}
