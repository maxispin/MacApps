import Foundation

// MARK: - App Scanner

struct AppInfo {
    let name: String
    let path: String
    let bundleIdentifier: String?
    let existingComment: String?
}

class AppScanner {
    
    func scanApplications() -> [AppInfo] {
        let fileManager = FileManager.default
        let applicationsPath = "/Applications"
        
        guard let contents = try? fileManager.contentsOfDirectory(atPath: applicationsPath) else {
            print("Virhe: Ei voitu lukea /Applications-kansiota")
            return []
        }
        
        var apps: [AppInfo] = []
        
        for item in contents where item.hasSuffix(".app") {
            let appPath = "\(applicationsPath)/\(item)"
            let appName = String(item.dropLast(4)) // Poista .app
            
            let bundleId = getBundleIdentifier(appPath: appPath)
            let existingComment = getFinderComment(path: appPath)
            
            apps.append(AppInfo(
                name: appName,
                path: appPath,
                bundleIdentifier: bundleId,
                existingComment: existingComment
            ))
        }
        
        return apps.sorted { $0.name.lowercased() < $1.name.lowercased() }
    }
    
    private func getBundleIdentifier(appPath: String) -> String? {
        let plistPath = "\(appPath)/Contents/Info.plist"
        guard let plistData = FileManager.default.contents(atPath: plistPath),
              let plist = try? PropertyListSerialization.propertyList(from: plistData, format: nil) as? [String: Any] else {
            return nil
        }
        return plist["CFBundleIdentifier"] as? String
    }
    
    private func getFinderComment(path: String) -> String? {
        let script = """
        tell application "Finder"
            set theFile to POSIX file "\(path)" as alias
            return comment of theFile
        end tell
        """
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", script]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        
        do {
            try process.run()
            process.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
            return output?.isEmpty == true ? nil : output
        } catch {
            return nil
        }
    }
}

// MARK: - Claude CLI Integration

class ClaudeDescriber {
    
    func getDescription(for appName: String, bundleId: String?) -> String? {
        var prompt = "Kirjoita lyhyt (max 10 sanaa) suomenkielinen kuvaus Mac-sovelluksesta '\(appName)'"
        if let bundleId = bundleId {
            prompt += " (bundle id: \(bundleId))"
        }
        prompt += ". Vastaa VAIN kuvaus, ei mitään muuta. Esim: 'Kuvankäsittelyohjelma' tai 'Selain internetin selaamiseen' tai 'Koodieditori ohjelmoijille'"
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/local/bin/claude")
        
        // Kokeile eri polkuja claudelle
        let claudePaths = [
            "/usr/local/bin/claude",
            "/opt/homebrew/bin/claude",
            "\(NSHomeDirectory())/.local/bin/claude",
            "\(NSHomeDirectory())/bin/claude"
        ]
        
        var claudePath: String?
        for path in claudePaths {
            if FileManager.default.fileExists(atPath: path) {
                claudePath = path
                break
            }
        }
        
        // Jos ei löydy, kokeile which-komentoa
        if claudePath == nil {
            let whichProcess = Process()
            whichProcess.executableURL = URL(fileURLWithPath: "/usr/bin/which")
            whichProcess.arguments = ["claude"]
            let whichPipe = Pipe()
            whichProcess.standardOutput = whichPipe
            try? whichProcess.run()
            whichProcess.waitUntilExit()
            let whichData = whichPipe.fileHandleForReading.readDataToEndOfFile()
            if let path = String(data: whichData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines), !path.isEmpty {
                claudePath = path
            }
        }
        
        guard let finalClaudePath = claudePath else {
            print("  ⚠️  Claude CLI:tä ei löydy")
            return nil
        }
        
        process.executableURL = URL(fileURLWithPath: finalClaudePath)
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
        } catch {
            print("  ⚠️  Virhe Claude CLI:n suorituksessa: \(error)")
        }
        
        return nil
    }
}

// MARK: - Finder Comment Writer

class MetadataWriter {
    
    func setFinderComment(path: String, comment: String) -> Bool {
        let escapedComment = comment.replacingOccurrences(of: "\"", with: "\\\"")
        let script = """
        tell application "Finder"
            set theFile to POSIX file "\(path)" as alias
            set comment of theFile to "\(escapedComment)"
        end tell
        """
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", script]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        
        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus == 0
        } catch {
            return false
        }
    }
}

// MARK: - Main

func main() {
    print("🔍 MacApps - Sovellusten metatietojen päivitys")
    print("=" .padding(toLength: 50, withPad: "=", startingAt: 0))
    print("")
    
    let scanner = AppScanner()
    let describer = ClaudeDescriber()
    let writer = MetadataWriter()
    
    print("📂 Skannataan /Applications-kansio...")
    let apps = scanner.scanApplications()
    print("   Löydettiin \(apps.count) sovellusta")
    print("")
    
    var processed = 0
    var skipped = 0
    var failed = 0
    
    for (index, app) in apps.enumerated() {
        print("[\(index + 1)/\(apps.count)] \(app.name)")
        
        // Ohita jos kommentti on jo olemassa
        if let existing = app.existingComment, !existing.isEmpty {
            print("   ⏭️  Ohitetaan - kommentti on jo: \"\(existing)\"")
            skipped += 1
            continue
        }
        
        // Hae kuvaus Claudelta
        print("   🤖 Haetaan kuvaus...")
        guard let description = describer.getDescription(for: app.name, bundleId: app.bundleIdentifier) else {
            print("   ❌ Kuvausta ei saatu")
            failed += 1
            continue
        }
        
        print("   📝 Kuvaus: \"\(description)\"")
        
        // Kirjoita Finder-kommentti
        if writer.setFinderComment(path: app.path, comment: description) {
            print("   ✅ Metatiedot päivitetty")
            processed += 1
        } else {
            print("   ❌ Metatietojen kirjoitus epäonnistui")
            failed += 1
        }
        
        // Pieni tauko API-kutsujen välillä
        Thread.sleep(forTimeInterval: 0.5)
    }
    
    print("")
    print("=" .padding(toLength: 50, withPad: "=", startingAt: 0))
    print("📊 Yhteenveto:")
    print("   ✅ Päivitetty: \(processed)")
    print("   ⏭️  Ohitettu: \(skipped)")
    print("   ❌ Epäonnistui: \(failed)")
    print("")
    print("💡 Vinkki: Etsi sovelluksia Finderissa hakemalla kuvauksella!")
}

main()
