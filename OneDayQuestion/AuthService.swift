//
//  AuthService.swift
//  OneDayQuestion
//
//  Created by pental-macbook on 1/4/26.
//

import Foundation

struct UserPublic: Decodable {
    let id: Int
    let email: String
    let username: String
    let isAdmin: Bool
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case email
        case username
        case isAdmin = "is_admin"
        case createdAt = "created_at"
    }
}

struct TokenResponse: Decodable {
    let accessToken: String
    let tokenType: String

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case tokenType = "token_type"
    }
}

struct ValidationErrorItem: Decodable {
    let msg: String
}

struct APIErrorResponse: Decodable {
    let detail: String?

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let stringDetail = try? container.decode(String.self, forKey: .detail) {
            detail = stringDetail
            return
        }
        if let items = try? container.decode([ValidationErrorItem].self, forKey: .detail) {
            let message = items.map { $0.msg }.joined(separator: ", ")
            detail = message.isEmpty ? nil : message
            return
        }
        detail = nil
    }

    private enum CodingKeys: String, CodingKey {
        case detail
    }
}

enum AuthServiceError: LocalizedError {
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

final class AuthService {
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
            if let date = AuthService.parseDate(value) {
                return date
            }
            throw AuthServiceError.invalidResponse
        }
        self.decoder = decoder
    }

    func signup(email: String, username: String, password: String) async throws -> UserPublic {
        let url = baseURL.appendingPathComponent("auth/signup")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let payload = [
            "email": email,
            "username": username,
            "password": password
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: payload, options: [])

        let (data, response) = try await session.data(for: request)
        return try decodeResponse(data: data, response: response)
    }

    func login(identifier: String, password: String) async throws -> TokenResponse {
        let url = baseURL.appendingPathComponent("auth/login")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = formURLEncoded([
            "username": identifier,
            "password": password
        ])

        let (data, response) = try await session.data(for: request)
        return try decodeResponse(data: data, response: response)
    }

    func fetchMe(token: String) async throws -> UserPublic {
        let url = baseURL.appendingPathComponent("users/me")
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await session.data(for: request)
        return try decodeResponse(data: data, response: response)
    }

    private func decodeResponse<T: Decodable>(data: Data, response: URLResponse) throws -> T {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AuthServiceError.invalidResponse
        }

        if !(200...299).contains(httpResponse.statusCode) {
            if let apiError = try? decoder.decode(APIErrorResponse.self, from: data),
               let detail = apiError.detail {
                throw AuthServiceError.api(detail)
            }
            throw AuthServiceError.api("요청에 실패했습니다. (\(httpResponse.statusCode))")
        }

        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw AuthServiceError.invalidResponse
        }
    }

    private func formURLEncoded(_ params: [String: String]) -> Data? {
        let query = params
            .map { key, value in
                "\(key.urlEncoded())=\(value.urlEncoded())"
            }
            .joined(separator: "&")
        return query.data(using: .utf8)
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

        fallback.dateFormat = "yyyy-MM-dd HH:mm:ss.SSSSSS"
        if let date = fallback.date(from: value) {
            return date
        }

        fallback.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return fallback.date(from: value)
    }
}

private extension String {
    func urlEncoded() -> String {
        addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? self
    }
}
