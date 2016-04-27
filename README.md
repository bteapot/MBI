# MBI

Menu bar unread count for Mail.app in Mac OS.

## Usage

Build project. This will place `MBI.mailbundle` into `~/Library/Mail/Bundles`. Restart Mail.app.

## Compatibility

For compatibility with future versions of Mail.app, use:

	defaults read /Applications/Mail.app/Contents/Info PluginCompatibilityUUID

This will extract UUID. Add it to project's `Info.plist` into `SupportedPluginCompatibilityUUIDs`. Build project and restart Mail.app.