import ArgumentParser

@available(macOS 10.15, macCatalyst 13, iOS 13, tvOS 13, watchOS 6, *)
struct RemindersToTodoistTool: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "reminders-to-todoist",
        abstract: "Sync Apple Reminders to Todoist via Siri",
        version: "1.0.0",
        subcommands: [SyncCommand.self, SetupCommand.self, UninstallCommand.self],
        defaultSubcommand: SyncCommand.self
    )
}

RemindersToTodoistTool.main()
