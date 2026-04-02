import SwiftUI

struct LoginView: View {
    @State private var username = ""
    @State private var password = ""
    @State private var name = ""
    @State private var isRegistering = false
    @State private var errorMessage = ""
    @State private var showAlert = false
    @State private var isLoading = false

    private let networkService = NetworkService.shared

    var body: some View {
        VStack(spacing: 30) {
            Spacer()

            Image(systemName: "message.fill")
                .font(.system(size: 80))
                .foregroundColor(.blue)

            Text("Messanger")
                .font(.largeTitle)
                .fontWeight(.bold)

            VStack(spacing: 16) {
                TextField("Логин", text: $username)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .disabled(isLoading)

                if isRegistering {
                    TextField("Имя", text: $name)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .disabled(isLoading)
                }

                SecureField("Пароль", text: $password)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .disabled(isLoading)
            }

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
            .disabled(
                isLoading ||
                username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                password.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                (isRegistering && name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            )

            Button(action: {
                isRegistering.toggle()
                errorMessage = ""
            }) {
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
        let trimmedUsername = username.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedPassword = password.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedUsername.isEmpty, !trimmedPassword.isEmpty else { return }
        if isRegistering && trimmedName.isEmpty { return }

        isLoading = true
        errorMessage = ""

        if isRegistering {
            networkService.register(
                username: trimmedUsername,
                password: trimmedPassword,
                name: trimmedName
            ) { result in
                handleAuthResult(result)
            }
        } else {
            networkService.login(
                username: trimmedUsername,
                password: trimmedPassword
            ) { result in
                handleAuthResult(result)
            }
        }
    }

    private func handleAuthResult(_ result: Result<AuthResponse, Error>) {
        DispatchQueue.main.async {
            isLoading = false

            switch result {
            case .success(let response):
                guard response.success,
                      let token = response.token,
                      let user = response.user else {
                    errorMessage = response.error ?? "Не удалось выполнить вход"
                    showAlert = true
                    return
                }

                AuthManager.shared.saveAuth(token: token, user: user)
                errorMessage = ""

            case .failure(let error):
                errorMessage = error.localizedDescription
                showAlert = true
            }
        }
    }
}
