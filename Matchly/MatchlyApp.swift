//
//  MatchlyApp.swift
//  Matchly
//
//  Created by Leoh N. Leon II on 11/14/25.
//

import SwiftUI
import Combine

@main
struct MatchlyApp: App {
    @StateObject private var deepLinkHandler = CoupleDeepLinkHandler()

    var body: some Scene {
        WindowGroup {
            SplashView()
                .arialFont()
                .environmentObject(deepLinkHandler)
                .onOpenURL { url in
                    deepLinkHandler.handle(url: url)
                }
        }
    }
}

final class CoupleDeepLinkHandler: ObservableObject {
    @Published var pendingCoupleCode: String?

    func handle(url: URL) {
        if let code = Couple.parseLinkPayload(url.absoluteString) {
            pendingCoupleCode = code
        }
    }
}
