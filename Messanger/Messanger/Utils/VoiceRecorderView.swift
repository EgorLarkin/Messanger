import SwiftUI
import AVFoundation
import Combine

class VoiceRecorderViewModel: ObservableObject {
    @Published var isRecording = false
    @Published var recordingTime: TimeInterval = 0
    @Published var errorMessage: String?
    
    private var audioRecorder: AVAudioRecorder?
    private var timer: Timer?
    let onRecorded: (String, Double) -> Void
    
    init(onRecorded: @escaping (String, Double) -> Void) {
        self.onRecorded = onRecorded
    }
    
    func startRecording() {
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.playAndRecord, mode: .default)
            try audioSession.setActive(true)
            
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("voice.m4a")
            let settings: [String: Any] = [
                AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                AVSampleRateKey: 44100,
                AVNumberOfChannelsKey: 1,
                AVEncoderAudioQualityKey: AVAudioQuality.medium.rawValue
            ]
            
            audioRecorder = try AVAudioRecorder(url: tempURL, settings: settings)
            audioRecorder?.prepareToRecord()
            audioRecorder?.record()
            
            isRecording = true
            recordingTime = 0
            timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
                self?.recordingTime += 1
            }
            
        } catch {
            errorMessage = "Ошибка записи: \(error.localizedDescription)"
        }
    }
    
    func stopRecording(cancel: Bool = false) {
        timer?.invalidate()
        audioRecorder?.stop()
        
        if !cancel,
           let url = audioRecorder?.url,
           let data = try? Data(contentsOf: url) {
            let base64 = "audio/m4a;base64,\(data.base64EncodedString())"
            onRecorded(base64, recordingTime)
        }
        
        isRecording = false
        audioRecorder = nil
    }
    
    deinit {
        timer?.invalidate()
    }
}

struct VoiceRecorderView: View {
    let onRecorded: (String, Double) -> Void
    @StateObject private var viewModel: VoiceRecorderViewModel
    
    init(onRecorded: @escaping (String, Double) -> Void) {
        self.onRecorded = onRecorded
        _viewModel = StateObject(wrappedValue: VoiceRecorderViewModel(onRecorded: onRecorded))
    }
    
    var body: some View {
        VStack(spacing: 30) {
            Text("Запись голосового сообщения")
                .font(.headline)
            
            ZStack {
                Circle()
                    .fill(viewModel.isRecording ? Color.red.opacity(0.3) : Color.gray.opacity(0.2))
                    .frame(width: 150, height: 150)
                
                if viewModel.isRecording {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 120, height: 120)
                        .scaleEffect(1 + sin(viewModel.recordingTime * 3) * 0.1)
                        .animation(.easeInOut(duration: 0.3), value: viewModel.recordingTime)
                }
                
                Image(systemName: viewModel.isRecording ? "mic.slash.fill" : "mic.fill")
                    .font(.system(size: 50))
                    .foregroundColor(viewModel.isRecording ? .white : .gray)
            }
            .onTapGesture {
                if viewModel.isRecording {
                    viewModel.stopRecording()
                } else {
                    viewModel.startRecording()
                }
            }
            
            Text(String(format: "%d:%02d", Int(viewModel.recordingTime) / 60, Int(viewModel.recordingTime) % 60))
                .font(.system(size: 32, weight: .medium))
                .monospacedDigit()
            
            HStack(spacing: 40) {
                if viewModel.isRecording {
                    Button("Отмена") {
                        viewModel.stopRecording(cancel: true)
                    }
                    .foregroundColor(.red)
                }
                
                Spacer()
                
                if viewModel.isRecording {
                    Button("Готово") {
                        viewModel.stopRecording()
                    }
                    .foregroundColor(.blue)
                }
            }
            .font(.headline)
            .padding(.horizontal)
            
            if let error = viewModel.errorMessage {
                Text(error)
                    .foregroundColor(.red)
                    .font(.caption)
            }
            
            Spacer()
            
            Text("Нажмите на микрофон для записи")
                .foregroundColor(.gray)
                .font(.caption)
        }
        .padding()
    }
}
