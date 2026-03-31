import SwiftUI
import AVFoundation
import Combine

class VideoNoteRecorderViewModel: ObservableObject {
    @Published var isRecording = false
    @Published var recordingTime: TimeInterval = 0
    @Published var errorMessage: String?
    @Published var previewImage: UIImage?
    
    private var captureSession: AVCaptureSession?
    private var photoOutput: AVCapturePhotoOutput?
    private var timer: Timer?
    
    let onRecorded: (String, Double) -> Void
    
    init(onRecorded: @escaping (String, Double) -> Void) {
        self.onRecorded = onRecorded
        setupCamera()
    }
    
    private func setupCamera() {
        captureSession = AVCaptureSession()
        captureSession?.sessionPreset = .medium
        
        guard let camera = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: camera),
              captureSession?.canAddInput(input) == true else {
            errorMessage = "Не удалось подключить камеру"
            return
        }
        
        captureSession?.addInput(input)
        
        photoOutput = AVCapturePhotoOutput()
        if let photoOutput = photoOutput,
           captureSession?.canAddOutput(photoOutput) == true {
            captureSession?.addOutput(photoOutput)
        }
        
        captureSession?.startRunning()
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            if let photoOutput = self?.photoOutput {
                let settings = AVCapturePhotoSettings()
                photoOutput.capturePhoto(with: settings, delegate: PhotoCaptureDelegate { image in
                    DispatchQueue.main.async {
                        self?.previewImage = image
                    }
                })
            }
        }
    }
    
    func startRecording() {
        isRecording = true
        recordingTime = 0
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.recordingTime += 1
            if self?.recordingTime ?? 0 >= 60 {
                self?.stopRecording()
            }
        }
    }
    
    func stopRecording(cancel: Bool = false) {
        timer?.invalidate()
        
        if !cancel {
            // Для демо возвращаем заглушку
            let placeholderBase64 = "video/quicktime;base64,placeholder"
            onRecorded(placeholderBase64, recordingTime)
        }
        
        isRecording = false
    }
    
    deinit {
        timer?.invalidate()
        captureSession?.stopRunning()
    }
}

struct VideoNoteRecorderView: View {
    let onRecorded: (String, Double) -> Void
    @StateObject private var viewModel: VideoNoteRecorderViewModel
    
    init(onRecorded: @escaping (String, Double) -> Void) {
        self.onRecorded = onRecorded
        _viewModel = StateObject(wrappedValue: VideoNoteRecorderViewModel(onRecorded: onRecorded))
    }
    
    var body: some View {
        VStack(spacing: 20) {
            ZStack {
                if let image = viewModel.previewImage {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 250, height: 250)
                        .clipShape(Circle())
                } else {
                    Circle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(width: 250, height: 250)
                    Image(systemName: "video.slash")
                        .font(.system(size: 50))
                        .foregroundColor(.gray)
                }
                
                Circle()
                    .stroke(Color.white, lineWidth: 3)
                    .frame(width: 250, height: 250)
            }
            
            if viewModel.isRecording {
                Circle()
                    .fill(Color.red)
                    .frame(width: 20, height: 20)
                    .scaleEffect(1 + sin(viewModel.recordingTime * 3) * 0.2)
                    .animation(.easeInOut(duration: 0.3), value: viewModel.recordingTime)
            }
            
            Text(String(format: "%d:%02d", Int(viewModel.recordingTime) / 60, Int(viewModel.recordingTime) % 60))
                .font(.system(size: 24, weight: .medium))
                .monospacedDigit()
            
            Button(action: toggleRecording) {
                Circle()
                    .fill(viewModel.isRecording ? Color.red : Color.white)
                    .frame(width: 70, height: 70)
                    .overlay(
                        Circle()
                            .stroke(Color.gray, lineWidth: 2)
                            .frame(width: 74, height: 74)
                    )
            }
            
            if let error = viewModel.errorMessage {
                Text(error)
                    .foregroundColor(.red)
                    .font(.caption)
            }
            
            Spacer()
            
            Text("Нажмите для записи кружочка (макс. 60 сек)")
                .foregroundColor(.gray)
                .font(.caption)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .padding()
    }
    
    private func toggleRecording() {
        if viewModel.isRecording {
            viewModel.stopRecording()
        } else {
            viewModel.startRecording()
        }
    }
}
