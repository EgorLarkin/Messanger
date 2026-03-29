import SwiftUI
import PhotosUI
import AVFoundation
import Combine

// ============================================
// MARK: - ConversationView
// ============================================
struct ConversationView: View {
    let chatUser: User
    @State private var messageText = ""
    @State private var messages: [Message] = []
    @State private var isLoading = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showPhotoPicker = false
    @State private var showFilePicker = false
    @State private var showVoiceRecorder = false
    @State private var showCamera = false
    @State private var showActionSheet = false
    
    private let networkService = NetworkService.shared
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 8) {
                            ForEach(messages) { message in
                                MessageBubble(message: message, sender: chatUser)
                                    .id(message.id)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                    }
                    .task {
                        loadMessages()
                    }
                    .onChange(of: messages.count) { oldValue, newValue in
                        scrollToBottom(proxy: proxy)
                    }
                }
                
                Divider()
                
                HStack(spacing: 12) {
                    Button(action: { showActionSheet = true }) {
                        Image(systemName: "paperclip")
                            .font(.system(size: 22))
                            .foregroundColor(.blue)
                            .frame(width: 44, height: 44)
                            .background(Color.blue.opacity(0.1))
                            .clipShape(Circle())
                    }
                    .confirmationDialog("Прикрепить", isPresented: $showActionSheet, titleVisibility: .visible, presenting: ()) { _ in
                        Button("📷 Сделать снимок") {
                            showCamera = true
                        }
                        Button("🖼️ Выбрать из галереи") {
                            showPhotoPicker = true
                        }
                        Button("📎 Выбрать файл") {
                            showFilePicker = true
                        }
                        Button("Отмена", role: .cancel) { }
                    }
                    TextField("Сообщение", text: $messageText)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .onSubmit { sendMessage() }
                    
                    Button(action: { showVoiceRecorder = true }) {
                        Image(systemName: "mic.circle.fill")
                            .font(.system(size: 28))
                            .foregroundColor(.red)
                            .frame(width: 44, height: 44)
                            .background(Color.red.opacity(0.1))
                            .clipShape(Circle())
                    }
                    
                    Button(action: sendMessage) {
                        Image(systemName: "paperplane.fill")
                            .font(.system(size: 20))
                            .foregroundColor(messageText.trimmingCharacters(in: .whitespaces).isEmpty ? .gray : .blue)
                    }
                }
                .padding()
            }
            .navigationTitle(chatUser.name)
            .navigationBarTitleDisplayMode(.inline)
            
            .sheet(isPresented: $showCamera) {
                CameraView(onCapture: { base64, size in
                    sendMedia(type: .image, data: base64, duration: nil, fileName: nil, fileSize: size)
                    showCamera = false
                })
            }
            .sheet(isPresented: $showPhotoPicker) {
                PhotoAndVideoPickerView(onSelect: { mediaType, base64, size, fileName in
                    sendMedia(type: mediaType, data: base64, duration: nil, fileName: fileName, fileSize: size)
                    showPhotoPicker = false
                })
            }
            .sheet(isPresented: $showFilePicker) {
                FilePickerView(onSelect: { base64, size, name in
                    sendMedia(type: .file, data: base64, duration: nil, fileName: name, fileSize: size)
                    showFilePicker = false
                })
            }
            .sheet(isPresented: $showVoiceRecorder) {
                VoiceAndVideoRecorderView(chatUser: chatUser, onSend: { type, data, duration, fileName, fileSize in
                    sendMedia(type: type, data: data, duration: duration, fileName: fileName, fileSize: fileSize)
                    showVoiceRecorder = false
                })
            }
        }
    }
    
    private func scrollToBottom(proxy: ScrollViewProxy) {
        if let last = messages.last {
            withAnimation {
                proxy.scrollTo(last.id, anchor: .bottom)
            }
        }
    }
    
    private func sendMessage() {
        guard !messageText.isEmpty else { return }
        let text = messageText
        messageText = ""
        networkService.sendMessage(to: chatUser.username, text: text) { result in
            if case .success(let msg) = result {
                messages.append(msg)
            }
        }
    }
    
    private func sendMedia(type: MediaType, data: String?, duration: Double?, fileName: String?, fileSize: Int?) {
        networkService.sendMessage(to: chatUser.username, text: "", mediaType: type, mediaData: data, duration: duration, fileName: fileName, fileSize: fileSize) { result in
            if case .success(let msg) = result {
                messages.append(msg)
            }
        }
    }
    
    private func loadMessages() {
        guard let currentUser = AuthManager.shared.currentUser else { return }
        networkService.fetchHistory(user1: currentUser.username, user2: chatUser.username) { result in
            if case .success(let fetched) = result {
                messages = fetched.sorted { $0.date < $1.date }
            }
        }
    }
}

// ============================================
// MARK: - CameraView
// ============================================
struct CameraView: View {
    let onCapture: (String, Int) -> Void
    @Environment(\.dismiss) var dismiss
    @StateObject private var viewModel = CameraViewModel()
    @State private var showingAlert = false
    @State private var alertMessage = ""
    
    var body: some View {
        NavigationView {
            ZStack {
                CameraPreviewView(session: viewModel.session)
                    .ignoresSafeArea()
                
                if !viewModel.isSessionRunning {
                    VStack {
                        ProgressView("Инициализация камеры...")
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.black.opacity(0.7))
                            .cornerRadius(10)
                    }
                }
                
                VStack {
                    Spacer()
                    
                    Button(action: {
                        viewModel.capturePhoto { image in
                            guard let image = image,
                                  let base64 = image.toBase64(compressionQuality: 0.8),
                                  let data = image.jpegData(compressionQuality: 0.8) else {
                                DispatchQueue.main.async {
                                    alertMessage = "Не удалось сделать фото"
                                    showingAlert = true
                                }
                                return
                            }
                            
                            DispatchQueue.main.async {
                                onCapture(base64, data.count)
                                dismiss()
                            }
                        }
                    }) {
                        Circle()
                            .stroke(Color.white, lineWidth: 4)
                            .frame(width: 70, height: 70)
                            .background(Color.black.opacity(0.3))
                            .clipShape(Circle())
                    }
                    .disabled(!viewModel.isSessionRunning)
                    .padding(.bottom, 30)
                }
            }
            .navigationTitle("Камера")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Отмена") {
                        viewModel.stopSession()
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
            }
            .onAppear {
                viewModel.checkPermissions()
            }
            .onDisappear {
                viewModel.stopSession()
            }
            .alert("Ошибка", isPresented: $showingAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(alertMessage)
            }
        }
    }
}

class CameraViewModel: NSObject, ObservableObject {
    @Published var session = AVCaptureSession()
    @Published var hasPermission = false
    @Published var isSessionRunning = false
    
    private let photoOutput = AVCapturePhotoOutput()
    private var isConfigured = false
    private var photoCaptureDelegate: PhotoCaptureDelegate?
    
    func checkPermissions() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            hasPermission = true
            setupSession()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    self?.hasPermission = granted
                    if granted {
                        self?.setupSession()
                    }
                }
            }
        default:
            hasPermission = false
        }
    }
    
    private func setupSession() {
        guard !isConfigured else { return }
        
        session.beginConfiguration()
        session.sessionPreset = .photo
        
        guard let camera = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: camera),
              session.canAddInput(input) else {
            session.commitConfiguration()
            return
        }
        
        session.addInput(input)
        
        if session.canAddOutput(photoOutput) {
            session.addOutput(photoOutput)
        }
        
        session.commitConfiguration()
        isConfigured = true
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.session.startRunning()
            DispatchQueue.main.async {
                self?.isSessionRunning = true
            }
        }
    }
    
    func capturePhoto(completion: @escaping (UIImage?) -> Void) {
        guard isSessionRunning else {
            completion(nil)
            return
        }
        
        let settings = AVCapturePhotoSettings()
        
        photoCaptureDelegate = PhotoCaptureDelegate { [weak self] image in
            completion(image)
            self?.photoCaptureDelegate = nil
        }
        
        if let delegate = photoCaptureDelegate {
            photoOutput.capturePhoto(with: settings, delegate: delegate)
        }
    }
    
    func stopSession() {
        if session.isRunning {
            session.stopRunning()
            isSessionRunning = false
        }
    }
}

class PhotoCaptureDelegate: NSObject, AVCapturePhotoCaptureDelegate {
    let completion: (UIImage?) -> Void
    
    init(completion: @escaping (UIImage?) -> Void) {
        self.completion = completion
    }
    
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let error = error {
            print("❌ Ошибка: \(error)")
            completion(nil)
            return
        }
        
        guard let data = photo.fileDataRepresentation(),
              let image = UIImage(data: data) else {
            completion(nil)
            return
        }
        
        completion(image)
    }
}

struct CameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        
        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(previewLayer)
        
        DispatchQueue.main.async {
            previewLayer.frame = view.bounds
        }
        
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        if let previewLayer = uiView.layer.sublayers?.first as? AVCaptureVideoPreviewLayer {
            DispatchQueue.main.async {
                previewLayer.frame = uiView.bounds
            }
        }
    }
}

// ============================================
// MARK: - PhotoAndVideoPickerView
// ============================================
struct PhotoAndVideoPickerView: View {
    let onSelect: (MediaType, String, Int, String?) -> Void
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var selectedVideo: PhotosPickerItem?
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            List {
                Section(header: Text("Фото")) {
                    PhotosPicker(selection: $selectedPhoto, matching: .images) {
                        HStack {
                            Image(systemName: "photo")
                                .font(.system(size: 24))
                                .foregroundColor(.blue)
                            Text("Выбрать фото")
                        }
                    }
                    .onChange(of: selectedPhoto) { oldValue, newValue in
                        Task {
                            await processPhoto(newValue)
                        }
                    }
                }
                
                Section(header: Text("Видео")) {
                    PhotosPicker(selection: $selectedVideo, matching: .videos) {
                        HStack {
                            Image(systemName: "video")
                                .font(.system(size: 24))
                                .foregroundColor(.red)
                            Text("Выбрать видео")
                        }
                    }
                    .onChange(of: selectedVideo) { oldValue, newValue in
                        Task {
                            await processVideo(newValue)
                        }
                    }
                }
            }
            .navigationTitle("Галерея")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Отмена") { dismiss() }
                }
            }
        }
    }
    
    private func processPhoto(_ item: PhotosPickerItem?) async {
        guard let item = item else { return }
        
        do {
            guard let data = try await item.loadTransferable(type: Data.self) else {
                return
            }
            
            guard let image = UIImage(data: data),
                  let base64 = image.toBase64(compressionQuality: 0.8) else {
                return
            }
            
            await MainActor.run {
                onSelect(.image, base64, data.count, nil)
                dismiss()
            }
        } catch {
            print("❌ Ошибка: \(error)")
        }
    }
    
    private func processVideo(_ item: PhotosPickerItem?) async {
        guard let item = item else { return }
        
        do {
            guard let data = try await item.loadTransferable(type: Data.self) else {
                return
            }
            
            let base64 = "video/mp4;base64,\(data.base64EncodedString())"
            
            await MainActor.run {
                onSelect(.video, base64, data.count, "video.mp4")
                dismiss()
            }
        } catch {
            print("❌ Ошибка: \(error)")
        }
    }
}

// ============================================
// MARK: - FilePickerView
// ============================================
struct FilePickerView: View {
    let onSelect: (String, Int, String) -> Void
    @State private var showPicker = false
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            VStack {
                Button("Выбрать файл") {
                    showPicker = true
                }
                .fileImporter(
                    isPresented: $showPicker,
                    allowedContentTypes: [.item],
                    allowsMultipleSelection: false
                ) { result in
                    Task {
                        do {
                            let urls = try result.get()
                            guard let url = urls.first else { return }
                            _ = url.startAccessingSecurityScopedResource()
                            defer { url.stopAccessingSecurityScopedResource() }
                            
                            let data = try Data(contentsOf: url)
                            let base64 = "file;base64,\(data.base64EncodedString())"
                            onSelect(base64, data.count, url.lastPathComponent)
                            await MainActor.run {
                                dismiss()
                            }
                        } catch {
                            print("❌ Ошибка: \(error)")
                        }
                    }
                }
            }
            .navigationTitle("Файл")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Отмена") { dismiss() }
                }
            }
        }
    }
}

// ============================================
// MARK: - VoiceAndVideoRecorderView
// ============================================
struct VoiceAndVideoRecorderView: View {
    let chatUser: User
    let onSend: (MediaType, String?, Double?, String?, Int?) -> Void
    @Environment(\.dismiss) var dismiss
    @State private var tab = 0
    
    var body: some View {
        NavigationView {
            VStack {
                Picker("Тип", selection: $tab) {
                    Text("🎤 Голос").tag(0)
                    Text("⭕ Кружок").tag(1)
                }
                .pickerStyle(.segmented)
                .padding()
                
                if tab == 0 {
                    SimpleVoiceRecorder(onSend: { base64, duration in
                        onSend(.voice, base64, duration, nil, nil)
                        dismiss()
                    })
                } else {
                    Text("Кружочки скоро будут")
                        .padding()
                    Button("Тест") {
                        onSend(.videoNote, "video;base64,test", 5, nil, nil)
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent)
                }
                
                Spacer()
            }
            .navigationTitle("Запись")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Отмена") { dismiss() }
                }
            }
        }
    }
}

struct SimpleVoiceRecorder: View {
    let onSend: (String, Double) -> Void
    @State private var recording = false
    @State private var time: TimeInterval = 0
    @State private var audioRecorder: AVAudioRecorder?
    @State private var timer: Timer?
    
    var body: some View {
        VStack(spacing: 20) {
            Circle()
                .fill(recording ? Color.red : Color.gray)
                .frame(width: 100, height: 100)
                .overlay(Image(systemName: "mic.fill").foregroundColor(.white))
                .onTapGesture {
                    if recording {
                        stopRecording()
                    } else {
                        startRecording()
                    }
                }
            
            Text(String(format: "%d:%02d", Int(time)/60, Int(time)%60))
                .font(.title2)
                .monospacedDigit()
            
            if recording {
                Button("Отправить") {
                    stopRecording(cancel: false)
                }
                .buttonStyle(.borderedProminent)
                
                Button("Отмена") {
                    stopRecording(cancel: true)
                }
                .foregroundColor(.red)
            }
        }
        .padding()
    }
    
    private func startRecording() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playAndRecord, mode: .default)
            try session.setActive(true)
            
            let url = FileManager.default.temporaryDirectory.appendingPathComponent("voice.m4a")
            let settings: [String: Any] = [
                AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                AVSampleRateKey: 44100,
                AVNumberOfChannelsKey: 1,
                AVEncoderAudioQualityKey: AVAudioQuality.medium.rawValue
            ]
            
            audioRecorder = try AVAudioRecorder(url: url, settings: settings)
            audioRecorder?.prepareToRecord()
            audioRecorder?.record()
            
            recording = true
            time = 0
            timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
                time += 1
            }
        } catch {
            print("❌ Ошибка: \(error)")
        }
    }
    
    private func stopRecording(cancel: Bool = true) {
        timer?.invalidate()
        audioRecorder?.stop()
        
        if !cancel,
           let url = audioRecorder?.url,
           let data = try? Data(contentsOf: url) {
            let base64 = "audio/m4a;base64,\(data.base64EncodedString())"
            onSend(base64, time)
        }
        
        recording = false
        audioRecorder = nil
    }
}
