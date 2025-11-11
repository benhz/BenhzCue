//
//  DifyService.swift
//  ImageToCalendar
//
//  Service for communicating with Dify workflow via backend
//

import Foundation
import UIKit

class DifyService {
    static let shared = DifyService()

    private let backendURL: String
    private let timeout: TimeInterval = 30.0

    private init() {
        // Load from configuration or environment
        self.backendURL = ProcessInfo.processInfo.environment["BACKEND_URL"] ?? "https://your-backend.vercel.app"
    }

    /// Upload image and optional text to backend, trigger Dify workflow
    func parseImageToEvents(image: UIImage, additionalText: String?) async throws -> DifyResponse {
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            throw DifyError.invalidImage
        }

        // Create multipart form data
        let boundary = UUID().uuidString
        var body = Data()

        // Add image
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"image\"; filename=\"image.jpg\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
        body.append(imageData)
        body.append("\r\n".data(using: .utf8)!)

        // Add optional text
        if let text = additionalText, !text.isEmpty {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"text\"\r\n\r\n".data(using: .utf8)!)
            body.append(text.data(using: .utf8)!)
            body.append("\r\n".data(using: .utf8)!)
        }

        body.append("--\(boundary)--\r\n".data(using: .utf8)!)

        // Create request
        guard let url = URL(string: "\(backendURL)/api/parse") else {
            throw DifyError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.httpBody = body
        request.timeoutInterval = timeout

        // Execute request
        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw DifyError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw DifyError.serverError(httpResponse.statusCode)
        }

        // Decode response
        let decoder = JSONDecoder()
        do {
            let difyResponse = try decoder.decode(DifyResponse.self, from: data)
            return difyResponse
        } catch {
            print("Decoding error: \(error)")
            throw DifyError.decodingError(error)
        }
    }
}

enum DifyError: LocalizedError {
    case invalidImage
    case invalidURL
    case invalidResponse
    case serverError(Int)
    case decodingError(Error)

    var errorDescription: String? {
        switch self {
        case .invalidImage:
            return "Unable to process the selected image"
        case .invalidURL:
            return "Invalid backend URL configuration"
        case .invalidResponse:
            return "Received invalid response from server"
        case .serverError(let code):
            return "Server error: \(code)"
        case .decodingError(let error):
            return "Failed to parse response: \(error.localizedDescription)"
        }
    }
}
