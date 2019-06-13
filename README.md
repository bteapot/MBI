# MBI

Menu bar unread count indication for Mail.app in Mac OS.

### Usage

Enable Mail.app bundles:

	defaults write com.apple.mail EnableBundles -bool YES

Build the project. This will place `MBI.mailbundle` into `~/Desktop`. Copy it into  `~/Library/Mail/Bundles` and restart Mail.app.

On macOS Mojave open Mail.app, navigate to `Preferences / General / Manage Plug-ins…` and enable `MBI.mailbundle`.

 "Manage plug-ins" button gone from Mail in Mojave >= 10.14.5

 ```sh
 sudo defaults write "/Library/Preferences/com.apple.mail" EnableBundles 1
 ```

### Compatibility

For compatibility with future versions of Mail.app, use:

	defaults read /Applications/Mail.app/Contents/Info PluginCompatibilityUUID

This will extract UUID.

- For Mac OS < 10.12: Add it to project's `Info.plist` into `SupportedPluginCompatibilityUUIDs`.
- For macOS >= 10.12: Add it to project's `Info.plist` into `Supported%ld.%ldPluginCompatibilityUUIDs`, where `%ld.%ld` is the operating system version like `10.12`.

Build project and restart Mail.app.
