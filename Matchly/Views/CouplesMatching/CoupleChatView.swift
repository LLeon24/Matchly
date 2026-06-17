//
//  CoupleChatView.swift
//  Matchly
//

import SwiftUI

struct CoupleChatView: View {
    @EnvironmentObject var dataManager: DataManager
    @ObservedObject private var authManager = AuthManager.shared

    let couple: Couple

    @State private var messages: [CoupleMessage] = []
    @State private var draft = ""
    @State private var isLoading = false
    @State private var isSending = false
    @State private var errorMessage: String?
    @FocusState private var isInputFocused: Bool

    private var senderRecordName: String? {
        authManager.cloudKitUserRecordName
    }

    private var senderName: String {
        authManager.currentUser?.displayName
            ?? (dataManager.preferences.profile.name.isEmpty ? "You" : dataManager.preferences.profile.name)
    }

    var body: some View {
        VStack(spacing: 0) {
            if !authManager.isCloudKitAvailable {
                ContentUnavailableView {
                    Label("iCloud Required", systemImage: "icloud.slash")
                } description: {
                    Text(authManager.cloudUnavailableMessage ?? "Sign in to iCloud to message your partner.")
                }
                .frame(maxHeight: .infinity)
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 10) {
                            if messages.isEmpty && !isLoading {
                                Text("Coordinate interviews, rank-list tradeoffs, and geography here. Messages sync between linked partners.")
                                    .font(.arial(size: 13))
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                                    .padding(.vertical, 24)
                                    .padding(.horizontal, 20)
                            }

                            ForEach(messages) { message in
                                CoupleMessageBubble(message: message)
                                    .id(message.id)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                    }
                    .onChange(of: messages.count) { _, _ in
                        if let last = messages.last {
                            withAnimation {
                                proxy.scrollTo(last.id, anchor: .bottom)
                            }
                        }
                    }
                }

                Divider()

                HStack(spacing: 10) {
                    TextField("Message your partner…", text: $draft, axis: .vertical)
                        .lineLimit(1...4)
                        .font(.arial(size: 15))
                        .focused($isInputFocused)

                    Button(action: sendMessage) {
                        if isSending {
                            ProgressView()
                        } else {
                            Image(systemName: "paperplane.fill")
                                .font(.arial(size: 16, weight: .semibold))
                        }
                    }
                    .disabled(isSending || draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color(.systemBackground))
            }
        }
        .navigationTitle("Partner Chat")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await refreshMessages()
        }
        .refreshable {
            await refreshMessages()
        }
        .alert("Message Error", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private func refreshMessages() async {
        isLoading = true
        defer { isLoading = false }
        do {
            messages = try await CoupleMessageService.fetchMessages(coupleID: couple.id)
        } catch {
            errorMessage = "Could not load messages."
        }
    }

    private func sendMessage() {
        guard let senderRecordName else {
            errorMessage = "Could not verify your iCloud identity."
            return
        }

        isSending = true
        Task { @MainActor in
            defer { isSending = false }
            do {
                let message = try await CoupleMessageService.sendMessage(
                    coupleID: couple.id,
                    senderRecordName: senderRecordName,
                    senderName: senderName,
                    text: draft
                )
                draft = ""
                if !messages.contains(where: { $0.id == message.id }) {
                    messages.append(message)
                }
            } catch let error as CoupleMessageError {
                errorMessage = error.localizedDescription
            } catch {
                errorMessage = "Could not send your message."
            }
        }
    }
}

private struct CoupleMessageBubble: View {
    let message: CoupleMessage

    var body: some View {
        HStack {
            if message.isFromCurrentUser { Spacer(minLength: 40) }

            VStack(alignment: message.isFromCurrentUser ? .trailing : .leading, spacing: 4) {
                if !message.isFromCurrentUser {
                    Text(message.senderName)
                        .font(.arial(size: 11, weight: .semibold))
                        .foregroundColor(.secondary)
                }

                Text(message.text)
                    .font(.arial(size: 15))
                    .foregroundColor(message.isFromCurrentUser ? .white : .primary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(message.isFromCurrentUser ? AppColors.primaryBlue : Color(.systemGray5))
                    )

                Text(message.sentAt, style: .time)
                    .font(.arial(size: 10))
                    .foregroundColor(.secondary)
            }

            if !message.isFromCurrentUser { Spacer(minLength: 40) }
        }
    }
}
