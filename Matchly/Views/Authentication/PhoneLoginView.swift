//
//  PhoneLoginView.swift
//  Matchly
//
//  Created on 11/16/25.
//

import SwiftUI

struct PhoneLoginView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var authManager = AuthManager.shared
    @State private var phoneNumber = ""
    @State private var verificationCode = ""
    @State private var isCodeSent = false
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    if !isCodeSent {
                        TextField("Phone Number", text: $phoneNumber)
                            .textContentType(.telephoneNumber)
                            .keyboardType(.phonePad)
                            .onChange(of: phoneNumber) { oldValue, newValue in
                                // Format phone number
                                phoneNumber = formatPhoneNumber(newValue)
                            }
                    } else {
                        Text(phoneNumber)
                            .foregroundColor(.secondary)
                        
                        TextField("Verification Code", text: $verificationCode)
                            .textContentType(.oneTimeCode)
                            .keyboardType(.numberPad)
                    }
                } header: {
                    Text(isCodeSent ? "Enter Verification Code" : "Phone Number")
                } footer: {
                    if let error = errorMessage {
                        Text(error)
                            .foregroundColor(.red)
                    } else if isCodeSent {
                        Text("We've sent a verification code to \(phoneNumber)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Section {
                    Button(action: {
                        Task {
                            if isCodeSent {
                                await verifyCode()
                            } else {
                                await sendCode()
                            }
                        }
                    }) {
                        HStack {
                            Spacer()
                            if isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle())
                            } else {
                                Text(isCodeSent ? "Verify Code" : "Send Code")
                                    .fontWeight(.semibold)
                            }
                            Spacer()
                        }
                    }
                    .disabled(isLoading || phoneNumber.isEmpty || (isCodeSent && verificationCode.isEmpty))
                    
                    if isCodeSent {
                        Button(action: {
                            isCodeSent = false
                            verificationCode = ""
                        }) {
                            Text("Change Phone Number")
                                .foregroundColor(.blue)
                        }
                    }
                }
            }
            .navigationTitle("Phone Sign In")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func formatPhoneNumber(_ number: String) -> String {
        let cleaned = number.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
        if cleaned.count <= 3 {
            return cleaned
        } else if cleaned.count <= 6 {
            return "(\(cleaned.prefix(3))) \(cleaned.dropFirst(3))"
        } else {
            return "(\(cleaned.prefix(3))) \(cleaned.dropFirst(3).prefix(3))-\(cleaned.dropFirst(6))"
        }
    }
    
    private func sendCode() async {
        isLoading = true
        errorMessage = nil
        
        let cleaned = phoneNumber.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
        guard cleaned.count == 10 else {
            errorMessage = "Please enter a valid 10-digit phone number."
            isLoading = false
            return
        }
        
        do {
            try await authManager.signInWithPhone(phoneNumber: phoneNumber)
            await MainActor.run {
                isCodeSent = true
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    private func verifyCode() async {
        isLoading = true
        errorMessage = nil
        
        guard verificationCode.count == 6 else {
            errorMessage = "Please enter the 6-digit verification code."
            isLoading = false
            return
        }
        
        do {
            try await authManager.verifyPhoneCode(code: verificationCode)
            await MainActor.run {
                dismiss()
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
}

#Preview {
    PhoneLoginView()
}

