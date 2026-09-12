//
//  ClearableTextField.swift
//  Matchly
//

import SwiftUI

enum ClearableTextFieldNoFocus: Hashable {}

struct ClearableTextFieldRow<F: Hashable>: View {
    let placeholder: String
    @Binding var text: String
    var axis: Axis
    var focus: FocusState<F?>.Binding?
    var focusValue: F?
    var textContentType: UITextContentType?

    init(
        _ placeholder: String,
        text: Binding<String>,
        axis: Axis = .horizontal,
        textContentType: UITextContentType? = nil
    ) where F == ClearableTextFieldNoFocus {
        self.placeholder = placeholder
        self._text = text
        self.axis = axis
        self.focus = nil
        self.focusValue = nil
        self.textContentType = textContentType
    }

    init(
        _ placeholder: String,
        text: Binding<String>,
        axis: Axis = .horizontal,
        focus: FocusState<F?>.Binding,
        equals focusValue: F,
        textContentType: UITextContentType? = nil
    ) {
        self.placeholder = placeholder
        self._text = text
        self.axis = axis
        self.focus = focus
        self.focusValue = focusValue
        self.textContentType = textContentType
    }

    var body: some View {
        HStack(alignment: axis == .vertical ? .top : .center, spacing: 8) {
            field

            if !text.isEmpty {
                Button(action: { text = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.body)
                        .foregroundStyle(.secondary.opacity(0.55))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear text")
                .padding(.top, axis == .vertical ? 2 : 0)
            }
        }
    }

    @ViewBuilder
    private var field: some View {
        if let focus, let focusValue {
            styledField(
                TextField(placeholder, text: $text, axis: axis)
                    .textFieldStyle(.plain)
                    .focused(focus, equals: focusValue)
            )
        } else {
            styledField(
                TextField(placeholder, text: $text, axis: axis)
                    .textFieldStyle(.plain)
            )
        }
    }

    @ViewBuilder
    private func styledField<Content: View>(_ content: Content) -> some View {
        if let textContentType {
            content.textContentType(textContentType)
        } else {
            content
        }
    }
}

typealias ClearableTextField = ClearableTextFieldRow<ClearableTextFieldNoFocus>
