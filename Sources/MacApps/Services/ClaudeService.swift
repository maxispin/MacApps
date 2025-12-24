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

    func getDescription(for appName: String, bundleId: String?, type: DescriptionType) -> String? {
        guard let path = claudePath else { return nil }

        let prompt = buildPrompt(appName: appName, bundleId: bundleId, type: type)

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

    private func buildPrompt(appName: String, bundleId: String?, type: DescriptionType) -> String {
        let escapedName = appName.replacingOccurrences(of: "'", with: "\\'")

        switch type {
        case .short:
            var prompt = "Write a brief description (5-10 words) of the Mac application '\(escapedName)'"
            if let bundleId = bundleId {
                prompt += " (bundle id: \(bundleId))"
            }
            prompt += ". Reply ONLY with the description, nothing else. Example: 'Image editing software' or 'Web browser for internet' or 'Code editor for developers'"
            return prompt

        case .expanded:
            var prompt = """
            Write a detailed description (20-40 words) of the Mac application '\(escapedName)'
            """
            if let bundleId = bundleId {
                prompt += " (bundle id: \(bundleId))"
            }
            prompt += """
            .
            Include:
            - Main purpose
            - Key features or capabilities
            - Target users or use cases
            - Relevant search keywords

            Reply ONLY with the description, nothing else. Make it searchable with relevant terms.
            Example: 'Professional image editing and graphic design software for photographers and designers. Features layers, filters, retouching tools. Photo manipulation, digital art creation.'
            """
            return prompt
        }
    }
}
