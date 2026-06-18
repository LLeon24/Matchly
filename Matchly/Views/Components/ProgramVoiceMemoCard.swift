//
//  ProgramVoiceMemoCard.swift
//  Matchly
//
//  Recording temporarily disabled to isolate AVAudioSession hang warnings.
//  Playback + delete remain for existing memos. Re-enable recording when warnings are cleared.
//

import SwiftUI
import Combine
import AVFoundation

private final class ProgramAudioPlayer: NSObject, ObservableObject, AVAudioPlayerDelegate {
    @Published var isPlaying = false
    @Published var currentTime: TimeInterval = 0
    @Published var duration: TimeInterval = 0

    private var player: AVAudioPlayer?
    private var progressTimer: DispatchSourceTimer?

    func setDurationHint(_ duration: TimeInterval) {
        if player == nil {
            self.duration = duration
        }
    }

    func reset() async {
        await AudioSessionManager.runVoid {
            self.progressTimer?.cancel()
            self.progressTimer = nil
            self.player?.stop()
            self.player = nil
        }
        await MainActor.run {
            isPlaying = false
            currentTime = 0
            duration = 0
        }
    }

    func togglePlayback(for url: URL) {
        Task {
            if await MainActor.run(body: { isPlaying }) {
                await pause()
                return
            }

            do {
                try await AudioSessionManager.run {
                    if self.player == nil {
                        let session = AVAudioSession.sharedInstance()
                        try session.setCategory(.playback, mode: .default)
                        let loadedPlayer = try AVAudioPlayer(contentsOf: url)
                        loadedPlayer.delegate = self
                        loadedPlayer.prepareToPlay()
                        self.player = loadedPlayer
                    }

                    guard let player = self.player, player.play() else {
                        throw AudioSessionError.playbackFailed
                    }

                    self.startProgressTimer(for: player)
                }

                let loadedDuration = try await AudioSessionManager.run {
                    self.player?.duration ?? 0
                }

                await MainActor.run {
                    if loadedDuration > 0 {
                        duration = loadedDuration
                    }
                    isPlaying = true
                }
            } catch {
                await MainActor.run { isPlaying = false }
            }
        }
    }

    func pause() async {
        await AudioSessionManager.runVoid {
            self.progressTimer?.cancel()
            self.progressTimer = nil
            self.player?.pause()
        }
        await MainActor.run { isPlaying = false }
    }

    func stop() async {
        await reset()
    }

    func seek(to time: TimeInterval) {
        Task {
            await AudioSessionManager.runVoid {
                self.player?.currentTime = time
            }
            await MainActor.run { currentTime = time }
        }
    }

    private func startProgressTimer(for player: AVAudioPlayer) {
        progressTimer?.cancel()
        let timer = DispatchSource.makeTimerSource(queue: AudioSessionManager.queue)
        timer.schedule(deadline: .now(), repeating: 0.1)
        timer.setEventHandler { [weak self, weak player] in
            guard let self, let player else { return }
            let time = player.currentTime
            Task { @MainActor in
                self.currentTime = time
            }
        }
        progressTimer = timer
        timer.resume()
    }

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task {
            await AudioSessionManager.runVoid {
                self.progressTimer?.cancel()
                self.progressTimer = nil
            }
            await MainActor.run {
                isPlaying = false
                currentTime = 0
            }
        }
    }

    func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

struct ProgramVoiceMemoCard: View {
    let programId: String
    var onMemoChanged: () -> Void = {}

    @StateObject private var player = ProgramAudioPlayer()
    @State private var hasMemo = false

    private var memoURL: URL {
        VoiceMemoStorage.fileURL(forProgramId: programId)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "mic.fill")
                    .font(.arial(size: 14))
                    .foregroundColor(.blue)
                Text("Voice Memo")
                    .font(.arial(size: 18, weight: .semibold))
                Spacer()
                Text("Playback only")
                    .font(.arial(size: 11))
                    .foregroundColor(.secondary)
            }

            Text("Recording is temporarily off while we fix audio session warnings. Existing memos can still be played or deleted.")
                .font(.arial(size: 13))
                .foregroundColor(.secondary)

            if hasMemo {
                playbackRow
            } else {
                idleRow
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .onAppear {
            Task { await refreshMemoState() }
        }
        .onChange(of: programId) { _, _ in
            Task {
                await player.stop()
                await refreshMemoState()
            }
        }
    }

    private var playbackRow: some View {
        VStack(spacing: 10) {
            HStack(spacing: 12) {
                Button {
                    player.togglePlayback(for: memoURL)
                } label: {
                    Image(systemName: player.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 36))
                        .foregroundColor(.blue)
                }
                .buttonStyle(.plain)

                VStack(alignment: .leading, spacing: 4) {
                    if player.duration > 0 {
                        Slider(value: Binding(
                            get: { player.currentTime },
                            set: { player.seek(to: $0) }
                        ), in: 0...max(player.duration, 0.1))
                        HStack {
                            Text(player.formatTime(player.currentTime))
                            Spacer()
                            Text(player.formatTime(player.duration))
                        }
                        .font(.arial(size: 11))
                        .foregroundColor(.secondary)
                        .monospacedDigit()
                    } else {
                        Text("Voice memo saved")
                            .font(.arial(size: 14))
                            .foregroundColor(.secondary)
                    }
                }
            }

            HStack {
                Spacer()
                Button("Delete", role: .destructive) {
                    Task {
                        await player.stop()
                        VoiceMemoStorage.deleteMemo(forProgramId: programId)
                        hasMemo = false
                        onMemoChanged()
                    }
                }
                .font(.arial(size: 13, weight: .medium))
                .foregroundColor(.red)
            }
        }
        .padding(12)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var idleRow: some View {
        HStack {
            Text("No voice memo on this device")
                .font(.arial(size: 14))
                .foregroundColor(.secondary)
            Spacer()
        }
        .padding(12)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func refreshMemoState() async {
        await player.reset()
        let memoExists = VoiceMemoStorage.hasMemo(forProgramId: programId)
        await MainActor.run { hasMemo = memoExists }
        guard memoExists else { return }
        let memoDuration = await VoiceMemoStorage.duration(of: memoURL)
        await MainActor.run {
            player.setDurationHint(memoDuration)
        }
    }
}
