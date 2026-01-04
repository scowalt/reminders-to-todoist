import Foundation
import ArgumentParser

struct UninstallCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Uninstall LaunchAgent and cleanup"
    )

    @Flag(name: .long, help: "Also remove Todoist API token from Keychain")
    var removeToken = false

    @Flag(name: .long, help: "Also remove state file (sync history)")
    var removeState = false

    func run() throws {
        print("🗑️  Uninstalling reminders-to-todoist...")
        print()

        var errors: [String] = []

        // Step 1: Unload and remove LaunchAgent
        print("📦 Removing LaunchAgent...")
        do {
            try removeLaunchAgent()
            print("✓ LaunchAgent removed")
        } catch {
            let errorMsg = "Failed to remove LaunchAgent: \(error.localizedDescription)"
            print("⚠️  \(errorMsg)")
            errors.append(errorMsg)
        }

        // Step 2: Remove token from Keychain (if requested)
        if removeToken {
            print()
            print("🔐 Removing token from Keychain...")
            let keychain = KeychainService()
            if keychain.deleteToken(service: "com.user.reminders-to-todoist", account: "todoist-api-token") {
                print("✓ Token removed from Keychain")
            } else {
                let errorMsg = "Failed to remove token from Keychain"
                print("⚠️  \(errorMsg)")
                errors.append(errorMsg)
            }
        } else {
            print()
            print("ℹ️  Token left in Keychain (use --remove-token to remove)")
        }

        // Step 3: Remove state file (if requested)
        if removeState {
            print()
            print("📝 Removing state file...")
            let homeDir = FileManager.default.homeDirectoryForCurrentUser
            let stateFile = homeDir.appendingPathComponent(".config/reminders-to-todoist/state.json")

            do {
                try FileManager.default.removeItem(at: stateFile)
                print("✓ State file removed")
            } catch {
                let errorMsg = "Failed to remove state file: \(error.localizedDescription)"
                print("⚠️  \(errorMsg)")
                errors.append(errorMsg)
            }
        } else {
            print()
            print("ℹ️  State file left intact (use --remove-state to remove)")
        }

        // Print summary
        print()
        if errors.isEmpty {
            print("✅ Uninstall complete!")
            print()
            print("   To reinstall:    reminders-to-todoist setup")
            print("   To remove fully: brew uninstall reminders-to-todoist")
        } else {
            print("⚠️  Uninstall completed with \(errors.count) warning(s):")
            for error in errors {
                print("   • \(error)")
            }
            throw ExitCode.failure
        }
    }

    /// Unloads and removes the LaunchAgent plist
    private func removeLaunchAgent() throws {
        let homeDir = FileManager.default.homeDirectoryForCurrentUser
        let plistPath = homeDir.appendingPathComponent("Library/LaunchAgents/com.user.reminders-to-todoist.plist")

        // Try to unload
        let unloadProcess = Process()
        unloadProcess.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        unloadProcess.arguments = ["unload", plistPath.path]
        try? unloadProcess.run()
        unloadProcess.waitUntilExit()

        // Remove plist file
        if FileManager.default.fileExists(atPath: plistPath.path) {
            try FileManager.default.removeItem(at: plistPath)
        }
    }
}
