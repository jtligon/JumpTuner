// AICharacterService.swift
// Calls the Claude API to turn a text description into AICharacterParams.

import Foundation

enum AICharacterError: LocalizedError {
    case noAPIKey
    case badResponse(Int)
    case malformedJSON(String)

    var errorDescription: String? {
        switch self {
        case .noAPIKey:          return "Enter your Anthropic API key in the field above."
        case .badResponse(let c):return "API returned HTTP \(c)."
        case .malformedJSON(let m): return "Could not read the response: \(m)"
        }
    }
}

struct AICharacterService {

    private static let endpoint = URL(string: "https://api.anthropic.com/v1/messages")!
    private static let model    = "claude-haiku-5-5"

    static func generate(description: String, apiKey: String) async throws -> AICharacterParams {
        guard !apiKey.trimmingCharacters(in: .whitespaces).isEmpty else {
            throw AICharacterError.noAPIKey
        }

        let systemPrompt = """
        You design 2D platformer game characters. Given a description, return ONLY a valid JSON object with these exact fields — no commentary, no markdown, no code fences, only the raw JSON:
        {
          "name": string — a fun short name for this character,
          "bodyHex": string — main body color as 6-digit hex (e.g. "4A90E2"),
          "accentHex": string — detail/accent color as 6-digit hex,
          "headShape": "round" | "square" | "diamond",
          "hasAntenna": boolean,
          "hasEars": boolean,
          "eyeCount": 1 | 2 | 3,
          "limbStyle": "normal" | "stubby"
        }
        Choose vivid, varied colors that match the character's personality.
        """

        let body: [String: Any] = [
            "model":      Self.model,
            "max_tokens": 512,
            "system":     systemPrompt,
            "messages":   [["role": "user", "content": description]]
        ]

        var request = URLRequest(url: Self.endpoint)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse, http.statusCode != 200 {
            throw AICharacterError.badResponse(http.statusCode)
        }

        // Extract the text content block
        guard
            let outer = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let content = outer["content"] as? [[String: Any]],
            let first   = content.first,
            let text    = first["text"] as? String
        else {
            throw AICharacterError.malformedJSON("unexpected envelope shape")
        }

        // The model returns raw JSON in the text block
        guard let jsonData = text.data(using: .utf8) else {
            throw AICharacterError.malformedJSON("non-UTF8 response")
        }

        do {
            return try JSONDecoder().decode(AICharacterParams.self, from: jsonData)
        } catch {
            throw AICharacterError.malformedJSON(error.localizedDescription)
        }
    }
}
