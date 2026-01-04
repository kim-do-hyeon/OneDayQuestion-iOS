//
//  QuestionService.swift
//  OneDayQuestion
//
//  Created by pental-macbook on 1/4/26.
//

import Foundation

struct QuestionPublic: Decodable {
    let id: Int
    let questionDate: Date
    let prompt: String

    enum CodingKeys: String, CodingKey {
        case id
        case questionDate = "question_date"
        case prompt
    }
}

struct QuestionCreatePayload: Encodable {
    let questionDate: String
    let prompt: String

    enum CodingKeys: String, CodingKey {
        case questionDate = "question_date"
        case prompt
    }
}

enum QuestionServiceError: LocalizedError {
    case invalidURL
    case invalidResponse
    case api(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "서버 주소가 올바르지 않습니다."
        case .invalidResponse:
            return "서버 응답을 이해할 수 없습니다."
        case .api(let message):
            return message
        }
    }
}

final class QuestionService {
    private let baseURL: URL
    private let session: URLSession
    private let decoder: JSONDecoder

    init(baseURL: URL = URL(string: "https://oneday.system32.kr")!, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let value = try container.decode(String.self)
            if let date = QuestionService.parseDate(value) {
                return date
            }
            throw QuestionServiceError.invalidResponse
        }
        self.decoder = decoder
    }

    func fetchTodayQuestion() async throws -> QuestionPublic {
        let url = baseURL.appendingPathComponent("questions/today")
        let (data, response) = try await session.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw QuestionServiceError.invalidResponse
        }
        if !(200...299).contains(httpResponse.statusCode) {
            if let apiError = try? decoder.decode(APIErrorResponse.self, from: data),
               let detail = apiError.detail {
                throw QuestionServiceError.api(detail)
            }
            throw QuestionServiceError.api("요청에 실패했습니다. (\(httpResponse.statusCode))")
        }
        do {
            return try decoder.decode(QuestionPublic.self, from: data)
        } catch {
            throw QuestionServiceError.invalidResponse
        }
    }

    func createQuestion(date: Date, prompt: String, token: String) async throws -> QuestionPublic {
        let url = baseURL.appendingPathComponent("questions")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"

        let payload = QuestionCreatePayload(
            questionDate: formatter.string(from: date),
            prompt: prompt
        )
        request.httpBody = try JSONEncoder().encode(payload)

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw QuestionServiceError.invalidResponse
        }
        if !(200...299).contains(httpResponse.statusCode) {
            if let apiError = try? decoder.decode(APIErrorResponse.self, from: data),
               let detail = apiError.detail {
                throw QuestionServiceError.api(detail)
            }
            throw QuestionServiceError.api("요청에 실패했습니다. (\(httpResponse.statusCode))")
        }
        do {
            return try decoder.decode(QuestionPublic.self, from: data)
        } catch {
            throw QuestionServiceError.invalidResponse
        }
    }

    private static func parseDate(_ value: String) -> Date? {
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = isoFormatter.date(from: value) {
            return date
        }

        let fallback = DateFormatter()
        fallback.locale = Locale(identifier: "en_US_POSIX")
        fallback.timeZone = TimeZone(secondsFromGMT: 0)
        fallback.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSS"
        if let date = fallback.date(from: value) {
            return date
        }

        fallback.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        if let date = fallback.date(from: value) {
            return date
        }

        fallback.dateFormat = "yyyy-MM-dd"
        return fallback.date(from: value)
    }
}
