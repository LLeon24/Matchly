//
//  VoiceMemoPlayer.swift
//  Matchly
//
//  Created by Leoh N. Leon II on 11/14/25.
//

import SwiftUI
import AVFoundation
import Combine

class AudioPlayer: NSObject, ObservableObject, AVAudioPlayerDelegate {
    @Published var isPlaying = false
    @Published var currentTime: TimeInterval = 0
    @Published var duration: TimeInterval = 0
    
    private var audioPlayer: AVAudioPlayer?
    private var timer: Timer?
    
    func loadAudio(from url: URL) {
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.delegate = self
            duration = audioPlayer?.duration ?? 0
        } catch {
            print("Failed to load audio: \(error)")
        }
    }
    
    func play() {
        audioPlayer?.play()
        isPlaying = true
        startTimer()
    }
    
    func pause() {
        audioPlayer?.pause()
        isPlaying = false
        stopTimer()
    }
    
    func stop() {
        audioPlayer?.stop()
        audioPlayer?.currentTime = 0
        isPlaying = false
        currentTime = 0
        stopTimer()
    }
    
    func seek(to time: TimeInterval) {
        audioPlayer?.currentTime = time
        currentTime = time
    }
    
    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self, let player = self.audioPlayer else { return }
            self.currentTime = player.currentTime
        }
    }
    
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
    
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        isPlaying = false
        currentTime = 0
        stopTimer()
    }
    
    func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

struct VoiceMemoPlayer: View {
    let voiceMemoURL: String?
    @StateObject private var player = AudioPlayer()
    @State private var loadedURL: URL?
    
    var body: some View {
        if let urlString = voiceMemoURL {
            let url: URL = {
                if urlString.hasPrefix("file://") {
                    return URL(string: urlString) ?? URL(fileURLWithPath: urlString)
                } else {
                    return URL(fileURLWithPath: urlString)
                }
            }()
            
            if FileManager.default.fileExists(atPath: url.path) {
                VStack(spacing: 12) {
                    HStack {
                        Button(action: {
                            if player.isPlaying {
                                player.pause()
                            } else {
                                if loadedURL != url {
                                    player.loadAudio(from: url)
                                    loadedURL = url
                                }
                                player.play()
                            }
                        }) {
                            Image(systemName: player.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                                .font(.title)
                                .foregroundColor(.blue)
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            if player.duration > 0 {
                                Slider(
                                    value: Binding(
                                        get: { player.currentTime },
                                        set: { player.seek(to: $0) }
                                    ),
                                    in: 0...player.duration
                                )
                                
                                HStack {
                                    Text(player.formatTime(player.currentTime))
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .monospacedDigit()
                                    
                                    Spacer()
                                    
                                    Text(player.formatTime(player.duration))
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .monospacedDigit()
                                }
                            } else {
                                Text("Voice Memo")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        if player.isPlaying {
                            Button(action: {
                                player.stop()
                            }) {
                                Image(systemName: "stop.circle")
                                    .font(.title3)
                                    .foregroundColor(.red)
                            }
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                }
                .onAppear {
                    if loadedURL != url {
                        player.loadAudio(from: url)
                        loadedURL = url
                    }
                }
            } else {
                Text("Voice memo file not found")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding()
            }
        }
    }
}

#Preview {
    VoiceMemoPlayer(voiceMemoURL: nil)
}

