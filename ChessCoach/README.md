# ChessCoach iOS – Chess Training & Review

A standalone iOS app built in SwiftUI. It is not affiliated with Chessigma. The app offers independently implemented chess training features; it is not a pixel-for-pixel port of a third-party application.

## Implemented

- Connect a public Chess.com username, import recent standard games and analyze them locally with embedded Stockfish.
- Game review with move ratings, accuracy, evaluation graphs, best moves and training candidates.
- **Blunder Training** (free; no premium unlock needed): solve positions generated from mistakes and blunders in reviewed games.
- **Spaced repetition**: revisit failed positions quickly and successful ones at increasing intervals.
- **Woodpecker**: timed cycles over the current reviewed positions with an end-of-cycle report and a restart button.
- Home / Train / Coach / Games / Brain navigation.
- High-resolution, self-authored SVG chess-piece assets; vector rendering is preserved in the Xcode asset catalog.
- Original dark-mode icon assets for home, blunders, Woodpecker, progress, puzzles and coach.
- Review data and drill statistics are stored on the device.

## Important limitations

- Training positions are created from games that have been imported and reviewed; the app currently does not bundle Chessigma's proprietary puzzle catalog, nor does it bypass its paywall.
- The training board checks the selected origin/destination against the best UCI move. A fully independent legal-move chess engine for interactive training is not implemented in this UI.
- A successful iOS compilation has **not** yet been verified for the November 2026 changes.
- The project supports iOS 26 or later.

## Build an IPA with GitHub Actions

1. Open the GitHub Actions workflow **Build ChessCoach IPA**.
2. Choose **Run workflow**, branch `chesscoach-ios`, and start the build.
3. A successful run uploads a `ChessCoach-IPA` artifact, containing the unsigned app package.
4. Download the artifact ZIP and unzip `ChessCoach.ipa`. Sign it using your own valid iOS signing certificate and provisioning profile (eSign, Xcode, or another signing method).
5. Installation success depends on the certificate/device registration and iOS installation method.

The workflow uses `macos-26`, downloads and verifies the Stockfish NNUE file, runs XcodeGen, builds for arm64 iPhone and packages the IPA with an ad-hoc signature for re-signing. Unavailable or disabled repository Actions prevent producing a new IPA.

## Licensing

This project links Stockfish (GPL-3.0) through StockfishEmbedded. Distributing an IPA also requires fulfilling the relevant GPL source-code obligations. See `ChessCoach/Resources/ThirdPartyNotices.txt` for the third-party dependencies.

Original vector assets created for this project are independent of Chessigma's protected imagery.
