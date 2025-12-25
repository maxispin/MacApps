import Foundation

class ClaudeService {

    private var claudePath: String?

    init() {
        self.claudePath = findClaudePath()
    }

    private func findClaudePath() -> String? {
        let paths = [
            "/usr/local/bin/claude",
            "/opt/homebrew/bin/claude",
            "\(NSHomeDirectory())/.local/bin/claude",
            "\(NSHomeDirectory())/bin/claude",
            "\(NSHomeDirectory())/.claude/local/claude"
        ]

        for path in paths {
            if FileManager.default.fileExists(atPath: path) {
                return path
            }
        }

        // Try which command
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        process.arguments = ["claude"]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let path = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
               !path.isEmpty {
                return path
            }
        } catch {}

        return nil
    }

    var isAvailable: Bool {
        claudePath != nil
    }

    /// Result with timing info
    struct DescriptionResult {
        let text: String?
        let durationMs: Int
    }

    /// Result for category
    struct CategoryResult {
        let category: AppCategory?
        let durationMs: Int
    }

    /// Result for functions
    struct FunctionsResult {
        let functions: [String]
        let durationMs: Int
    }

    func getDescription(for appName: String, bundleId: String?, type: DescriptionType, language: String = "en") -> String? {
        return getDescriptionWithTiming(for: appName, bundleId: bundleId, type: type, language: language).text
    }

    /// Get category for an app
    func getCategoryWithTiming(for appName: String, bundleId: String?) -> CategoryResult {
        guard let path = claudePath else { return CategoryResult(category: nil, durationMs: 0) }

        let startTime = CFAbsoluteTimeGetCurrent()

        let escapedName = appName.replacingOccurrences(of: "'", with: "\\'")
        var prompt = "Categorize the Mac application '\(escapedName)'"
        if let bundleId = bundleId {
            prompt += " (bundle id: \(bundleId))"
        }
        prompt += """
         into ONE of these categories:
        - Productivity (office, notes, documents)
        - Development (coding, IDEs, databases)
        - Design (graphics, video, 3D, UI)
        - Media (music, video, photos, streaming)
        - Communication (email, chat, video calls)
        - Utilities (system tools, file managers)
        - Games (games, entertainment)
        - Finance (accounting, trading, banking)
        - Education (learning, courses, reference)
        - System (OS components, settings)
        - Other (if none fit)

        Reply with ONLY the category name, nothing else. Example: "Development"
        """

        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = ["-p", prompt]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            process.waitUntilExit()

            let durationMs = Int((CFAbsoluteTimeGetCurrent() - startTime) * 1000)

            if process.terminationStatus == 0 {
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                if let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) {
                    let category = parseCategory(from: output)
                    return CategoryResult(category: category, durationMs: durationMs)
                }
            }
            return CategoryResult(category: nil, durationMs: durationMs)
        } catch {
            let durationMs = Int((CFAbsoluteTimeGetCurrent() - startTime) * 1000)
            return CategoryResult(category: nil, durationMs: durationMs)
        }
    }

    /// Get functions/actions for an app
    func getFunctionsWithTiming(for appName: String, bundleId: String?, language: String = "en") -> FunctionsResult {
        guard let path = claudePath else { return FunctionsResult(functions: [], durationMs: 0) }

        let startTime = CFAbsoluteTimeGetCurrent()

        let escapedName = appName.replacingOccurrences(of: "'", with: "\\'")
        let langName = languageName(for: language)
        let inLanguage = language == "en" ? "" : " in \(langName)"

        var prompt = "List the main ACTIONS/FUNCTIONS a user can do with the Mac application '\(escapedName)'"
        if let bundleId = bundleId {
            prompt += " (bundle id: \(bundleId))"
        }
        prompt += """
        \(inLanguage).

        Format: One action per line. Short and simple: "verb + object" (2-3 words max).
        List 5-15 actions, most important first.

        FORBIDDEN: No praise words. No duplicate verb forms. Keep it simple!

        """
        if language == "fi" {
            prompt += """
            Examples:
            muokkaa kuvia
            rajaa valokuvia
            säädä värejä
            poista taustoja
            lisää suodattimia

            Reply ONLY with the list in Finnish, one per line.
            """
        } else {
            prompt += """
            Examples:
            edit images
            crop photos
            adjust colors
            remove backgrounds
            add filters

            Reply ONLY with the list in English, one per line.
            """
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = ["-p", prompt]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            process.waitUntilExit()

            let durationMs = Int((CFAbsoluteTimeGetCurrent() - startTime) * 1000)

            if process.terminationStatus == 0 {
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                if let output = String(data: data, encoding: .utf8) {
                    let functions = parseFunctions(from: output)
                    return FunctionsResult(functions: functions, durationMs: durationMs)
                }
            }
            return FunctionsResult(functions: [], durationMs: durationMs)
        } catch {
            let durationMs = Int((CFAbsoluteTimeGetCurrent() - startTime) * 1000)
            return FunctionsResult(functions: [], durationMs: durationMs)
        }
    }

    /// Parse functions from AI response (one per line)
    private func parseFunctions(from text: String) -> [String] {
        let lines = text.components(separatedBy: .newlines)
        var functions: [String] = []

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            // Skip empty lines, numbered prefixes, bullets
            var cleaned = trimmed
            // Remove common prefixes: "1.", "- ", "• ", etc.
            if let range = cleaned.range(of: #"^[\d\.\-\•\*]+\s*"#, options: .regularExpression) {
                cleaned = String(cleaned[range.upperBound...])
            }
            cleaned = cleaned.trimmingCharacters(in: .whitespaces)

            // Must start with lowercase letter (verb) and be 2-6 words
            let words = cleaned.components(separatedBy: " ").filter { !$0.isEmpty }
            if words.count >= 2 && words.count <= 6 && !cleaned.isEmpty {
                // Normalize: lowercase first word (verb)
                let normalized = cleaned.prefix(1).lowercased() + cleaned.dropFirst()
                functions.append(normalized)
            }
        }

        return functions
    }

    /// Parse category from AI response
    private func parseCategory(from text: String) -> AppCategory? {
        let lowercased = text.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)

        // Direct match
        for category in AppCategory.allCases {
            if lowercased == category.rawValue.lowercased() {
                return category
            }
        }

        // Partial match
        for category in AppCategory.allCases {
            if lowercased.contains(category.rawValue.lowercased()) {
                return category
            }
        }

        return .other
    }

    func getDescriptionWithTiming(for appName: String, bundleId: String?, type: DescriptionType, language: String = "en") -> DescriptionResult {
        guard let path = claudePath else { return DescriptionResult(text: nil, durationMs: 0) }

        let startTime = CFAbsoluteTimeGetCurrent()

        let prompt = buildPrompt(appName: appName, bundleId: bundleId, type: type, language: language)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = ["-p", prompt]

        let pipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = pipe
        process.standardError = errorPipe

        do {
            try process.run()
            process.waitUntilExit()

            let durationMs = Int((CFAbsoluteTimeGetCurrent() - startTime) * 1000)

            if process.terminationStatus == 0 {
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
                return DescriptionResult(text: output, durationMs: durationMs)
            }
            return DescriptionResult(text: nil, durationMs: durationMs)
        } catch {
            let durationMs = Int((CFAbsoluteTimeGetCurrent() - startTime) * 1000)
            return DescriptionResult(text: nil, durationMs: durationMs)
        }
    }

    /// Language name for prompts
    private func languageName(for code: String) -> String {
        switch code {
        case "fi": return "Finnish"
        case "sv": return "Swedish"
        case "de": return "German"
        case "fr": return "French"
        case "es": return "Spanish"
        case "it": return "Italian"
        case "ja": return "Japanese"
        case "zh": return "Chinese"
        case "ko": return "Korean"
        case "pt": return "Portuguese"
        case "ru": return "Russian"
        case "nl": return "Dutch"
        case "no": return "Norwegian"
        case "da": return "Danish"
        default: return "English"
        }
    }

    private func buildPrompt(appName: String, bundleId: String?, type: DescriptionType, language: String) -> String {
        let escapedName = appName.replacingOccurrences(of: "'", with: "\\'")
        let langName = languageName(for: language)
        let inLanguage = language == "en" ? "" : " in \(langName)"

        switch type {
        case .short:
            var prompt = "Write a brief description (5-10 words)\(inLanguage) of the Mac application '\(escapedName)'"
            if let bundleId = bundleId {
                prompt += " (bundle id: \(bundleId))"
            }
            prompt += """
            . Focus on ACTION VERBS - what can user DO with this app.

            IMPORTANT: Include BOTH verb forms for searchability:
            - English: "edit editing, write writing, create creating"
            - Finnish: "muokkaa muokkaaminen, kirjoita kirjoittaminen"

            FORBIDDEN: NO ADJECTIVES! Only verbs and nouns. Never describe app qualities, only actions.

            Reply ONLY with the description\(inLanguage), nothing else.
            """
            if language == "fi" {
                prompt += " Example: 'Muokkaa muokkaaminen kuvia, retusoi retusoiminen, rajaa rajaaminen'"
            } else {
                prompt += " Example: 'Edit editing photos, retouch retouching, crop cropping'"
            }
            return prompt

        case .expanded:
            var prompt = """
            Write a searchable description (use ALL 255 characters)\(inLanguage) of the Mac application '\(escapedName)'
            """
            if let bundleId = bundleId {
                prompt += " (bundle id: \(bundleId))"
            }
            prompt += """
            .

            CRITICAL: Focus on ACTION VERBS - what can user DO with this app!
            The user knows what they want to DO, not the app name.

            IMPORTANT: Include BOTH verb forms for searchability:
            - English: "edit editing, write writing, create creating"
            - Finnish: "muokkaa muokkaaminen, kirjoita kirjoittaminen, tallenna tallentaminen"

            FORBIDDEN: NO ADJECTIVES! Only verbs and nouns. Never describe app qualities, only actions.

            Include verbs like:
            """
            if language == "fi" {
                prompt += """

                - kirjoita kirjoittaminen, muokkaa muokkaaminen, luo luominen
                - laske laskeminen, analysoi analysointi, suunnittele suunnittelu
                - tallenna tallentaminen, jaa jakaminen, lähetä lähettäminen
                - etsi etsiminen, selaa selaaminen, järjestä järjestäminen

                Reply ONLY with the description in Finnish. Use ALL 255 characters.
                Example: 'Muokkaa muokkaaminen kuvia, retusoi retusoiminen valokuvia, rajaa rajaaminen, säädä säätäminen värejä, lisää lisääminen suodattimia, poista poistaminen taustoja'
                """
            } else {
                prompt += """

                - write writing, edit editing, create creating, design designing
                - calculate calculating, analyze analyzing, save saving, share sharing
                - search searching, browse browsing, organize organizing, manage managing

                Reply ONLY with the description in English. Use ALL 255 characters.
                Example: 'Edit editing photos, retouch retouching images, crop cropping, adjust adjusting colors, add adding filters, remove removing backgrounds, merge merging layers, create creating collages'
                """
            }
            return prompt
        }
    }
}
