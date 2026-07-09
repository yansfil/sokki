import Foundation
import SokkiCore

enum OpenAIClientError: LocalizedError {
    case badResponse(Int, String)
    case emptyOutput

    var errorDescription: String? {
        switch self {
        case .badResponse(let code, let message):
            return "OpenAI request failed (\(code)): \(message)"
        case .emptyOutput:
            return "OpenAI returned no text output"
        }
    }
}

/// Minimal Responses API client used for the optional Cleanup/Prompt modes.
struct OpenAIClient: Sendable {
    var endpoint = URL(string: "https://api.openai.com/v1/responses")!

    func transform(_ request: OpenAIRequest, apiKey: String) async throws -> String {
        var urlRequest = URLRequest(url: endpoint)
        urlRequest.httpMethod = "POST"
        urlRequest.timeoutInterval = request.timeoutSeconds
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        let body: [String: Any] = [
            "model": request.model,
            "input": request.input,
            "max_output_tokens": 900
        ]
        urlRequest.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: urlRequest)
        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(statusCode) else {
            let message = String(data: data.prefix(300), encoding: .utf8) ?? "unreadable body"
            throw OpenAIClientError.badResponse(statusCode, message)
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw OpenAIClientError.emptyOutput
        }
        // Prefer the convenience field when present.
        if let outputText = json["output_text"] as? String, !outputText.isEmpty {
            return outputText.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        guard let output = json["output"] as? [[String: Any]] else {
            throw OpenAIClientError.emptyOutput
        }
        var pieces: [String] = []
        for item in output where (item["type"] as? String) == "message" {
            guard let content = item["content"] as? [[String: Any]] else { continue }
            for part in content where (part["type"] as? String) == "output_text" {
                if let text = part["text"] as? String {
                    pieces.append(text)
                }
            }
        }
        let combined = pieces.joined().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !combined.isEmpty else { throw OpenAIClientError.emptyOutput }
        return combined
    }
}
