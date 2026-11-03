# HTML Arcade

I built this for myself so I can play HTML games on my iPhone during flights. Download a game before boarding, import it, and play with the whole screen—even without Wi-Fi.

I'm sharing the project so other people can do the same. If you find a good game for the next flight, **PRs to the game list are welcome**. Pokémon fan games are my starting point; other good offline HTML games are welcome too.

## Pack a game for your next flight

1. Get a **self-contained `.html` or `.htm` game** from its developer, or prepare an offline export from its source. It needs its scripts, images, audio, and other assets inside that file.
2. Save the file to your iPhone's Files app. If it is in iCloud Drive, download it onto the phone before boarding.
3. Open HTML Arcade → **Import game**, or **Find → Browse device files**. Use the Files picker's search to find the game in Downloads, On My iPhone, iCloud Drive, or connected storage.
4. Tap the game to play. Rotate your phone when the game needs landscape. The movable **•••** menu returns to your library, restarts the game, or changes orientation.
5. Before leaving, turn on airplane mode, turn Wi-Fi off, and reopen the game. Check that it starts, its assets load, and its own save/load works.

The app copies imported files into its library, so it does not need the original file afterward. Each game has separate persistent browser storage. Games that implement local saves can keep their progress; deleting a game also deletes its saves.

**Find** also lets you search the web or paste a game URL and import an HTML download. Importing a webpage does not automatically make its remote assets, account system, or server work offline. ZIPs and folders with separate assets are not supported yet.

## Pokémon HTML game list

### Tested in HTML Arcade

| Game | What it is | Flight notes | Source and license |
| --- | --- | --- | --- |
| **PokéSurvivor** | Pokémon survival / bullet-heaven fan game. | A locally prepared 104 MB single-file offline build was imported and opened in the iPhone simulator. **Landscape required.** The upstream repository's ordinary `index.html` is not that self-contained export. | [Original project](https://github.com/JPTER78/pokesurvivor) · [License](https://github.com/JPTER78/pokesurvivor/blob/main/LICENSE) |

PokéSurvivor is the game that started this project. Its current code is **source-available under PolyForm Noncommercial**, rather than an open-source license; upstream identifies older versions through `b297089` as MIT. It is listed separately so its terms are clear. The tested game file is not included in this repository.

### Open-source Pokémon browser games to explore

These are source projects worth exploring, **not a list of confirmed, ready-to-import downloads**. None of these has been tested in HTML Arcade yet. They need a working offline adaptation/export and single-file packaging before they can join the tested list.

| Game | What it is | Preparation needed for this player | Code license |
| --- | --- | --- | --- |
| [FullScreenPokemon](https://github.com/FullScreenShenanigans/FullScreenPokemon) | HTML5 remake of the original Pokémon, built for modern browsers. | Build the game and package its assets into one HTML file; check that its input works on an iPhone touchscreen. | [MIT](https://github.com/FullScreenShenanigans/FullScreenPokemon/blob/main/LICENSE.txt) |
| [PokéRogue](https://github.com/pagefaultgames/pokerogue) | Pokémon battles with roguelite runs, stacking items, and different biomes. | Needs an offline-capable adaptation and embedded assets. Importing the hosted game's page alone is insufficient. | [AGPL-3.0-only](https://github.com/pagefaultgames/pokerogue/blob/beta/LICENSES/AGPL-3.0-only.txt) |
| [Pokémon TCG Academy](https://github.com/f/pokemon-tcg) | Learn and play the Pokémon Trading Card Game against a CPU opponent. | Start with its CPU-only static web build, make its card images available offline, and package everything into one HTML file. Cloud/local-model engines are outside this player's scope. | [MIT](https://github.com/f/pokemon-tcg/blob/main/LICENSE) |

Game code, artwork, music, fonts, and Pokémon trademarks may have different owners and terms. Follow each project's own notices. HTML Arcade is an independent fan project with no affiliation with Nintendo, Game Freak, Creatures, or The Pokémon Company.

## Add a good game by PR

**Found something fun to play on a flight? Please add it to the list.** You do not have to change the app's code.

Fork this repo, edit the table in this README, and open a pull request. Include:

- The game's name, a short description, and its original source repository.
- Its code license and a link to the author's download or build instructions.
- Whether it comes as one HTML file or needs preparation.
- If you tested it: your device, portrait/landscape, touch controls, and whether startup and saving worked with Wi-Fi off.

Untested suggestions are welcome in the exploration list—just label them honestly. Please link to upstream games instead of committing game downloads, ROMs, or large asset bundles. App fixes and improvements are welcome too; see [CONTRIBUTING.md](CONTRIBUTING.md).

## Build your own player

Requires **Xcode** and an iPhone/iPad running **iOS 17 or later**. The app uses SwiftUI and WKWebView, with no third-party packages or app account required.

1. Clone this repository and open `HTMLArcade.xcodeproj` in Xcode.
2. Select the **HTMLArcade** target → **Signing & Capabilities**, choose your own Apple development team, and use your own unique bundle identifier.
3. Select your iPhone or an iOS simulator and press **Run**.
4. Import a game and try the airplane-mode check above.

If you regenerate the project with [XcodeGen](https://github.com/yonaskolb/XcodeGen), update the signing team and bundle identifier in `project.yml` first, then run `xcodegen generate`.

The bundled **Orbit** game is a small original offline sample, so you can try the player before finding another game. The Pokémon games linked above are not bundled. The existing TestFlight build is for my private testing; building the source does not require access to my Apple account.

## Development

```sh
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
xcodebuild -project HTMLArcade.xcodeproj -scheme HTMLArcade \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -parallel-testing-enabled NO test
```

Choose an available simulator name if yours differs. Tests cover imports that preserve every byte, separate game saves, duplicate filenames, invalid files, full-screen playback, and the native Files picker. The optional large-game tests run when a local `fixtures/PokeSurvivor-Offline.html` is present; that folder is git-ignored. Debug builds also accept an `ARCADE_IMPORT_FILE` environment variable for local fixtures.

Maintainer release instructions are in [TESTFLIGHT.md](TESTFLIGHT.md). Forks should use their own signing identity and App Store Connect configuration.

## Privacy

There is no analytics or account system in HTML Arcade. Imported games and saves live in app storage. Web searches use DuckDuckGo; websites and imported game code can contact their own services. Offline behavior depends on the game you import.

Read the [privacy policy](PRIVACY.md) or visit [support](SUPPORT.md).

## License

HTML Arcade's original code and the bundled Orbit sample are available under the [MIT License](LICENSE). Linked games retain their own licenses.
