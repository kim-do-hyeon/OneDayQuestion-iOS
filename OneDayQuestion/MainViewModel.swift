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
    enum AnswerSort: String, CaseIterable {
        case latest = "최신순"
        case likes = "좋아요순"
    }

    @Published var question: QuestionPublic?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var isSubmitting = false
    @Published var adminNotice: String?
    @Published var answerNotice: String?
    @Published var answers: [AnswerPublic] = []
    @Published var visibleAnswers: [AnswerPublic] = []
    @Published var answersNotice: String?
    @Published var isLoadingAnswers = false
    @Published var hasAnswered = false
    @Published var isAnswersUnlocked = false
    @Published var myAnswerContent: String?
    @Published var myAnswerIsPublic = true
    @Published var didSaveAnswer = false
    @Published var currentUserId: Int?
    @Published var likingAnswerIds: Set<Int> = []
    @Published var answerSort: AnswerSort = .latest

    private let service: QuestionService
    private let pageSize = 10

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

    func loadAnswers(token: String?) {
        Task {
            await fetchPublicAnswers(token: token)
        }
    }

    func setCurrentUserId(_ userId: Int?) {
        currentUserId = userId
    }

    func checkMyAnswer(token: String?) {
        Task {
            await fetchMyAnswer(token: token)
        }
    }

    func unlockAnswers(token: String?) {
        answersNotice = nil
        guard hasAnswered else {
            answersNotice = "답변을 작성해야 다른 사람의 답변을 볼 수 있어요."
            return
        }
        isAnswersUnlocked = true
        loadAnswers(token: token)
    }

    func loadMoreAnswers() {
        let sorted = sortedAnswers()
        guard visibleAnswers.count < sorted.count else { return }
        let nextCount = min(visibleAnswers.count + pageSize, sorted.count)
        visibleAnswers = Array(sorted.prefix(nextCount))
    }

    func setAnswerSort(_ sort: AnswerSort) {
        answerSort = sort
        let currentCount = visibleAnswers.count
        let sorted = sortedAnswers()
        visibleAnswers = Array(sorted.prefix(max(currentCount, min(pageSize, sorted.count))))
    }

    func likeAnswer(answerId: Int, token: String?) {
        Task {
            await sendLike(answerId: answerId, token: token)
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
            hasAnswered = true
            myAnswerContent = trimmed
            myAnswerIsPublic = isPublic
            didSaveAnswer = true
            if isAnswersUnlocked {
                await fetchPublicAnswers(token: token)
            }
        } catch {
            answerNotice = error.localizedDescription
        }

        isSubmitting = false
    }

    private func fetchMyAnswer(token: String?) async {
        guard let token else {
            return
        }
        do {
            let response = try await service.fetchMyAnswer(token: token)
            hasAnswered = true
            myAnswerContent = response.content
            myAnswerIsPublic = response.isPublic
        } catch {
            hasAnswered = false
            myAnswerContent = nil
            myAnswerIsPublic = true
        }
    }

    private func fetchPublicAnswers(token: String?) async {
        guard let token else {
            answersNotice = "로그인이 필요합니다."
            return
        }

        isLoadingAnswers = true
        answersNotice = nil

        do {
            let list = try await service.fetchPublicAnswers(token: token)
            let filtered = list.filter { answer in
                guard let currentUserId else { return true }
                return answer.userId != currentUserId
            }
            answers = filtered
            visibleAnswers = Array(sortedAnswers().prefix(pageSize))
            if filtered.isEmpty {
                answersNotice = "아직 공개 답변이 없습니다."
            }
        } catch {
            answersNotice = error.localizedDescription
        }

        isLoadingAnswers = false
    }

    private func sendLike(answerId: Int, token: String?) async {
        guard let token else {
            answersNotice = "로그인이 필요합니다."
            return
        }
        guard !likingAnswerIds.contains(answerId) else { return }

        likingAnswerIds.insert(answerId)
        defer { likingAnswerIds.remove(answerId) }

        do {
            let newCount = try await service.likeAnswer(answerId: answerId, token: token)
            answers = answers.map { answer in
                guard answer.id == answerId else { return answer }
                return AnswerPublic(
                    id: answer.id,
                    userId: answer.userId,
                    questionId: answer.questionId,
                    content: answer.content,
                    isPublic: answer.isPublic,
                    createdAt: answer.createdAt,
                    updatedAt: answer.updatedAt,
                    likeCount: newCount
                )
            }
            let currentCount = visibleAnswers.count
            visibleAnswers = Array(sortedAnswers().prefix(currentCount))
        } catch {
            answersNotice = error.localizedDescription
        }
    }

    private func sortedAnswers() -> [AnswerPublic] {
        switch answerSort {
        case .latest:
            return answers.sorted { lhs, rhs in
                lhs.createdAt > rhs.createdAt
            }
        case .likes:
            return answers.sorted { lhs, rhs in
                if lhs.likeCount == rhs.likeCount {
                    return lhs.createdAt > rhs.createdAt
                }
                return lhs.likeCount > rhs.likeCount
            }
        }
    }
}
