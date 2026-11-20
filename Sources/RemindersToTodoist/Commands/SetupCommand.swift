import Foundation
import ArgumentParser
import EventKit

@available(macOS 10.15, *)
struct SetupCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "setup",
        abstract: "Interactive setup wizard"
    )

    func run() async throws {
        print("🚀 reminders-to-todoist setup")
        print()

        // Step 1: Get Todoist API token
        print("📝 Step 1: Todoist API Token")
        print("   Get your token from: https://todoist.com/app/settings/integrations/developer")
        print()
        print("   Enter your Todoist API token (input hidden):")
        print("   > ", terminator: "")
        fflush(stdout)

        guard let token = readSecureInput(), !token.isEmpty else {
            print("❌ No token provided. Setup cancelled.")
            throw ExitCode.failure
        }

        // Step 2: Find binary path
        let binaryPath = findBinaryPath()
        print()
        print("🔍 Found binary at: \(binaryPath)")

        // Step 3: Create config directory
        let homeDir = FileManager.default.homeDirectoryForCurrentUser
        let configDir = homeDir.appendingPathComponent(".config/reminders-to-todoist")
        try? FileManager.default.createDirectory(at: configDir, withIntermediateDirectories: true)

        // Step 4: Store token (try Keychain first, fall back to file)
        print()
        print("🔐 Step 2: Storing token...")
        let keychain = KeychainService()
        let result = keychain.setToken(service: "com.user.reminders-to-todoist", account: "todoist-api-token", token: token)
        if result.success {
            print("✓ Token stored securely in macOS Keychain")
        } else {
            print("⚠️  Keychain storage failed: \(result.error ?? "Unknown error")")
            print("   Storing in config file instead (less secure)")
            let tokenFile = configDir.appendingPathComponent("token.txt")
            do {
                try token.write(to: tokenFile, atomically: true, encoding: .utf8)
                try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: tokenFile.path)
                print("✓ Token stored in \(tokenFile.path)")
            } catch {
                print("❌ Failed to store token: \(error.localizedDescription)")
                throw ExitCode.failure
            }
        }

        // Step 5: Install LaunchAgent
        print()
        print("⚙️  Step 3: Installing LaunchAgent...")
        do {
            try installLaunchAgent(binaryPath: binaryPath)
            print("✓ LaunchAgent installed and loaded")
        } catch {
            print("❌ Failed to install LaunchAgent: \(error.localizedDescription)")
            throw ExitCode.failure
        }

        // Step 6: Request EventKit permissions
        print()
        print("🔑 Step 4: Requesting Reminders permissions...")
        let eventKitService = EventKitService()
        let granted = try await eventKitService.requestRemindersAccess()

        if granted {
            print("✓ Reminders access granted")
        } else {
            print("⚠️  Reminders access denied. Please grant access in:")
            print("   System Settings > Privacy & Security > Reminders")
        }

        // Success!
        print()
        print("✅ Setup complete!")
        print()
        print("   Your reminders will now automatically sync to Todoist every 5 minutes.")
        print("   Try it: Say to Siri \"Remind me to test Todoist sync\"")
        print()
        print("   To check status:   launchctl list | grep reminders-to-todoist")
        print("   To view logs:      tail -f /tmp/reminders-to-todoist.log")
        print("   To uninstall:      reminders-to-todoist uninstall")
    }

    /// Reads password input without echoing to terminal
    private func readSecureInput() -> String? {
        let input = String(cString: getpass(""))
        return input.isEmpty ? nil : input
    }

    /// Finds the path to the current binary
    private func findBinaryPath() -> String {
        // Get the executable path and resolve to absolute path
        if let executablePath = ProcessInfo.processInfo.arguments.first {
            let url = URL(fileURLWithPath: executablePath)

            // Resolve to absolute path
            let absolutePath: String
            if url.path.hasPrefix("/") {
                absolutePath = url.path
            } else {
                // Relative path - resolve it
                let currentDir = FileManager.default.currentDirectoryPath
                absolutePath = URL(fileURLWithPath: currentDir)
                    .appendingPathComponent(url.path)
                    .standardizedFileURL
                    .path
            }

            return absolutePath
        }

        // Fallback to common install location
        return "/opt/homebrew/bin/reminders-to-todoist"
    }

    /// Installs the LaunchAgent plist and loads it
    private func installLaunchAgent(binaryPath: String) throws {
        let homeDir = FileManager.default.homeDirectoryForCurrentUser
        let launchAgentsDir = homeDir.appendingPathComponent("Library/LaunchAgents")
        let plistPath = launchAgentsDir.appendingPathComponent("com.user.reminders-to-todoist.plist")

        // Create LaunchAgents directory if needed
        try FileManager.default.createDirectory(at: launchAgentsDir, withIntermediateDirectories: true)

        // Generate plist content
        let plistContent = generatePlistContent(binaryPath: binaryPath)

        // Write plist
        try plistContent.write(to: plistPath, atomically: true, encoding: .utf8)

        // Unload existing agent if running
        let unloadProcess = Process()
        unloadProcess.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        unloadProcess.arguments = ["unload", plistPath.path]
        try? unloadProcess.run()
        unloadProcess.waitUntilExit()

        // Load agent
        let loadProcess = Process()
        loadProcess.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        loadProcess.arguments = ["load", plistPath.path]
        try loadProcess.run()
        loadProcess.waitUntilExit()

        guard loadProcess.terminationStatus == 0 else {
            throw NSError(domain: "SetupError", code: Int(loadProcess.terminationStatus),
                         userInfo: [NSLocalizedDescriptionKey: "launchctl load failed"])
        }
    }

    /// Generates the LaunchAgent plist content
    private func generatePlistContent(binaryPath: String) -> String {
        return """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>Label</key>
            <string>com.user.reminders-to-todoist</string>

            <key>ProgramArguments</key>
            <array>
                <string>\(binaryPath)</string>
            </array>

            <key>StartInterval</key>
            <integer>300</integer>

            <key>RunAtLoad</key>
            <true/>

            <key>StandardOutPath</key>
            <string>/tmp/reminders-to-todoist.log</string>

            <key>StandardErrorPath</key>
            <string>/tmp/reminders-to-todoist.err</string>
        </dict>
        </plist>
        """
    }
}
