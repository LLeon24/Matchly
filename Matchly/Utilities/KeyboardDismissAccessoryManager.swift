//
//  KeyboardDismissAccessoryManager.swift
//  Matchly
//
//  Shows a global Done bar above the keyboard for SwiftUI and UIKit text inputs.
//

import UIKit

enum KeyboardDismissAccessoryManager {
    private static let barTag = 991_002
    private static var isInstalled = false
    private static weak var windowBarContainer: UIView?

    static func installIfNeeded() {
        guard !isInstalled else { return }
        isInstalled = true

        NotificationCenter.default.addObserver(
            forName: UIResponder.keyboardWillShowNotification,
            object: nil,
            queue: .main
        ) { notification in
            showWindowBar(for: notification)
        }

        NotificationCenter.default.addObserver(
            forName: UIResponder.keyboardWillChangeFrameNotification,
            object: nil,
            queue: .main
        ) { notification in
            repositionWindowBar(for: notification)
        }

        NotificationCenter.default.addObserver(
            forName: UIResponder.keyboardWillHideNotification,
            object: nil,
            queue: .main
        ) { _ in
            hideWindowBar()
        }
    }

    private static func showWindowBar(for notification: Notification) {
        guard let window = activeKeyWindow,
              let keyboardFrame = keyboardEndFrame(from: notification) else { return }

        let container = windowBarContainer ?? makeWindowBarContainer()
        windowBarContainer = container

        if container.superview !== window {
            window.addSubview(container)
        }

        container.isHidden = false
        window.bringSubviewToFront(container)
        animateWindowBar(to: keyboardFrame, in: window, notification: notification)
    }

    private static func repositionWindowBar(for notification: Notification) {
        guard let window = activeKeyWindow,
              let container = windowBarContainer,
              !container.isHidden,
              let keyboardFrame = keyboardEndFrame(from: notification) else { return }

        animateWindowBar(to: keyboardFrame, in: window, notification: notification)
    }

    private static func hideWindowBar() {
        windowBarContainer?.isHidden = true
    }

    private static func animateWindowBar(to keyboardFrame: CGRect, in window: UIWindow, notification: Notification) {
        let targetFrame = windowBarFrame(for: keyboardFrame, in: window)
        guard let container = windowBarContainer else { return }

        if let duration = notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double {
            let curveRaw = notification.userInfo?[UIResponder.keyboardAnimationCurveUserInfoKey] as? UInt ?? 7
            let options = UIView.AnimationOptions(rawValue: curveRaw << 16)
            UIView.animate(withDuration: duration, delay: 0, options: options) {
                container.frame = targetFrame
            }
        } else {
            container.frame = targetFrame
        }
    }

    private static func makeWindowBarContainer() -> UIView {
        let container = UIView()
        container.tag = barTag
        container.backgroundColor = .systemBackground
        container.layer.shadowColor = UIColor.black.cgColor
        container.layer.shadowOpacity = 0.08
        container.layer.shadowRadius = 4
        container.layer.shadowOffset = CGSize(width: 0, height: -1)

        let topBorder = UIView()
        topBorder.backgroundColor = .separator
        topBorder.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(topBorder)

        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setTitle("Done", for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 17, weight: .semibold)
        button.addTarget(KeyboardDismissTarget.shared, action: #selector(KeyboardDismissTarget.dismissKeyboard), for: .touchUpInside)
        button.accessibilityLabel = "Hide keyboard"
        container.addSubview(button)

        NSLayoutConstraint.activate([
            topBorder.topAnchor.constraint(equalTo: container.topAnchor),
            topBorder.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            topBorder.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            topBorder.heightAnchor.constraint(equalToConstant: 0.5),
            button.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),
            button.centerYAnchor.constraint(equalTo: container.centerYAnchor)
        ])

        return container
    }

    private static func windowBarFrame(for keyboardFrame: CGRect, in window: UIWindow) -> CGRect {
        let convertedKeyboard: CGRect
        if let coordinateSpace = window.windowScene?.coordinateSpace {
            convertedKeyboard = window.convert(keyboardFrame, from: coordinateSpace)
        } else {
            convertedKeyboard = keyboardFrame
        }
        let height: CGFloat = 44
        return CGRect(
            x: 0,
            y: convertedKeyboard.minY - height,
            width: window.bounds.width,
            height: height
        )
    }

    private static func keyboardEndFrame(from notification: Notification) -> CGRect? {
        guard let frame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect,
              frame.height > 0 else {
            return nil
        }
        return frame
    }

    private static var activeKeyWindow: UIWindow? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first(where: \.isKeyWindow)
    }
}

@objc private final class KeyboardDismissTarget: NSObject {
    static let shared = KeyboardDismissTarget()

    @objc func dismissKeyboard() {
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil,
            from: nil,
            for: nil
        )
    }
}
