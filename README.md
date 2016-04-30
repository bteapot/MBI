# MBI

Menu bar unread count indication for Mail.app in Mac OS.

### Usage

Enable Mail.app bundles:

	defaults write com.apple.mail EnableBundles -bool YES

Build project. This will place `MBI.mailbundle` into `~/Library/Mail/Bundles`. Restart Mail.app.

### Compatibility

For compatibility with future versions of Mail.app, use:

	defaults read /Applications/Mail.app/Contents/Info PluginCompatibilityUUID

This will extract UUID. Add it to project's `Info.plist` into `SupportedPluginCompatibilityUUIDs`. Build project and restart Mail.app.
