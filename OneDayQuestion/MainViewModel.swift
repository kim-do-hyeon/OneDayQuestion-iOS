//
//  MainViewModel.swift
//  OneDayQuestion
//
//  Created by pental-macbook on 1/4/26.
//

import Foundation
import Combine

@MainActor
final class MainViewModel: ObservableObject {
    @Published var question: QuestionPublic?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var isSubmitting = false
    @Published var adminNotice: String?
    @Published var answerNotice: String?

    private let service: QuestionService

    init(service: QuestionService = QuestionService()) {
        self.service = service
    }

    func loadQuestion() {
        Task {
            await fetchTodayQuestion()
        }
    }

    func submitQuestion(date: Date, prompt: String, token: String?) {
        Task {
            await createQuestion(date: date, prompt: prompt, token: token)
        }
    }

    func submitAnswer(content: String, isPublic: Bool, token: String?) {
        Task {
            await createAnswer(content: content, isPublic: isPublic, token: token)
        }
    }

    private func fetchTodayQuestion() async {
        isLoading = true
        errorMessage = nil

        do {
            question = try await service.fetchTodayQuestion()
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    private func createQuestion(date: Date, prompt: String, token: String?) async {
        guard let token else {
            adminNotice = "로그인이 필요합니다."
            return
        }
        let trimmed = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            adminNotice = "질문 내용을 입력해 주세요."
            return
        }

        isSubmitting = true
        adminNotice = nil

        do {
            question = try await service.createQuestion(date: date, prompt: trimmed, token: token)
            adminNotice = "질문이 등록되었습니다."
        } catch {
            adminNotice = error.localizedDescription
        }

        isSubmitting = false
    }

    private func createAnswer(content: String, isPublic: Bool, token: String?) async {
        guard let token else {
            answerNotice = "로그인이 필요합니다."
            return
        }
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            answerNotice = "답변을 입력해 주세요."
            return
        }

        isSubmitting = true
        answerNotice = nil

        do {
            _ = try await service.submitTodayAnswer(content: trimmed, isPublic: isPublic, token: token)
            answerNotice = "답변이 저장되었습니다."
        } catch {
            answerNotice = error.localizedDescription
        }

        isSubmitting = false
    }
}
