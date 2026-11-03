# HTML Arcade support

HTML Arcade is an independent, open-source iPhone and iPad app for playing self-contained HTML games. It requires iOS 17 or later.

## Import and play

1. Save a self-contained `.html` or `.htm` game to Files. Download iCloud files onto your device before going offline.
2. In HTML Arcade, tap **Import game**, or choose **Find → Browse device files** to search device storage.
3. Tap the imported game to play. Use the movable **•••** button to return to Library, restart the game, or choose an orientation.

**Orbit**, an original offline game, is included so you can try the player without downloading another game. Other games are imported by you; HTML Arcade does not include a third-party game catalog.

## Common questions

**My game is blank or missing images.** The player imports a single HTML file. If the game needs separate JavaScript, images, fonts, or audio files, use a self-contained export from its developer. Importing an ordinary webpage does not automatically download its dependencies. ZIPs and folders are not currently supported.

**The game asks me to rotate my phone.** Rotate to landscape, or use **••• → Orientation → Landscape**. Some games only support one layout.

**Will it work on a flight?** Before leaving, enable airplane mode, turn Wi-Fi off, and reopen the game. Check that the game starts, its assets load, and its own saving works. Online accounts, multiplayer, and remote assets still need a connection.

**Where is my progress?** Each imported game has its own WebKit data store. Progress is retained only if the game implements local saving. Reimporting a game creates a new library entry with separate saves. Removing an entry also removes its saves.

**Does the app need an account or payment?** The player has no account, subscriptions, or in-app purchases. Websites and imported games may have their own requirements.

## Get help or suggest a game

[Open a GitHub issue](https://github.com/somethingwentwell/html-game-player/issues/new) with your device, iOS version, game source, and steps to reproduce the problem. Do not include passwords, tokens, private save files, or personal information; issues are public.

Good game recommendations and app improvements are welcome by pull request. See [the README](README.md), [contribution guide](CONTRIBUTING.md), and [privacy policy](PRIVACY.md).
