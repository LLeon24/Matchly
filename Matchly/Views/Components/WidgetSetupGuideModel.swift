//
//  WidgetSetupGuideModel.swift
//  Matchly
//

import Combine
import SwiftUI

@MainActor
final class WidgetSetupGuideModel: ObservableObject {
    @Published var widgetAlreadyAdded = false
    @Published var checkedForWidget = false
    @Published var isCheckingWidget = false
    private var checkTask: Task<Void, Never>?

    func checkForWidget() {
        guard !isCheckingWidget else { return }
        checkTask?.cancel()
        checkedForWidget = true
        isCheckingWidget = true

        checkTask = Task {
            defer {
                isCheckingWidget = false
            }
            let installed = await WidgetInstallationChecker.isMatchlyWidgetInstalled()
            guard !Task.isCancelled else { return }
            widgetAlreadyAdded = installed
        }
    }

    func cancelInFlightCheck() {
        checkTask?.cancel()
        checkTask = nil
    }
}
