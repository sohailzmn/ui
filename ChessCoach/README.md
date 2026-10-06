# Chess Coach iOS

An animated iPhone/iPad chess learning app that connects to the official Chess.com public API, imports a player's public games, and produces local Stockfish-powered reviews without a paid analysis API.

## Features

- Connect with a Chess.com username only; no password is requested.
- Imports recent public standard games from Chess.com's PubAPI.
- Local Stockfish review with move-by-move evaluation and best moves.
- Review labels: Best, Great, Inaccuracy, Mistake, Blunder.
- Automatically turns mistakes into practice positions.
- Animated SwiftUI dashboard, game timeline, board transitions and review progress.
- Review data is cached locally on device.
- No ads and no paid AI/API requirement.

## Build

The GitHub Actions workflow creates an unsigned device IPA. It downloads the exact verified Stockfish NNUE expected by StockfishEmbedded, generates the app icon, generates the Xcode project with XcodeGen, and packages ChessCoach.app into ChessCoach.ipa.

The unsigned IPA is intended for signing with the user's own certificate/signing workflow (for example eSign).

## Licensing

Because StockfishEmbedded statically links GPL-3.0 Stockfish code, this app's distributed source is intended to be GPL-3.0-or-later compatible. See the bundled ThirdPartyNotices.txt and the upstream projects for complete license texts and corresponding source.
