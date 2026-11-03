# Contributing

This started as my personal way to play HTML games on flights. Good game recommendations and small, useful app improvements are welcome.

## Recommend a game

A README-only pull request is enough. Add a row to the appropriate [game list](README.md#pokémon-html-game-list):

- **Tested:** you have a self-contained HTML file and verified it in HTML Arcade. Say which device you used, its orientation, how the touch controls behave, and whether it starts and saves with Wi-Fi off.
- **To explore:** an open-source browser game that still needs offline adaptation, single-file packaging, or testing. Say what remains to be done.

Include the original repository, the actual license link, a short description, and the author's download/build instructions. Other offline HTML games are welcome alongside Pokémon games. Source-available games should be identified as such, rather than called open source.

Keep recommendations small and useful. Link to the original game; do not add third-party game binaries or assets to this repo.

## Improve the player

Fork the repository, make a focused change, and open a PR explaining what changed and how you checked it. For app behavior changes, run the relevant tests and describe your iPhone/simulator check. README and game-list changes do not need an iOS build.

Use your own signing team and bundle identifier for development. Keep credentials, provisioning files, downloaded games, and build artifacts out of commits.
