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

    func getDescription(for appName: String, bundleId: String?, type: DescriptionType, language: String = "en") -> String? {
        guard let path = claudePath else { return nil }

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

            if process.terminationStatus == 0 {
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
                return output
            }
        } catch {}

        return nil
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
            prompt += ". Focus on ACTION VERBS - what can user DO with this app. Reply ONLY with the description\(inLanguage), nothing else."
            if language == "fi" {
                prompt += " Example: 'Muokkaa kuvia, retusoi, rajaa, säädä värejä'"
            } else {
                prompt += " Example: 'Edit photos, retouch, crop, adjust colors'"
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

            Include many verbs like:
            """
            if language == "fi" {
                prompt += """

                - kirjoita, muokkaa, luo, suunnittele, piirrä, luonnostele
                - laske, analysoi, taulukoi, kaavio, graafi
                - tallenna, jaa, lähetä, synkronoi, varmuuskopioi
                - etsi, selaa, järjestä, hallitse, organisoi
                - toista, nauhoita, miksaa, editoi, leikkaa

                Reply ONLY with the description in Finnish. Use ALL 255 characters.
                Example: 'Muokkaa kuvia, retusoi valokuvia, rajaa, säädä värejä, lisää suodattimia, poista taustoja, yhdistä tasoja, luo kollaaseja, piirrä, maalaa digitaalista taidetta, suunnittele grafiikoita, vie eri formaatteihin'
                """
            } else {
                prompt += """

                - write, edit, create, design, draw, sketch
                - calculate, analyze, spreadsheet, chart, graph
                - save, share, send, sync, backup
                - search, browse, organize, manage, sort
                - play, record, mix, edit, cut

                Reply ONLY with the description in English. Use ALL 255 characters.
                Example: 'Edit photos, retouch images, crop, adjust colors, add filters, remove backgrounds, merge layers, create collages, draw, paint digital art, design graphics, export to various formats, batch process'
                """
            }
            return prompt
        }
    }
}
