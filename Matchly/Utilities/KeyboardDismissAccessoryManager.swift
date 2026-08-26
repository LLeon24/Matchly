//
//  KeyboardDismissAccessoryManager.swift
//  Matchly
//
//  Attaches a Done accessory bar above the keyboard for every text field / text view.
//

import UIKit

enum KeyboardDismissAccessoryManager {
    private static let toolbarTag = 991_002
    private static var isInstalled = false

    static func installIfNeeded() {
        guard !isInstalled else { return }
        isInstalled = true

        NotificationCenter.default.addObserver(
            forName: UITextField.textDidBeginEditingNotification,
            object: nil,
            queue: .main
        ) { notification in
            guard let field = notification.object as? UITextField else { return }
            DispatchQueue.main.async {
                attachToolbar(to: field)
            }
        }

        NotificationCenter.default.addObserver(
            forName: UITextView.textDidBeginEditingNotification,
            object: nil,
            queue: .main
        ) { notification in
            guard let textView = notification.object as? UITextView else { return }
            DispatchQueue.main.async {
                attachToolbar(to: textView)
            }
        }
    }

    private static func attachToolbar(to field: UITextField) {
        if field.inputAccessoryView?.tag == toolbarTag { return }
        field.inputAccessoryView = makeToolbar()
    }

    private static func attachToolbar(to textView: UITextView) {
        if textView.inputAccessoryView?.tag == toolbarTag { return }
        textView.inputAccessoryView = makeToolbar()
    }

    private static func makeToolbar() -> UIToolbar {
        let toolbar = UIToolbar()
        toolbar.tag = toolbarTag
        toolbar.sizeToFit()

        let previous = UIBarButtonItem(
            image: UIImage(systemName: "chevron.up"),
            style: .plain,
            target: nil,
            action: NSSelectorFromString("selectPrevious:")
        )
        previous.accessibilityLabel = "Previous field"

        let next = UIBarButtonItem(
            image: UIImage(systemName: "chevron.down"),
            style: .plain,
            target: nil,
            action: NSSelectorFromString("selectNext:")
        )
        next.accessibilityLabel = "Next field"

        let flex = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        let done = UIBarButtonItem(
            image: UIImage(systemName: "checkmark"),
            style: .done,
            target: KeyboardDismissTarget.shared,
            action: #selector(KeyboardDismissTarget.dismissKeyboard)
        )
        done.accessibilityLabel = "Hide keyboard"
        toolbar.items = [previous, next, flex, done]
        return toolbar
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
