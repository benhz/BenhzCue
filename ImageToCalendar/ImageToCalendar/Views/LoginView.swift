//
//  LoginView.swift
//  ImageToCalendar
//
//  Login screen with biometric authentication
//

import SwiftUI
import LocalAuthentication

struct LoginView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var viewModel = LoginViewModel()

    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                gradient: Gradient(colors: [Color.blue.opacity(0.6), Color.purple.opacity(0.6)]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 40) {
                Spacer()

                // App Logo and Title
                VStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(Color.white.opacity(0.3))
                            .frame(width: 120, height: 120)

                        Image(systemName: "calendar.badge.plus")
                            .font(.system(size: 60))
                            .foregroundColor(.white)
                    }

                    Text("Image to Calendar")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(.white)

                    Text("AI驱动的智能日程助手")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.9))
                }

                Spacer()

                // Biometric Authentication Section
                VStack(spacing: 20) {
                    if viewModel.isBiometricAvailable {
                        // Biometric Icon
                        Button(action: {
                            viewModel.authenticate()
                        }) {
                            VStack(spacing: 12) {
                                ZStack {
                                    Circle()
                                        .fill(Color.white)
                                        .frame(width: 80, height: 80)
                                        .shadow(color: .black.opacity(0.2), radius: 10)

                                    Image(systemName: viewModel.biometricIcon)
                                        .font(.system(size: 36))
                                        .foregroundColor(.blue)
                                }

                                Text("使用\(viewModel.biometricTypeName)登录")
                                    .font(.headline)
                                    .foregroundColor(.white)
                            }
                        }
                        .disabled(viewModel.isAuthenticating)
                        .opacity(viewModel.isAuthenticating ? 0.6 : 1.0)

                        // Alternative: Use Passcode
                        Button(action: {
                            viewModel.authenticateWithPasscode()
                        }) {
                            Text("使用密码")
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.9))
                                .underline()
                        }
                        .disabled(viewModel.isAuthenticating)

                    } else {
                        // Fallback when biometric not available
                        VStack(spacing: 16) {
                            Image(systemName: "lock.shield")
                                .font(.system(size: 40))
                                .foregroundColor(.white)

                            Text(viewModel.biometricUnavailableReason ?? "生物识别不可用")
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.9))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)

                            Button(action: {
                                viewModel.authenticateWithPasscode()
                            }) {
                                Text("使用设备密码登录")
                                    .font(.headline)
                                    .foregroundColor(.blue)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.white)
                                    .cornerRadius(12)
                                    .shadow(radius: 4)
                            }
                            .disabled(viewModel.isAuthenticating)
                            .padding(.horizontal, 40)
                        }
                    }

                    // Loading indicator
                    if viewModel.isAuthenticating {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(1.2)
                    }
                }

                Spacer()

                // Footer
                VStack(spacing: 8) {
                    Text("您的隐私受到保护")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.8))

                    Text("所有数据仅存储在您的设备上")
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.7))
                }
                .padding(.bottom, 40)
            }
            .padding()
        }
        .alert("验证失败", isPresented: $viewModel.showingError) {
            Button("重试") {
                viewModel.authenticate()
            }
            Button("取消", role: .cancel) {
                viewModel.errorMessage = nil
            }
        } message: {
            Text(viewModel.errorMessage ?? "未知错误")
        }
        .onAppear {
            viewModel.onAuthenticated = {
                appState.isAuthenticated = true
            }
            // Auto-trigger authentication on appear
            if viewModel.isBiometricAvailable {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    viewModel.authenticate()
                }
            }
        }
    }
}

@MainActor
class LoginViewModel: ObservableObject {
    @Published var isAuthenticating = false
    @Published var showingError = false
    @Published var errorMessage: String?
    @Published var isBiometricAvailable = false
    @Published var biometricTypeName = "生物识别"
    @Published var biometricIcon = "faceid"
    @Published var biometricUnavailableReason: String?

    var onAuthenticated: (() -> Void)?

    private let authService = BiometricAuthService.shared

    init() {
        checkBiometricAvailability()
    }

    func checkBiometricAvailability() {
        let result = authService.isBiometricAvailable()
        isBiometricAvailable = result.available
        biometricTypeName = authService.getBiometricTypeName()
        biometricUnavailableReason = result.error

        // Set icon based on biometry type
        let context = LAContext()
        _ = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)

        switch context.biometryType {
        case .faceID:
            biometricIcon = "faceid"
        case .touchID:
            biometricIcon = "touchid"
        default:
            biometricIcon = "lock.shield"
        }
    }

    func authenticate() {
        isAuthenticating = true
        errorMessage = nil

        Task {
            do {
                let success = try await authService.authenticate(reason: "登录以使用 Image to Calendar")
                if success {
                    await handleSuccessfulAuth()
                }
            } catch {
                await handleAuthError(error)
            }
            isAuthenticating = false
        }
    }

    func authenticateWithPasscode() {
        isAuthenticating = true
        errorMessage = nil

        Task {
            do {
                let success = try await authService.authenticateWithPasscode(reason: "登录以使用 Image to Calendar")
                if success {
                    await handleSuccessfulAuth()
                }
            } catch {
                await handleAuthError(error)
            }
            isAuthenticating = false
        }
    }

    private func handleSuccessfulAuth() async {
        // Save authentication state
        UserDefaults.standard.set(true, forKey: "hasAuthenticated")
        UserDefaults.standard.set(Date(), forKey: "lastAuthenticationDate")

        // Notify success
        onAuthenticated?()
    }

    private func handleAuthError(_ error: Error) async {
        if let authError = error as? BiometricAuthError {
            switch authError {
            case .userCancel:
                // User cancelled, don't show error
                return
            case .userFallback:
                // User wants to use passcode
                authenticateWithPasscode()
                return
            default:
                errorMessage = authError.localizedDescription
                showingError = true
            }
        } else {
            errorMessage = error.localizedDescription
            showingError = true
        }
    }
}

struct LoginView_Previews: PreviewProvider {
    static var previews: some View {
        LoginView()
            .environmentObject(AppState())
    }
}
