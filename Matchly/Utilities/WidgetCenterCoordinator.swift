//
//  WidgetCenterCoordinator.swift
//  Matchly
//
//  Serializes WidgetKit API use — concurrent reloadTimelines + getCurrentConfigurations
//  has been observed to crash release builds on device.
//

import Foundation
import WidgetKit

enum WidgetCenterCoordinator {
    private static let syncQueue = DispatchQueue(label: "com.lestarlu.matchly.widget-center")
    private static let configurationWaitSeconds: TimeInterval = 10

    /// Schedules a timeline reload without blocking the caller.
    static func scheduleReloadTimelines(ofKind kind: String) {
        syncQueue.async {
            runOnMainSync {
                WidgetCenter.shared.reloadTimelines(ofKind: kind)
            }
        }
    }

    static func isMatchlyWidgetInstalled(kind: String) async -> Bool {
        await withCheckedContinuation { continuation in
            let resumeOnce = ResumeOnce(continuation)
            syncQueue.async {
                var installed = false
                let semaphore = DispatchSemaphore(value: 0)

                runOnMainAsync {
                    WidgetCenter.shared.getCurrentConfigurations { @Sendable result in
                        if case .success(let configurations) = result {
                            installed = configurations.contains { $0.kind == kind }
                        }
                        semaphore.signal()
                    }
                }

                let waitResult = semaphore.wait(timeout: .now() + configurationWaitSeconds)
                if waitResult == .timedOut {
                    installed = false
                }
                resumeOnce.resume(returning: installed)
            }
        }
    }

    private static func runOnMainSync(_ work: @escaping () -> Void) {
        if Thread.isMainThread {
            work()
        } else {
            DispatchQueue.main.sync(execute: work)
        }
    }

    private static func runOnMainAsync(_ work: @escaping () -> Void) {
        if Thread.isMainThread {
            work()
        } else {
            DispatchQueue.main.async(execute: work)
        }
    }
}

private final class ResumeOnce: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<Bool, Never>?

    init(_ continuation: CheckedContinuation<Bool, Never>) {
        self.continuation = continuation
    }

    func resume(returning value: Bool) {
        lock.lock()
        guard let continuation else {
            lock.unlock()
            return
        }
        self.continuation = nil
        lock.unlock()
        continuation.resume(returning: value)
    }
}
