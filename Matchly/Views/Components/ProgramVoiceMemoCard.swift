//
//  ProgramVoiceMemoCard.swift
//  Matchly
//

import SwiftUI
import Combine
import AVFoundation

@MainActor
private final class ProgramAudioRecorder: ObservableObject {
    @Published var isRecording = false
    @Published var isMerging = false
    @Published var recordingTime: TimeInterval = 0
    @Published var existingDuration: TimeInterval = 0
    @Published var permissionDenied = false
    @Published var meterLevels: [CGFloat] = Array(repeating: 0.06, count: 48)

    private var meteringTimer: DispatchSourceTimer?
    private var outputURL: URL?
    private var segmentURL: URL?
    private var isAppending = false
    private var maxSegmentDuration: TimeInterval = VoiceMemoStorage.maxDurationSeconds

    var displayedDuration: TimeInterval {
        existingDuration + recordingTime
    }

    deinit {
        meteringTimer?.cancel()
    }

    func startRecording(to destination: URL, appending: Bool) {
        Task {
            permissionDenied = false
            let programId = destination.deletingPathExtension().lastPathComponent
            isAppending = appending && VoiceMemoStorage.hasMemo(forProgramId: programId)

            if isAppending {
                existingDuration = await VoiceMemoStorage.duration(of: destination)
                maxSegmentDuration = VoiceMemoStorage.remainingDuration(givenExistingDuration: existingDuration)
                guard maxSegmentDuration > 0 else { return }
                outputURL = destination
                segmentURL = FileManager.default.temporaryDirectory
                    .appendingPathComponent("voice-append-\(UUID().uuidString).m4a")
            } else {
                existingDuration = 0
                maxSegmentDuration = VoiceMemoStorage.maxDurationSeconds
                outputURL = destination
                segmentURL = nil
            }

            let granted = await AudioSessionManager.requestRecordPermission()
            guard granted else {
                permissionDenied = true
                return
            }

            let recordURL = isAppending ? segmentURL! : destination
            let deleteExisting = !isAppending
            do {
                try await AudioSessionManager.run {
                    try AudioSessionManager.startRecording(
                        at: recordURL,
                        deleteExisting: deleteExisting
                    )
                }
                recordingTime = 0
                meterLevels = Array(repeating: 0.06, count: 48)
                isRecording = true
                startMetering()
            } catch {
                isRecording = false
            }
        }
    }

    func stopRecording(completion: ((URL?) -> Void)? = nil) {
        Task {
            stopMetering()

            await AudioSessionManager.runVoid {
                AudioSessionManager.stopRecording()
            }

            isRecording = false

            guard let destination = outputURL else {
                resetSessionState()
                completion?(nil)
                return
            }

            if isAppending, let segmentURL, FileManager.default.fileExists(atPath: segmentURL.path) {
                isMerging = true
                do {
                    try await VoiceMemoStorage.mergeAudio(
                        existing: destination,
                        appendSegment: segmentURL,
                        into: destination
                    )
                    try? FileManager.default.removeItem(at: segmentURL)
                    VoiceMemoStorage.invalidateTranscript(
                        forProgramId: destination.deletingPathExtension().lastPathComponent
                    )
                    completion?(destination)
                } catch {
                    try? FileManager.default.removeItem(at: segmentURL)
                    completion?(nil)
                }
                isMerging = false
                resetSessionState()
                return
            }

            completion?(destination)
            resetSessionState()
        }
    }

    private func startMetering() {
        meteringTimer?.cancel()
        let timer = DispatchSource.makeTimerSource(queue: AudioSessionManager.queue)
        timer.schedule(deadline: .now(), repeating: 0.05)
        timer.setEventHandler { [weak self] in
            guard let self else { return }
            let decibels = AudioSessionManager.recordingMeterLevel()
            let level = Self.normalizedLevel(decibels)

            Task { @MainActor in
                self.meterLevels.append(level)
                if self.meterLevels.count > 48 {
                    self.meterLevels.removeFirst()
                }
                self.recordingTime += 0.05
                if self.recordingTime >= self.maxSegmentDuration {
                    self.stopRecording()
                }
            }
        }
        meteringTimer = timer
        timer.resume()
    }

    private func stopMetering() {
        meteringTimer?.cancel()
        meteringTimer = nil
    }

    private func resetSessionState() {
        outputURL = nil
        segmentURL = nil
        isAppending = false
        existingDuration = 0
        maxSegmentDuration = VoiceMemoStorage.maxDurationSeconds
        recordingTime = 0
    }

    private static func normalizedLevel(_ decibels: Float) -> CGFloat {
        let minDb: Float = -55
        let clamped = max(minDb, min(decibels, 0))
        return CGFloat((clamped - minDb) / (-minDb))
    }

    func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

private final class ProgramAudioPlayer: NSObject, ObservableObject, AVAudioPlayerDelegate {
    @Published var isPlaying = false
    @Published var currentTime: TimeInterval = 0
    @Published var duration: TimeInterval = 0
    @Published var playbackRate: Float

    private var progressTimer: DispatchSourceTimer?
    private var stopObserver: AnyCancellable?

    override init() {
        playbackRate = VoiceMemoStorage.preferredPlaybackRate
        super.init()
        stopObserver = NotificationCenter.default.publisher(for: .voiceMemoPlaybackDidStop)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.handleExternalStop()
            }
    }

    private func handleExternalStop() {
        progressTimer?.cancel()
        progressTimer = nil
        isPlaying = false
        currentTime = 0
    }

    func setDurationHint(_ duration: TimeInterval) {
        if !isPlaying {
            self.duration = duration
        }
    }

    func setPlaybackRate(_ rate: Float) {
        playbackRate = rate
        VoiceMemoStorage.preferredPlaybackRate = rate
        Task {
            await AudioSessionManager.runVoid {
                AudioSessionManager.setPlaybackRate(rate)
            }
        }
    }

    func reset() async {
        await AudioSessionManager.runVoid {
            self.progressTimer?.cancel()
            self.progressTimer = nil
            AudioSessionManager.clearPlayer()
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
                let rate = await MainActor.run { self.playbackRate }
                try await AudioSessionManager.run {
                    let player: AVAudioPlayer
                    if let existing = AudioSessionManager.currentPlayer() {
                        player = existing
                        player.enableRate = true
                        player.rate = rate
                    } else {
                        player = try AudioSessionManager.makePlayer(for: url, rate: rate)
                        player.delegate = self
                    }

                    guard player.play() else {
                        throw AudioSessionError.playbackFailed
                    }

                    self.startProgressTimer(for: player)
                }

                let loadedDuration = try await AudioSessionManager.run {
                    AudioSessionManager.currentPlayer()?.duration ?? 0
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
            AudioSessionManager.currentPlayer()?.pause()
        }
        await MainActor.run { isPlaying = false }
    }

    func stop() async {
        await reset()
    }

    func seek(to time: TimeInterval) {
        Task {
            await AudioSessionManager.runVoid {
                AudioSessionManager.currentPlayer()?.currentTime = time
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

private struct LiveAudioWaveformView: View {
    let levels: [CGFloat]

    var body: some View {
        HStack(alignment: .center, spacing: 2) {
            ForEach(Array(levels.enumerated()), id: \.offset) { _, level in
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(Color.red.opacity(0.85))
                    .frame(width: 3, height: max(4, 28 * level))
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 32)
    }
}

struct ProgramVoiceMemoCard: View {
    let programId: String
    var onMemoChanged: () -> Void = {}

    @StateObject private var recorder = ProgramAudioRecorder()
    @StateObject private var player = ProgramAudioPlayer()
    @State private var hasMemo = false
    @State private var showPermissionAlert = false
    @State private var showSpeechPermissionAlert = false
    @State private var remainingDuration: TimeInterval = VoiceMemoStorage.maxDurationSeconds
    @State private var showTranscript = false
    @State private var transcriptText: String?
    @State private var isTranscribing = false
    @State private var transcriptError: String?

    private var memoURL: URL {
        VoiceMemoStorage.fileURL(forProgramId: programId)
    }

    private var canAddOn: Bool {
        hasMemo && remainingDuration > 0
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
                Text("Optional · up to 5 min")
                    .font(.arial(size: 11))
                    .foregroundColor(.secondary)
            }

            Text("Capture quick post-interview impressions. Saved on this device for now.")
                .font(.arial(size: 13))
                .foregroundColor(.secondary)

            if recorder.isRecording {
                recordingRow
            } else if recorder.isMerging {
                mergingRow
            } else if hasMemo {
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
        .onDisappear {
            VoiceMemoPlayback.stopActivePlayback()
        }
        .onChange(of: programId) { _, _ in
            Task {
                await player.stop()
                resetTranscriptState()
                await refreshMemoState()
            }
        }
        .alert("Microphone Access Needed", isPresented: $showPermissionAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Enable microphone access for Matchly in Settings to record voice memos.")
        }
        .alert("Speech Recognition Needed", isPresented: $showSpeechPermissionAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Enable speech recognition for Matchly in Settings to generate transcripts on this device.")
        }
        .onChange(of: recorder.permissionDenied) { _, denied in
            if denied { showPermissionAlert = true }
        }
        .onChange(of: recorder.isRecording) { wasRecording, isRecording in
            if wasRecording && !isRecording && !recorder.isMerging {
                resetTranscriptState()
                Task { await refreshMemoState() }
            }
        }
        .onChange(of: recorder.isMerging) { wasMerging, isMerging in
            if wasMerging && !isMerging {
                resetTranscriptState()
                Task {
                    await refreshMemoState()
                    onMemoChanged()
                }
            }
        }
    }

    private var playbackSpeedMenu: some View {
        Menu {
            ForEach(VoiceMemoStorage.playbackRateOptions, id: \.self) { rate in
                Button {
                    player.setPlaybackRate(rate)
                } label: {
                    if rate == player.playbackRate {
                        Label(formattedPlaybackRate(rate), systemImage: "checkmark")
                    } else {
                        Text(formattedPlaybackRate(rate))
                    }
                }
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "gauge.with.dots.needle.33percent")
                    .font(.arial(size: 11))
                Text(formattedPlaybackRate(player.playbackRate))
                    .font(.arial(size: 12, weight: .medium))
                    .monospacedDigit()
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color(.tertiarySystemFill))
            .clipShape(Capsule())
        }
    }

    private var transcriptSection: some View {
        DisclosureGroup(isExpanded: $showTranscript) {
            VStack(alignment: .leading, spacing: 10) {
                if isTranscribing {
                    HStack(spacing: 10) {
                        ProgressView()
                        Text("Creating transcript on this device…")
                            .font(.arial(size: 13))
                            .foregroundColor(.secondary)
                    }
                } else if let transcriptError {
                    Text(transcriptError)
                        .font(.arial(size: 13))
                        .foregroundColor(.red)

                    Button("Try Again") {
                        Task { await generateTranscript(force: true) }
                    }
                    .font(.arial(size: 13, weight: .medium))
                } else if let transcriptText, !transcriptText.isEmpty {
                    Text(transcriptText)
                        .font(.arial(size: 14))
                        .foregroundColor(.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)

                    Button("Refresh Transcript") {
                        Task { await generateTranscript(force: true) }
                    }
                    .font(.arial(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
                } else {
                    Text("Generate a readable transcript from this recording.")
                        .font(.arial(size: 13))
                        .foregroundColor(.secondary)

                    Button("Generate Transcript") {
                        Task { await generateTranscript(force: true) }
                    }
                    .font(.arial(size: 13, weight: .medium))
                }
            }
            .padding(.top, 6)
        } label: {
            Label("Transcript", systemImage: "text.quote")
                .font(.arial(size: 14, weight: .medium))
        }
        .onChange(of: showTranscript) { _, expanded in
            if expanded {
                Task { await loadTranscriptIfNeeded() }
            }
        }
    }

    private var recordingRow: some View {
        VStack(alignment: .leading, spacing: 10) {
            LiveAudioWaveformView(levels: recorder.meterLevels)

            HStack(spacing: 12) {
                Image(systemName: "waveform")
                    .foregroundColor(.red)
                VStack(alignment: .leading, spacing: 2) {
                    Text(recorder.formatTime(recorder.displayedDuration))
                        .font(.arial(size: 17, weight: .medium))
                        .monospacedDigit()
                    if recorder.existingDuration > 0 {
                        Text("Adding on to existing memo")
                            .font(.arial(size: 11))
                            .foregroundColor(.secondary)
                    }
                }
                Spacer()
                Button("Stop") {
                    finishRecording()
                }
                .font(.arial(size: 15, weight: .semibold))
                .foregroundColor(.red)
            }
        }
        .padding(12)
        .background(Color.red.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var mergingRow: some View {
        HStack(spacing: 12) {
            ProgressView()
            Text("Saving added audio…")
                .font(.arial(size: 14))
                .foregroundColor(.secondary)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
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
                    HStack {
                        playbackSpeedMenu
                        Spacer()
                    }

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

            HStack(spacing: 16) {
                if canAddOn {
                    Button("Add On") {
                        Task {
                            await player.stop()
                            startAppending()
                        }
                    }
                    .font(.arial(size: 13, weight: .medium))
                }

                Button("Re-record") {
                    Task {
                        await player.stop()
                        VoiceMemoStorage.deleteMemo(forProgramId: programId)
                        hasMemo = false
                        remainingDuration = VoiceMemoStorage.maxDurationSeconds
                        resetTranscriptState()
                        onMemoChanged()
                        startRecording()
                    }
                }
                .font(.arial(size: 13, weight: .medium))

                Spacer()

                Button("Delete", role: .destructive) {
                    Task {
                        await player.stop()
                        VoiceMemoStorage.deleteMemo(forProgramId: programId)
                        hasMemo = false
                        remainingDuration = VoiceMemoStorage.maxDurationSeconds
                        resetTranscriptState()
                        onMemoChanged()
                    }
                }
                .font(.arial(size: 13, weight: .medium))
                .foregroundColor(.red)
            }

            if canAddOn {
                Text("\(recorder.formatTime(remainingDuration)) left before 5 min limit")
                    .font(.arial(size: 11))
                    .foregroundColor(.secondary)
            }

            transcriptSection
        }
        .padding(12)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var idleRow: some View {
        HStack {
            Text("No voice memo yet")
                .font(.arial(size: 14))
                .foregroundColor(.secondary)
            Spacer()
            Button(action: startRecording) {
                Label("Record", systemImage: "record.circle")
                    .font(.arial(size: 15, weight: .semibold))
            }
            .foregroundColor(.red)
        }
        .padding(12)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func startRecording() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        VoiceMemoStorage.invalidateTranscript(forProgramId: programId)
        resetTranscriptState()
        recorder.startRecording(to: memoURL, appending: false)
    }

    private func startAppending() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        recorder.startRecording(to: memoURL, appending: true)
    }

    private func finishRecording() {
        recorder.stopRecording { url in
            if url != nil {
                resetTranscriptState()
                onMemoChanged()
            }
            Task { await refreshMemoState() }
        }
    }

    private func resetTranscriptState() {
        showTranscript = false
        transcriptText = nil
        transcriptError = nil
        isTranscribing = false
    }

    private func loadTranscriptIfNeeded() async {
        if isTranscribing { return }

        if let cached = VoiceMemoStorage.loadTranscript(forProgramId: programId) {
            transcriptText = cached
            transcriptError = nil
            return
        }

        await generateTranscript(force: false)
    }

    private func generateTranscript(force: Bool) async {
        guard hasMemo else { return }
        if isTranscribing { return }

        if !force, let cached = VoiceMemoStorage.loadTranscript(forProgramId: programId) {
            transcriptText = cached
            transcriptError = nil
            return
        }

        isTranscribing = true
        transcriptError = nil

        do {
            let text = try await VoiceMemoTranscriber.transcribe(audioAt: memoURL)
            try VoiceMemoStorage.saveTranscript(text, forProgramId: programId)
            transcriptText = text
        } catch VoiceMemoTranscriberError.notAuthorized {
            showSpeechPermissionAlert = true
            transcriptError = VoiceMemoTranscriberError.notAuthorized.errorDescription
        } catch {
            transcriptError = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }

        isTranscribing = false
    }

    private func formattedPlaybackRate(_ rate: Float) -> String {
        if rate == floor(rate) {
            return String(format: "%.0f×", rate)
        }
        return String(format: "%.2g×", rate)
    }

    private func refreshMemoState() async {
        await player.reset()
        let memoExists = VoiceMemoStorage.hasMemo(forProgramId: programId)
        let memoDuration: TimeInterval
        let remaining: TimeInterval
        if memoExists {
            memoDuration = await VoiceMemoStorage.duration(of: memoURL)
            remaining = VoiceMemoStorage.remainingDuration(givenExistingDuration: memoDuration)
        } else {
            memoDuration = 0
            remaining = VoiceMemoStorage.maxDurationSeconds
        }

        await MainActor.run {
            hasMemo = memoExists
            remainingDuration = remaining
            if memoDuration > 0 {
                player.setDurationHint(memoDuration)
            }
        }
    }
}
