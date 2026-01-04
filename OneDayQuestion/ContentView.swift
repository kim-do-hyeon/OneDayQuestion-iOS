//
//  ContentView.swift
//  OneDayQuestion
//
//  Created by pental-macbook on 1/4/26.
//

import SwiftUI

enum AuthMode: String, CaseIterable {
    case login = "로그인"
    case signup = "회원가입"
}

struct ContentView: View {
    @StateObject private var viewModel = AuthViewModel()
    @State private var reveal = false

    var body: some View {
        Group {
            if viewModel.isLoggedIn {
                MainView(
                    onLogout: viewModel.signOut,
                    isAdmin: viewModel.isAdmin,
                    authToken: viewModel.accessToken,
                    currentUserId: viewModel.userId
                )
            } else {
                ZStack {
                    backgroundView
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 24) {
                            header
                            modeToggle
                            form
                            primaryButton
                            footer
                        }
                        .padding(.horizontal, 28)
                        .padding(.top, 40)
                        .padding(.bottom, 32)
                    }
                }
                .onAppear {
                    withAnimation(.easeOut(duration: 0.6)) {
                        reveal = true
                    }
                }
            }
        }
    }

    private var backgroundView: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.97, green: 0.94, blue: 0.88), Color(red: 0.96, green: 0.98, blue: 0.96)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            Circle()
                .fill(Color(red: 0.85, green: 0.72, blue: 0.55).opacity(0.35))
                .frame(width: 280, height: 280)
                .offset(x: 140, y: -220)
                .blur(radius: 2)

            RoundedRectangle(cornerRadius: 80, style: .continuous)
                .fill(Color(red: 0.20, green: 0.18, blue: 0.12).opacity(0.18))
                .frame(width: 360, height: 360)
                .rotationEffect(.degrees(18))
                .offset(x: -180, y: 260)
                .blur(radius: 18)
        }
    }

    private var header: some View {
        VStack(spacing: 10) {
            Text("OneDay")
                .font(.custom("AvenirNext-Bold", size: 36))
                .foregroundStyle(Color(red: 0.20, green: 0.18, blue: 0.12))
                .opacity(reveal ? 1 : 0)
                .offset(y: reveal ? 0 : -12)

            Text("하루 한 줄, 당신의 생각을 기록하세요")
                .font(.custom("AvenirNext-Regular", size: 16))
                .foregroundStyle(Color(red: 0.30, green: 0.26, blue: 0.20))
                .opacity(reveal ? 1 : 0)
                .offset(y: reveal ? 0 : -12)
        }
    }

    private var modeToggle: some View {
        HStack(spacing: 0) {
            ForEach(AuthMode.allCases, id: \.self) { item in
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        viewModel.mode = item
                        viewModel.errorMessage = nil
                        viewModel.successMessage = nil
                    }
                } label: {
                    Text(item.rawValue)
                        .font(.custom("AvenirNext-DemiBold", size: 15))
                        .foregroundStyle(viewModel.mode == item ? Color.white : Color(red: 0.20, green: 0.18, blue: 0.12))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            ZStack {
                                if viewModel.mode == item {
                                    Capsule(style: .continuous)
                                        .fill(Color(red: 0.20, green: 0.18, blue: 0.12))
                                }
                            }
                        )
                }
            }
        }
        .padding(6)
        .background(
            Capsule(style: .continuous)
                .fill(Color.white.opacity(0.7))
        )
        .overlay(
            Capsule(style: .continuous)
                .stroke(Color.white.opacity(0.5), lineWidth: 1)
        )
        .opacity(reveal ? 1 : 0)
        .offset(y: reveal ? 0 : 14)
    }

    private var form: some View {
        VStack(spacing: 16) {
            AuthField(
                title: viewModel.isSignup ? "이메일" : "이메일 또는 아이디",
                text: $viewModel.emailOrUsername,
                keyboard: .emailAddress
            )
            if viewModel.isSignup {
                AuthField(title: "닉네임", text: $viewModel.username, keyboard: .default)
            }
            AuthField(title: "비밀번호", text: $viewModel.password, keyboard: .default, isSecure: true)
            if viewModel.isSignup {
                AuthField(title: "비밀번호 확인", text: $viewModel.confirmPassword, keyboard: .default, isSecure: true)
            }

            if let error = viewModel.errorMessage {
                Text(error)
                    .font(.custom("AvenirNext-Regular", size: 13))
                    .foregroundStyle(Color(red: 0.72, green: 0.20, blue: 0.18))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            if let success = viewModel.successMessage {
                Text(success)
                    .font(.custom("AvenirNext-Regular", size: 13))
                    .foregroundStyle(Color(red: 0.16, green: 0.45, blue: 0.26))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .opacity(reveal ? 1 : 0)
        .offset(y: reveal ? 0 : 20)
    }

    private var primaryButton: some View {
        Button {
            viewModel.submit()
        } label: {
            HStack {
                Spacer()
                if viewModel.isLoading {
                    ProgressView()
                        .tint(.white)
                } else {
                    Text(viewModel.isSignup ? "계정 만들기" : "로그인")
                        .font(.custom("AvenirNext-Bold", size: 17))
                }
                Spacer()
            }
            .padding(.vertical, 14)
            .foregroundStyle(Color.white)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color(red: 0.20, green: 0.18, blue: 0.12))
            )
            .shadow(color: Color.black.opacity(0.15), radius: 16, x: 0, y: 8)
        }
        .padding(.top, 8)
        .disabled(!viewModel.canSubmit || viewModel.isLoading)
        .opacity(reveal ? 1 : 0)
        .offset(y: reveal ? 0 : 24)
    }

    private var footer: some View {
        VStack(spacing: 12) {
            Text(viewModel.isSignup ? "이미 계정이 있으신가요?" : "아직 계정이 없으신가요?")
                .font(.custom("AvenirNext-Regular", size: 14))
                .foregroundStyle(Color(red: 0.36, green: 0.32, blue: 0.24))

            Button {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    viewModel.toggleMode()
                }
            } label: {
                Text(viewModel.isSignup ? "로그인으로 전환" : "회원가입으로 전환")
                    .font(.custom("AvenirNext-DemiBold", size: 14))
                    .foregroundStyle(Color(red: 0.52, green: 0.36, blue: 0.15))
            }
        }
        .padding(.top, 8)
        .opacity(reveal ? 1 : 0)
        .offset(y: reveal ? 0 : 28)
    }
}

struct AuthField: View {
    let title: String
    @Binding var text: String
    let keyboard: UIKeyboardType
    var isSecure: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.custom("AvenirNext-DemiBold", size: 13))
                .foregroundStyle(Color(red: 0.28, green: 0.24, blue: 0.18))

            if isSecure {
                SecureField("", text: $text)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .font(.custom("AvenirNext-Regular", size: 16))
            } else {
                TextField("", text: $text)
                    .keyboardType(keyboard)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .font(.custom("AvenirNext-Regular", size: 16))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.8))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.white.opacity(0.6), lineWidth: 1)
        )
    }
}

#Preview {
    ContentView()
}
