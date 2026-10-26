import Foundation

final class ClaudeService: Sendable {

    private let claudePath: String?

    init() {
        self.claudePath = Self.findClaudePath()
    }

    private static func findClaudePath() -> String? {
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

    /// Keep only characters that can appear in an app name; strips quotes, newlines and control characters
    private static func sanitizeForPrompt(_ text: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: " .-_+&()"))
        let cleaned = text.unicodeScalars.filter { allowed.contains($0) }
        return String(String.UnicodeScalarView(cleaned)).trimmingCharacters(in: .whitespaces)
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

    /// Result for pricing
    struct PricingResult {
        let pricing: AppPricing?
        let durationMs: Int
    }

    /// Result for subcategory
    struct SubcategoryResult {
        let subcategory: String?
        let durationMs: Int
    }

    /// Unified result for all app data in one call
    struct UnifiedAppData {
        let category: AppCategory?
        let subcategory: String?
        let pricing: AppPricing?
        let functions: [String]
        let descriptions: [String: (short: String?, expanded: String?)]  // language -> descriptions
        let durationMs: Int

        static func empty(durationMs: Int = 0) -> UnifiedAppData {
            UnifiedAppData(category: nil, subcategory: nil, pricing: nil, functions: [], descriptions: [:], durationMs: durationMs)
        }

        /// True when Claude returned nothing usable (caller should keep existing data)
        var isEmpty: Bool {
            category == nil && subcategory == nil && pricing == nil && functions.isEmpty && descriptions.isEmpty
        }
    }

    /// Generate ALL app data in a single Claude call (optimized)
    func generateAllDataWithTiming(for appName: String, bundleId: String?, languages: [String]) -> UnifiedAppData {
        guard let path = claudePath else {
            return .empty()
        }

        let startTime = CFAbsoluteTimeGetCurrent()
        let escapedName = Self.sanitizeForPrompt(appName)
        let functionsLang = languageName(for: AppDatabase.systemLanguage)

        var prompt = """
        Analyze the Mac application '\(escapedName)'
        """
        if let bundleId = bundleId {
            prompt += " (bundle id: \(Self.sanitizeForPrompt(bundleId)))"
        }
        prompt += """
        .

        Return a JSON object with this EXACT structure:
        {
          "category": "ONE of: Productivity, Development, Design, Media, Communication, Utilities, Games, Finance, Education, System, Other",
          "subcategory": "ONE WORD describing main function (e.g., Email, IDE, Browser, Editor)",
          "pricing": "ONE of: Free, Freemium, Paid, Subscription, Open Source, Unknown",
          "functions": ["5-15 actions in \(functionsLang). Each item: verb + object, comma, noun form. e.g. 'edit images, image editing'"],
          "descriptions": {
        """

        for (index, lang) in languages.enumerated() {
            let langName = languageName(for: lang)
            prompt += """

            "\(lang)": {
              "short": "5-10 word description in \(langName)",
              "expanded": "20-40 word description in \(langName), at most 190 characters"
            }
        """
            if index < languages.count - 1 {
                prompt += ","
            }
        }

        prompt += """

          }
        }

        RULES:
        - NO ADJECTIVES! Only verbs and nouns
        - Focus on ACTION VERBS - what can user DO
        - Finnish verbs: IMPERATIVE (käskymuoto): muokkaa, kirjoita, hallitse
        - English verbs: base form: edit, write, manage
        - Return ONLY valid JSON, no other text

        """

        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = ["-p", prompt]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            // Read before waiting so a large response cannot fill the pipe and deadlock
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()

            let durationMs = Int((CFAbsoluteTimeGetCurrent() - startTime) * 1000)

            if process.terminationStatus == 0, let output = String(data: data, encoding: .utf8) {
                return parseUnifiedResponse(output, durationMs: durationMs)
            }
            return .empty(durationMs: durationMs)
        } catch {
            let durationMs = Int((CFAbsoluteTimeGetCurrent() - startTime) * 1000)
            return .empty(durationMs: durationMs)
        }
    }

    /// Parse the unified JSON response
    private func parseUnifiedResponse(_ text: String, durationMs: Int) -> UnifiedAppData {
        // Extract the outermost JSON object regardless of surrounding prose or code fences
        guard let startIndex = text.firstIndex(of: "{"),
              let endIndex = text.lastIndex(of: "}"),
              startIndex < endIndex else {
            return .empty(durationMs: durationMs)
        }
        let jsonText = String(text[startIndex...endIndex])

        guard let jsonData = jsonText.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
            return .empty(durationMs: durationMs)
        }

        // Parse category
        let category: AppCategory?
        if let catStr = json["category"] as? String {
            category = parseCategory(from: catStr)
        } else {
            category = nil
        }

        // Parse subcategory
        let subcategory = json["subcategory"] as? String

        // Parse pricing
        let pricing: AppPricing?
        if let priceStr = json["pricing"] as? String {
            pricing = parsePricing(from: priceStr)
        } else {
            pricing = nil
        }

        // Parse functions
        var functions: [String] = []
        if let list = json["functions"] as? [String] {
            functions = parseFunctions(from: list.joined(separator: "\n"))
        }

        // Parse descriptions
        var descriptions: [String: (short: String?, expanded: String?)] = [:]
        if let descs = json["descriptions"] as? [String: [String: String]] {
            for (lang, desc) in descs {
                descriptions[lang] = (short: desc["short"], expanded: desc["expanded"])
            }
        }

        return UnifiedAppData(
            category: category,
            subcategory: subcategory,
            pricing: pricing,
            functions: functions,
            descriptions: descriptions,
            durationMs: durationMs
        )
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

        Format: One action per line. Include BOTH forms for searchability:
        - verb + object
        - noun form (what it is)
        List 5-15 actions, most important first.

        VERB FORMAT:
        - Finnish: Use IMPERATIVE (käskymuoto): muokkaa, kirjoita, hallitse, tallenna
        - English: Use base form: edit, write, manage, save

        FORBIDDEN: No praise words. No adjectives!

        """
        if language == "fi" {
            prompt += """
            Examples (imperative verb + noun form):
            muokkaa kuvia, kuvankäsittely
            tallenna ääntä, äänitys
            rajaa valokuvia, rajaus
            säädä värejä, värisäätö
            poista taustoja, taustan poisto

            Reply ONLY with the list in Finnish, one per line.
            """
        } else {
            prompt += """
            Examples (base verb + noun form):
            edit images, image editing
            record audio, audio recording
            crop photos, photo cropping
            adjust colors, color adjustment
            remove backgrounds, background removal

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

    /// Get pricing model for an app
    func getPricingWithTiming(for appName: String, bundleId: String?) -> PricingResult {
        guard let path = claudePath else { return PricingResult(pricing: nil, durationMs: 0) }

        let startTime = CFAbsoluteTimeGetCurrent()

        let escapedName = appName.replacingOccurrences(of: "'", with: "\\'")
        var prompt = "What is the pricing model of the Mac application '\(escapedName)'"
        if let bundleId = bundleId {
            prompt += " (bundle id: \(bundleId))"
        }
        prompt += """
        ?

        Reply with ONLY one of these:
        - Free (completely free, no payment required)
        - Freemium (free with paid upgrades/features)
        - Paid (one-time purchase required)
        - Subscription (recurring payment required)
        - Open Source (free and open source)
        - Unknown (if you cannot determine)

        Reply with ONLY the pricing model, nothing else. Example: "Free"
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
                    let pricing = parsePricing(from: output)
                    return PricingResult(pricing: pricing, durationMs: durationMs)
                }
            }
            return PricingResult(pricing: nil, durationMs: durationMs)
        } catch {
            let durationMs = Int((CFAbsoluteTimeGetCurrent() - startTime) * 1000)
            return PricingResult(pricing: nil, durationMs: durationMs)
        }
    }

    /// Parse pricing from AI response
    private func parsePricing(from text: String) -> AppPricing? {
        let lowercased = text.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)

        if lowercased.contains("open source") { return .openSource }
        if lowercased.contains("subscription") { return .subscription }
        if lowercased.contains("freemium") { return .freemium }
        if lowercased.contains("paid") { return .paid }
        if lowercased.contains("free") { return .free }

        return .unknown
    }

    /// Get subcategory (main function in one word) for an app
    func getSubcategoryWithTiming(for appName: String, bundleId: String?, category: AppCategory?, language: String = "en") -> SubcategoryResult {
        guard let path = claudePath else { return SubcategoryResult(subcategory: nil, durationMs: 0) }

        let startTime = CFAbsoluteTimeGetCurrent()

        let escapedName = appName.replacingOccurrences(of: "'", with: "\\'")
        let langName = languageName(for: language)
        let inLanguage = language == "en" ? "" : " in \(langName)"

        var prompt = "What is the MAIN FUNCTION of the Mac application '\(escapedName)'"
        if let bundleId = bundleId {
            prompt += " (bundle id: \(bundleId))"
        }
        if let cat = category {
            prompt += " [category: \(cat.rawValue)]"
        }
        prompt += """
        \(inLanguage)?

        Reply with ONE WORD that describes its primary purpose.

        Examples by category:
        - Communication: Email, Chat, Video, Calls
        - Development: IDE, Editor, Terminal, Database
        - Media: Video, Audio, Photo, Streaming
        - Design: Graphics, UI, 3D, Vector
        - Productivity: Notes, Documents, Spreadsheet, Calendar
        - Utilities: Files, Backup, Security, Cleanup
        - Finance: Accounting, Trading, Banking, Budget

        Reply with ONLY one word\(inLanguage). No punctuation.
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
                if let output = String(data: data, encoding: .utf8)?
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .components(separatedBy: .whitespaces).first,  // Take first word only
                   !output.isEmpty {
                    // Capitalize first letter
                    let capitalized = output.prefix(1).uppercased() + output.dropFirst().lowercased()
                    return SubcategoryResult(subcategory: capitalized, durationMs: durationMs)
                }
            }
            return SubcategoryResult(subcategory: nil, durationMs: durationMs)
        } catch {
            let durationMs = Int((CFAbsoluteTimeGetCurrent() - startTime) * 1000)
            return SubcategoryResult(subcategory: nil, durationMs: durationMs)
        }
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

            VERB FORMAT:
            - Finnish: Use IMPERATIVE (käskymuoto): muokkaa, kirjoita, luo, hallitse, avaa
            - English: Use base form: edit, write, create, manage, open

            FORBIDDEN: NO ADJECTIVES! Only verbs and nouns.

            Reply ONLY with the description\(inLanguage), nothing else.
            """
            if language == "fi" {
                prompt += " Example: 'Muokkaa kuvia, retusoi valokuvia, rajaa'"
            } else {
                prompt += " Example: 'Edit photos, retouch images, crop'"
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

            VERB FORMAT:
            - Finnish: Use IMPERATIVE (käskymuoto): muokkaa, kirjoita, luo, hallitse, tallenna, jaa
            - English: Use base form: edit, write, create, manage, save, share

            FORBIDDEN: NO ADJECTIVES! Only verbs and nouns. Never describe app qualities, only actions.

            Include verbs like:
            """
            if language == "fi" {
                prompt += """

                - kirjoita, muokkaa, luo, suunnittele
                - laske, analysoi, tallenna, jaa
                - etsi, selaa, järjestä, hallitse

                Reply ONLY with the description in Finnish. Use ALL 255 characters.
                Example: 'Muokkaa kuvia, retusoi valokuvia, rajaa, säädä värejä, lisää suodattimia, poista taustoja, yhdistä tasoja, luo kollaaseja'
                """
            } else {
                prompt += """

                - write, edit, create, design, develop
                - calculate, analyze, save, share, export
                - search, browse, organize, manage, sync

                Reply ONLY with the description in English. Use ALL 255 characters.
                Example: 'Edit photos, retouch images, crop, adjust colors, add filters, remove backgrounds, merge layers, create collages'
                """
            }
            return prompt
        }
    }
}
