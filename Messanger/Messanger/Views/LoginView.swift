import SwiftUI

struct LoginView: View {
    @State private var username = ""
    @State private var password = ""
    @State private var isRegistering = false
    @State private var name = ""
    @State private var errorMessage = ""
    @State private var showAlert = false
    @State private var isLoading = false
    
    private let networkService = NetworkService.shared
    
    var body: some View {
        VStack(spacing: 30) {
            Image(systemName: "message.fill")
                .font(.system(size: 80))
                .foregroundColor(.blue)
            
            Text("Мессенджер")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            TextField("Логин", text: $username)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .autocapitalization(.none)
                .disabled(isLoading)
            
            if isRegistering {
                TextField("Имя", text: $name)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .disabled(isLoading)
            }
            
            SecureField("Пароль", text: $password)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .disabled(isLoading)
            
            Button(action: submit) {
                HStack {
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    }
                    Text(isRegistering ? "Зарегистрироваться" : "Войти")
                        .font(.headline)
                        .foregroundColor(.white)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(isLoading ? Color.gray : Color.blue)
                .cornerRadius(10)
            }
            .disabled(isLoading || username.isEmpty || password.isEmpty || (isRegistering && name.isEmpty))
            
            Button(action: { isRegistering.toggle() }) {
                Text(isRegistering ? "Уже есть аккаунт? Войти" : "Нет аккаунта? Зарегистрироваться")
                    .foregroundColor(.blue)
            }
            .disabled(isLoading)
            
            if !errorMessage.isEmpty {
                Text(errorMessage)
                    .foregroundColor(.red)
                    .font(.caption)
                    .multilineTextAlignment(.center)
            }
            
            Spacer()
        }
        .padding()
        .alert("Ошибка", isPresented: $showAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
    }
    
    private func submit() {
        isLoading = true
        errorMessage = ""
        
        if isRegistering {
            networkService.register(username: username, password: password, name: name) { result in
                handleResult(result)
            }
        } else {
            networkService.login(username: username, password: password) { result in
                handleResult(result)
            }
        }
    }
    
    private func handleResult(_ result: Result<User, Error>) {
        isLoading = false
        switch result {
        case .success:
            break
        case .failure(let error):
            errorMessage = error.localizedDescription
            showAlert = true
        }
    }
}
