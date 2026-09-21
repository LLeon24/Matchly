//
//  WidgetInstallationChecker.swift
//  Matchly
//

enum WidgetInstallationChecker {
    static func isMatchlyWidgetInstalled() async -> Bool {
        await WidgetCenterCoordinator.isMatchlyWidgetInstalled(kind: DataManager.widgetKind)
    }
}
