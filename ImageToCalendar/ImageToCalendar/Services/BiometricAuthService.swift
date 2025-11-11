//
//  BiometricAuthService.swift
//  ImageToCalendar
//
//  Biometric authentication service (Face ID / Touch ID)
//

import Foundation
import LocalAuthentication

class BiometricAuthService {
    static let shared = BiometricAuthService()

    private init() {}

    /// Check if biometric authentication is available
    func isBiometricAvailable() -> (available: Bool, biometryType: LABiometryType, error: String?) {
        let context = LAContext()
        var error: NSError?

        let canEvaluate = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)

        if canEvaluate {
            return (true, context.biometryType, nil)
        } else {
            return (false, context.biometryType, error?.localizedDescription)
        }
    }

    /// Get biometric type name for display
    func getBiometricTypeName() -> String {
        let context = LAContext()
        _ = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)

        switch context.biometryType {
        case .faceID:
            return "Face ID"
        case .touchID:
            return "Touch ID"
        case .none:
            return "生物识别"
        @unknown default:
            return "生物识别"
        }
    }

    /// Authenticate user with biometrics
    func authenticate(reason: String? = nil) async throws -> Bool {
        let context = LAContext()
        context.localizedCancelTitle = "取消"
        context.localizedFallbackTitle = "使用密码"

        let defaultReason = "验证您的身份以继续使用应用"
        let authReason = reason ?? defaultReason

        do {
            let success = try await context.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: authReason
            )
            return success
        } catch let error as LAError {
            throw BiometricAuthError.from(error)
        }
    }

    /// Authenticate with device passcode as fallback
    func authenticateWithPasscode(reason: String? = nil) async throws -> Bool {
        let context = LAContext()
        context.localizedCancelTitle = "取消"

        let defaultReason = "验证您的身份以继续使用应用"
        let authReason = reason ?? defaultReason

        do {
            let success = try await context.evaluatePolicy(
                .deviceOwnerAuthentication, // This includes biometrics + passcode
                localizedReason: authReason
            )
            return success
        } catch let error as LAError {
            throw BiometricAuthError.from(error)
        }
    }
}

enum BiometricAuthError: LocalizedError {
    case authenticationFailed
    case userCancel
    case userFallback
    case biometryNotAvailable
    case biometryNotEnrolled
    case biometryLockout
    case passcodeNotSet
    case unknown(String)

    var errorDescription: String? {
        switch self {
        case .authenticationFailed:
            return "身份验证失败，请重试"
        case .userCancel:
            return "用户取消了验证"
        case .userFallback:
            return "用户选择使用密码"
        case .biometryNotAvailable:
            return "此设备不支持生物识别"
        case .biometryNotEnrolled:
            return "未设置生物识别，请在系统设置中配置"
        case .biometryLockout:
            return "生物识别已被锁定，请使用密码解锁"
        case .passcodeNotSet:
            return "未设置设备密码"
        case .unknown(let message):
            return "验证错误: \(message)"
        }
    }

    static func from(_ error: LAError) -> BiometricAuthError {
        switch error.code {
        case .authenticationFailed:
            return .authenticationFailed
        case .userCancel:
            return .userCancel
        case .userFallback:
            return .userFallback
        case .biometryNotAvailable:
            return .biometryNotAvailable
        case .biometryNotEnrolled:
            return .biometryNotEnrolled
        case .biometryLockout:
            return .biometryLockout
        case .passcodeNotSet:
            return .passcodeNotSet
        default:
            return .unknown(error.localizedDescription)
        }
    }
}
