//
//  MatchlyDevLauncher.swift
//  Matchly
//
//  DEBUG-only helpers for switching between onboarding, auth, and the full app.
//

#if DEBUG
import SwiftUI

enum MatchlyDevLauncher {
    static let storageKey = "MatchlyDevLauncher.screen"

    enum Screen: String, CaseIterable, Identifiable {
        case automatic = "automatic"
        case onboarding = "onboarding"
        case mainApp = "mainApp"
        case auth = "auth"

        var id: String { rawValue }

        var label: String {
            switch self {
            case .automatic: return "Auto"
            case .onboarding: return "Onboarding"
            case .mainApp: return "Full App"
            case .auth: return "Sign In"
            }
        }
    }

    static func applyLaunchArgumentsIfNeeded() {
        let args = ProcessInfo.processInfo.arguments
        guard let index = args.firstIndex(of: "-MatchlyDevScreen"),
              index + 1 < args.count,
              let screen = Screen(rawValue: args[index + 1]) else { return }
        UserDefaults.standard.set(screen.rawValue, forKey: storageKey)
    }
}

struct MatchlyDevScreenPicker: View {
    @AppStorage(MatchlyDevLauncher.storageKey) private var devScreenRaw = MatchlyDevLauncher.Screen.automatic.rawValue

    private var selection: MatchlyDevLauncher.Screen {
        MatchlyDevLauncher.Screen(rawValue: devScreenRaw) ?? .automatic
    }

    var body: some View {
        VStack(spacing: 4) {
            Text("Dev Screen")
                .font(.arial(size: 10, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            Picker("Dev Screen", selection: Binding(
                get: { selection },
                set: { devScreenRaw = $0.rawValue }
            )) {
                ForEach(MatchlyDevLauncher.Screen.allCases) { screen in
                    Text(screen.label).tag(screen)
                }
            }
            .pickerStyle(.segmented)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .padding(.horizontal, 12)
        .padding(.top, 8)
    }
}
#endif
