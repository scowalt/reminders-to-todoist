# reminders-to-todoist

Sync Apple Reminders to Todoist via Siri. Create tasks in Todoist by simply asking Siri!

## Features

- ✨ **Siri Integration** - Create Todoist tasks using Siri voice commands
- 🔄 **Automatic Sync** - Runs every 5 minutes in the background
- 🔒 **Secure** - API token stored in macOS Keychain
- 🗑️ **Clean** - Automatically deletes synced reminders from Apple Reminders
- 📝 **Complete** - Syncs title, description, due date, and priority

## Installation

### Via Homebrew (Recommended)

```bash
brew install scowalt/tap/reminders-to-todoist
reminders-to-todoist setup
```

### From Source

```bash
git clone https://github.com/scowalt/reminders-to-todoist
cd reminders-to-todoist
swift build -c release
cp .build/release/reminders-to-todoist /usr/local/bin/
reminders-to-todoist setup
```

## Setup

The `setup` command will guide you through:

1. **Get your Todoist API token**
   - Visit: https://todoist.com/app/settings/integrations/developer
   - Copy your API token

2. **Run setup**
   ```bash
   reminders-to-todoist setup
   ```

3. **Grant permissions**
   - When prompted, grant Reminders access in System Settings

That's it! Your reminders will now automatically sync to Todoist every 5 minutes.

## Usage

### Creating Tasks via Siri

Simply ask Siri:
- "Remind me to buy milk"
- "Remind me to call mom tomorrow at 3pm"
- "Remind me to finish the report"

Within 5 minutes, these will appear in your Todoist Inbox and disappear from Apple Reminders.

### Manual Sync

To trigger a sync immediately:
```bash
reminders-to-todoist
```

### Checking Status

View LaunchAgent status:
```bash
launchctl list | grep reminders-to-todoist
```

View logs:
```bash
tail -f /tmp/reminders-to-todoist.log
```

### Uninstalling

```bash
reminders-to-todoist uninstall
brew uninstall reminders-to-todoist  # if installed via Homebrew
```

## How It Works

1. Every 5 minutes, a LaunchAgent runs the sync command
2. The tool fetches all incomplete reminders from Apple Reminders
3. New reminders (not previously synced) are created in Todoist Inbox
4. Successfully synced reminders are deleted from Apple Reminders
5. Reminder IDs are tracked to prevent duplicates

## Priority Mapping

Apple Reminders priorities are mapped to Todoist as follows:

| Apple Priority | Todoist Priority |
|----------------|------------------|
| None (0)       | Normal (p4)      |
| High (1-4)     | Urgent (p1)      |
| Medium (5)     | High (p2)        |
| Low (6-9)      | Medium (p3)      |

## Troubleshooting

### Permissions Not Working

If Reminders access is denied:
1. Open System Settings
2. Go to Privacy & Security > Reminders
3. Enable access for `reminders-to-todoist`

### LaunchAgent Not Running

Reload the LaunchAgent:
```bash
launchctl unload ~/Library/LaunchAgents/com.user.reminders-to-todoist.plist
launchctl load ~/Library/LaunchAgents/com.user.reminders-to-todoist.plist
```

### Token Issues

If you need to update your Todoist token:
```bash
reminders-to-todoist uninstall --remove-token
reminders-to-todoist setup
```

### Viewing Errors

Check error logs:
```bash
cat /tmp/reminders-to-todoist.err
```

## Development

### Building

```bash
swift build
```

### Running Tests

```bash
swift test
```

### Local Testing

```bash
swift build
.build/debug/reminders-to-todoist setup
```

## License

MIT License - see LICENSE file for details

## Credits

Built with:
- [Swift ArgumentParser](https://github.com/apple/swift-argument-parser)
- Apple EventKit framework
- Todoist REST API

Inspired by:
- [FirePanther/Apple-Reminders-to-Todoist](https://github.com/FirePanther/Apple-Reminders-to-Todoist)
- [DaveHarrington/reminder-to-todoist](https://github.com/DaveHarrington/reminder-to-todoist)
