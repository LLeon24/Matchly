//
//  CoupleInviteQRSheet.swift
//  Matchly
//

import SwiftUI

struct CoupleInviteQRSheet: View {
    let couple: Couple
    let inviterName: String
    @Environment(\.dismiss) private var dismiss

    private var inviteURL: URL? {
        Couple.inviteURL(for: couple.coupleCode)
    }

    private var shareMessage: String {
        Couple.shareInviteMessage(code: couple.coupleCode, inviterName: inviterName)
    }

    var body: some View {
        MatchlyNavigationView {
            VStack(spacing: 24) {
                Text("Have your partner open Matchly and tap Scan Partner's QR")
                    .font(.arial(size: 15))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 8)

                CoupleQRCodeView(code: couple.coupleCode)

                VStack(spacing: 12) {
                    if let inviteURL {
                        ShareLink(
                            item: inviteURL,
                            subject: Text(Couple.shareInviteSubject(inviterName: inviterName)),
                            message: Text(shareMessage)
                        ) {
                            HStack {
                                Spacer()
                                Image(systemName: "message.fill")
                                Text("Send Invite via Text")
                                Spacer()
                            }
                        }
                        .buttonStyle(.glassProminent)
                        .tint(AppColors.primaryBlue)
                    }

                    Button(action: {
                        UIPasteboard.general.string = couple.coupleCode
                    }) {
                        HStack {
                            Spacer()
                            Image(systemName: "doc.on.doc")
                            Text("Copy Code")
                            Spacer()
                        }
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(AppColors.primaryBlue)
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .appCanvasBackground()
            .navigationTitle("Your QR Code")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
