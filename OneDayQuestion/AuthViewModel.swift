//
//  AuthViewModel.swift
//  OneDayQuestion
//
//  Created by pental-macbook on 1/4/26.
//

import Foundation
import Combine

@MainActor
final class AuthViewModel: ObservableObject {
    @Published var mode: AuthMode = .login
    @Published var emailOrUsername = ""
    @Published var username = ""
    @Published var password = ""
    @Published var confirmPassword = ""
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var successMessage: String?
    @Published var accessToken: String?
    @Published var isLoggedIn = false
    @Published var isAdmin = false

    private let service: AuthService

    init(service: AuthService = AuthService()) {
        self.service = service
        Task {
            await restoreSession()
        }
    }

    var isSignup: Bool {
        mode == .signup
    }

    var canSubmit: Bool {
        if isSignup {
            return !emailOrUsername.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                && !username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                && !password.isEmpty
                && password == confirmPassword
        }
        return !emailOrUsername.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !password.isEmpty
    }

    func toggleMode() {
        mode = isSignup ? .login : .signup
        errorMessage = nil
        successMessage = nil
    }

    func submit() {
        Task {
            await performSubmit()
        }
    }

    private func performSubmit() async {
        guard canSubmit else {
            errorMessage = isSignup ? "입력값을 확인해 주세요." : "아이디와 비밀번호를 입력해 주세요."
            return
        }

        errorMessage = nil
        successMessage = nil
        isLoading = true

        do {
            if isSignup {
                _ = try await service.signup(
                    email: emailOrUsername,
                    username: username,
                    password: password
                )
                successMessage = "계정이 생성되었습니다. 로그인해 주세요."
                mode = .login
            } else {
                let token = try await service.login(identifier: emailOrUsername, password: password)
                accessToken = token.accessToken
                KeychainService.saveToken(token.accessToken)
                let profile = try await service.fetchMe(token: token.accessToken)
                isAdmin = profile.isAdmin
                successMessage = "환영합니다!"
                isLoggedIn = true
            }
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    func signOut() {
        KeychainService.deleteToken()
        accessToken = nil
        isLoggedIn = false
        isAdmin = false
        emailOrUsername = ""
        password = ""
        confirmPassword = ""
        errorMessage = nil
        successMessage = nil
    }

    private func restoreSession() async {
        guard let token = KeychainService.loadToken() else {
            return
        }

        isLoading = true
        errorMessage = nil
        successMessage = nil

        do {
            let profile = try await service.fetchMe(token: token)
            accessToken = token
            isAdmin = profile.isAdmin
            isLoggedIn = true
        } catch {
            KeychainService.deleteToken()
            accessToken = nil
            isAdmin = false
            isLoggedIn = false
        }

        isLoading = false
    }
}
