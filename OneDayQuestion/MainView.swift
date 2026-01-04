//
//  MainView.swift
//  OneDayQuestion
//
//  Created by pental-macbook on 1/4/26.
//

import SwiftUI

struct MainView: View {
    let onLogout: () -> Void
    @StateObject private var viewModel = MainViewModel()
    @State private var show = false
    @State private var showAdminSheet = false
    @State private var newQuestionDate = Date()
    @State private var newQuestionPrompt = ""
    let isAdmin: Bool
    let authToken: String?
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "M월 d일"
        return formatter
    }()

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.96, green: 0.96, blue: 0.90), Color(red: 0.92, green: 0.95, blue: 0.98)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 24) {
                HStack {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("오늘의 질문")
                            .font(.custom("AvenirNext-DemiBold", size: 16))
                            .foregroundStyle(Color(red: 0.32, green: 0.28, blue: 0.22))
                        Text("OneDay")
                            .font(.custom("AvenirNext-Bold", size: 30))
                            .foregroundStyle(Color(red: 0.18, green: 0.16, blue: 0.12))
                    }

                    Spacer()

                    Button("로그아웃") {
                        onLogout()
                    }
                    .font(.custom("AvenirNext-DemiBold", size: 13))
                    .foregroundStyle(Color(red: 0.52, green: 0.36, blue: 0.15))
                }

                if isAdmin {
                    Button {
                        showAdminSheet = true
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 18, weight: .semibold))
                            Text("관리자 질문 등록")
                                .font(.custom("AvenirNext-DemiBold", size: 15))
                        }
                        .padding(.vertical, 10)
                        .padding(.horizontal, 14)
                        .foregroundStyle(Color(red: 0.20, green: 0.18, blue: 0.12))
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(Color.white.opacity(0.85))
                        )
                    }
                    .opacity(show ? 1 : 0)
                    .offset(y: show ? 0 : 12)
                }

                VStack(alignment: .leading, spacing: 16) {
                    Text(questionTitle)
                        .font(.custom("AvenirNext-Bold", size: 22))
                        .foregroundStyle(Color(red: 0.20, green: 0.18, blue: 0.12))

                    Text(questionSubtitle)
                        .font(.custom("AvenirNext-Regular", size: 15))
                        .foregroundStyle(Color(red: 0.32, green: 0.28, blue: 0.22))
                }
                .padding(20)
                .background(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(Color.white.opacity(0.85))
                        .shadow(color: Color.black.opacity(0.08), radius: 14, x: 0, y: 8)
                )
                .opacity(show ? 1 : 0)
                .offset(y: show ? 0 : 14)

                Button {
                    // TODO: 답변 작성 화면으로 이동
                } label: {
                    HStack {
                        Spacer()
                        Text("작성하러 가기")
                            .font(.custom("AvenirNext-Bold", size: 17))
                        Spacer()
                    }
                    .padding(.vertical, 14)
                    .foregroundStyle(Color.white)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(Color(red: 0.20, green: 0.18, blue: 0.12))
                    )
                    .shadow(color: Color.black.opacity(0.14), radius: 16, x: 0, y: 10)
                }
                .opacity(show ? 1 : 0)
                .offset(y: show ? 0 : 20)

                Spacer()
            }
            .padding(24)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.5)) {
                show = true
            }
            viewModel.loadQuestion()
        }
        .sheet(isPresented: $showAdminSheet) {
            adminSheet
        }
    }

    private var questionTitle: String {
        if viewModel.isLoading {
            return "질문을 불러오는 중..."
        }
        if let question = viewModel.question {
            return question.prompt
        }
        return "오늘의 질문이 아직 준비되지 않았어요."
    }

    private var questionSubtitle: String {
        if viewModel.isLoading {
            return "잠시만 기다려 주세요."
        }
        if let question = viewModel.question {
            return "\(dateFormatter.string(from: question.questionDate)) · 모두에게 동일한 질문"
        }
        if let error = viewModel.errorMessage {
            return error
        }
        return "관리자가 질문을 등록하면 바로 보여드릴게요."
    }

    private var adminSheet: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 18) {
                DatePicker("질문 날짜", selection: $newQuestionDate, displayedComponents: .date)
                    .datePickerStyle(.compact)
                    .font(.custom("AvenirNext-Regular", size: 15))

                VStack(alignment: .leading, spacing: 8) {
                    Text("질문 내용")
                        .font(.custom("AvenirNext-DemiBold", size: 14))
                        .foregroundStyle(Color(red: 0.28, green: 0.24, blue: 0.18))

                    TextEditor(text: $newQuestionPrompt)
                        .frame(minHeight: 140)
                        .padding(10)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(Color(red: 0.97, green: 0.96, blue: 0.92))
                        )
                }

                if let notice = viewModel.adminNotice {
                    Text(notice)
                        .font(.custom("AvenirNext-Regular", size: 13))
                        .foregroundStyle(notice == "질문이 등록되었습니다." ? Color(red: 0.16, green: 0.45, blue: 0.26) : Color(red: 0.72, green: 0.20, blue: 0.18))
                }

                Button {
                    viewModel.submitQuestion(
                        date: newQuestionDate,
                        prompt: newQuestionPrompt,
                        token: authToken
                    )
                } label: {
                    HStack {
                        Spacer()
                        if viewModel.isSubmitting {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Text("등록하기")
                                .font(.custom("AvenirNext-Bold", size: 16))
                        }
                        Spacer()
                    }
                    .padding(.vertical, 12)
                    .foregroundStyle(Color.white)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color(red: 0.20, green: 0.18, blue: 0.12))
                    )
                }
                .disabled(viewModel.isSubmitting)

                Spacer()
            }
            .padding(22)
            .navigationTitle("질문 등록")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("닫기") {
                        showAdminSheet = false
                    }
                }
            }
        }
    }
}

#Preview {
    MainView(onLogout: {}, isAdmin: true, authToken: nil)
}
