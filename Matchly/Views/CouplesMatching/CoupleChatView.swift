//
//  CoupleChatView.swift
//  Matchly
//

import SwiftUI

struct CoupleChatView: View {
    @EnvironmentObject var dataManager: DataManager
    @Environment(\.matchlyLayout) private var layout
    @ObservedObject private var authManager = AuthManager.shared

    let couple: Couple
    var embeddedInHub: Bool = false

    /// Prefer the live couple from preferences so chat stays on the shared CloudKit couple ID
    /// after registration repair (the struct passed from the parent can be stale).
    private var activeCoupleID: String {
        dataManager.preferences.couple?.id ?? couple.id
    }

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
        Group {
            if !authManager.isCloudKitAvailable {
                ContentUnavailableView {
                    Label("iCloud Required", systemImage: "icloud.slash")
                } description: {
                    Text(authManager.cloudUnavailableMessage ?? "Sign in to iCloud to message your partner.")
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
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
                        .frame(maxWidth: .infinity)
                    }
                    .onChange(of: messages.count) { _, _ in
                        if let last = messages.last {
                            withAnimation {
                                proxy.scrollTo(last.id, anchor: .bottom)
                            }
                        }
                    }
                }
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    messageComposer
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .navigationTitle(embeddedInHub ? "" : "Partner Chat")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: activeCoupleID) {
            await CoupleSyncCoordinator.shared.ensureSyncStarted(dataManager: dataManager)
            await refreshMessages()
            await pollMessagesWhileVisible()
        }
        .refreshable {
            await refreshMessages()
        }
        .onReceive(NotificationCenter.default.publisher(for: .coupleMessageDidArrive)) { _ in
            Task { await refreshMessages() }
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

    private var messageComposer: some View {
        let canSend = !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isSending

        return HStack(alignment: .bottom, spacing: 10) {
            TextField("Message your partner…", text: $draft, axis: .vertical)
                .lineLimit(1...6)
                .font(.arial(size: 16))
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .focused($isInputFocused)
                .glassEffect(.regular, in: .rect(cornerRadius: 22))

            Button(action: sendMessage) {
                Group {
                    if isSending {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Image(systemName: "arrow.up")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
                .frame(width: 34, height: 34)
                .background(
                    Circle()
                        .fill(canSend ? AppColors.primaryBlue : Color(.systemGray3))
                )
            }
            .disabled(!canSend)
            .animation(.easeInOut(duration: 0.15), value: canSend)
        }
        .padding(.horizontal, 12)
        .padding(.top, 10)
        .padding(.bottom, isInputFocused ? 8 : layout.tabBarScrollClearance)
        .animation(.easeInOut(duration: 0.25), value: isInputFocused)
        .background {
            Rectangle()
                .fill(.ultraThinMaterial)
                .overlay(alignment: .top) {
                    Divider()
                }
        }
    }

    private func refreshMessages(silent: Bool = false) async {
        if !silent { isLoading = true }
        defer { if !silent { isLoading = false } }
        do {
            messages = try await CoupleMessageService.fetchMessages(coupleID: activeCoupleID)
        } catch {
            errorMessage = CoupleMessageService.userFacingMessage(for: error)
        }
    }

    private func pollMessagesWhileVisible() async {
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(5))
            await refreshMessages(silent: true)
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
                    coupleID: activeCoupleID,
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
                errorMessage = CoupleMessageService.userFacingMessage(for: error)
            }
        }
    }
}

private struct CoupleMessageBubble: View {
    let message: CoupleMessage

    var body: some View {
        HStack(alignment: .bottom, spacing: 0) {
            if message.isFromCurrentUser { Spacer(minLength: 48) }

            VStack(alignment: message.isFromCurrentUser ? .trailing : .leading, spacing: 4) {
                if !message.isFromCurrentUser {
                    Text(message.senderName)
                        .font(.arial(size: 11, weight: .semibold))
                        .foregroundColor(.secondary)
                        .padding(.leading, 4)
                }

                Text(message.text)
                    .font(.arial(size: 16))
                    .foregroundColor(message.isFromCurrentUser ? .white : .primary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 9)
                    .background {
                        bubbleShape(isFromCurrentUser: message.isFromCurrentUser)
                            .fill(message.isFromCurrentUser ? AppColors.primaryBlue : Color(.systemGray5))
                    }

                Text(message.sentAt, style: .time)
                    .font(.arial(size: 10))
                    .foregroundColor(.secondary)
                    .padding(message.isFromCurrentUser ? .trailing : .leading, 4)
            }

            if !message.isFromCurrentUser { Spacer(minLength: 48) }
        }
    }

    private func bubbleShape(isFromCurrentUser: Bool) -> UnevenRoundedRectangle {
        if isFromCurrentUser {
            return UnevenRoundedRectangle(
                topLeadingRadius: 20,
                bottomLeadingRadius: 20,
                bottomTrailingRadius: 6,
                topTrailingRadius: 20,
                style: .continuous
            )
        }

        return UnevenRoundedRectangle(
            topLeadingRadius: 20,
            bottomLeadingRadius: 6,
            bottomTrailingRadius: 20,
            topTrailingRadius: 20,
            style: .continuous
        )
    }
}
