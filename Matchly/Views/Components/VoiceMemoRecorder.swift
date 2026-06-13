//
//  VoiceMemoRecorder.swift
//  Matchly
//
//  Created by Leoh N. Leon II on 11/14/25.
//

import SwiftUI
import AVFoundation
import Combine

class AudioRecorder: NSObject, ObservableObject, AVAudioRecorderDelegate {
    @Published var isRecording = false
    @Published var recordingTime: TimeInterval = 0
    
    private var audioRecorder: AVAudioRecorder?
    private var timer: Timer?
    private var recordingURL: URL?
    
    func startRecording() {
        // Perform all audio setup on background queue to avoid blocking UI
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            let recordingSession = AVAudioSession.sharedInstance()
            
            // Check current permission status first
            let authStatus = recordingSession.recordPermission
            
            func proceedWithRecording() {
                do {
                    try recordingSession.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth])
                    try recordingSession.setActive(true, options: .notifyOthersOnDeactivation)
                } catch {
                    print("Failed to set up recording session: \(error)")
                    return
                }
                
                let documentPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                let audioFilename = documentPath.appendingPathComponent("\(UUID().uuidString).m4a")
                self.recordingURL = audioFilename
                
                let settings = [
                    AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                    AVSampleRateKey: 12000,
                    AVNumberOfChannelsKey: 1,
                    AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
                ]
                
                do {
                    let recorder = try AVAudioRecorder(url: audioFilename, settings: settings)
                    recorder.delegate = self
                    
                    guard recorder.record() == true else {
                        print("Could not start recording")
                        return
                    }
                    
                    // Update on main thread
                    DispatchQueue.main.async { [weak self] in
                        guard let self = self else { return }
                        self.audioRecorder = recorder
                        self.isRecording = true
                        self.recordingTime = 0
                        
                        // Create timer on main thread with proper RunLoop mode
                        self.timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] timer in
                            guard let self = self else {
                                timer.invalidate()
                                return
                            }
                            DispatchQueue.main.async {
                                self.recordingTime += 0.1
                            }
                        }
                        if let timer = self.timer {
                            RunLoop.current.add(timer, forMode: .common)
                        }
                    }
                } catch {
                    print("Could not start recording: \(error)")
                }
            }
            
            // Request microphone permission if needed
            if authStatus == .undetermined {
                recordingSession.requestRecordPermission { granted in
                    if granted {
                        proceedWithRecording()
                    } else {
                        print("Microphone permission denied")
                    }
                }
            } else if authStatus == .denied {
                print("Microphone permission denied")
            } else {
                // Permission already granted
                proceedWithRecording()
            }
        }
    }
    
    
    func stopRecording() -> URL? {
        audioRecorder?.stop()
        isRecording = false
        timer?.invalidate()
        timer = nil
        
        // Deactivate audio session
        do {
            try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        } catch {
            print("Failed to deactivate audio session: \(error)")
        }
        
        let url = recordingURL
        recordingURL = nil
        return url
    }
    
    func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

struct VoiceMemoRecorder: View {
    @StateObject private var recorder = AudioRecorder()
    @Binding var recordingURL: URL?
    @State private var hasRecording = false
    
    var body: some View {
        VStack(spacing: 16) {
            if recorder.isRecording {
                HStack {
                    Image(systemName: "mic.fill")
                        .foregroundColor(.red)
                        .font(.title2)
                    
                    Text(recorder.formatTime(recorder.recordingTime))
                        .font(.system(size: 18, weight: .medium))
                        .monospacedDigit()
                    
                    Spacer()
                    
                    Button(action: {
                        if let url = recorder.stopRecording() {
                            recordingURL = url
                            hasRecording = true
                        }
                    }) {
                        Image(systemName: "stop.circle.fill")
                            .font(.title)
                            .foregroundColor(.red)
                    }
                }
                .padding()
                .background(Color.red.opacity(0.1))
                .cornerRadius(12)
            } else {
                HStack {
                    if hasRecording {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.title2)
                        
                        Text("Recording saved")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Button(action: {
                            recordingURL = nil
                            hasRecording = false
                        }) {
                            Text("Remove")
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                    } else {
                        Image(systemName: "mic.circle")
                            .foregroundColor(.blue)
                            .font(.title2)
                        
                        Text("Record voice memo (optional)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                    }
                    
                    if !hasRecording {
                        Button(action: {
                            // Dismiss keyboard before recording
                            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                            recorder.startRecording()
                        }) {
                            Image(systemName: "record.circle")
                                .font(.title)
                                .foregroundColor(.red)
                        }
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
            }
        }
    }
}

#Preview {
    VoiceMemoRecorder(recordingURL: .constant(nil))
}

