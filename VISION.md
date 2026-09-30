# VISION.md — Kiln Keeper

## Vision
A cozy idle game about tending a warm glass kiln. No timers pressuring you, no
fail states, no accounts — just the quiet satisfaction of glass finishing,
collecting it, and slowly growing your studio. The kiln works while you're
gone, so every return feels like a small gift.

## Philosophy
- **The free tier must be genuinely usable.** The whole game — all shelves,
  all speeds, all glass rarities — is earnable with play. Money buys
  convenience (no ads) and cosmetics (kiln skins), never power or content.
- **Help-people-first monetization:** rewarded ads are strictly opt-in and
  always clearly labeled; interstitials are sparse and never interrupt play.
- **Offline-first:** the game works with no network (ads degrade gracefully,
  offline progress computes locally, owned entitlements persist locally).
- **Zero data collection:** no sign-in, no analytics/tracking beyond AdMob,
  StoreKit 2 only, no external billing links, no http:// URLs.

## Pricing

| Product | Type | Price | Product ID |
|---|---|---|---|
| Remove Ads | Non-consumable | $4.99 | `app.kilnkeeper.game.removeads` |
| Emberforge Kiln skin | Non-consumable | $1.99 | `app.kilnkeeper.game.skin.emberforge` |
| Tideglass Kiln skin | Non-consumable | $1.99 | `app.kilnkeeper.game.skin.tideglass` |

Rewarded ads (opt-in): 2x firing speed for 10 minutes; instant-finish one
shelf. Interstitials: at most one per ~5 minutes of play, only on screen
transitions, never in the first session, never for Remove-Ads owners.

## Current state (2026-09-29)
- v1.0 initial build complete and pushed to
  `https://github.com/OverlordLoader/kiln-keeper` (branch `main`).
- Core loop, offline progress (8h cap), 3 upgrade tracks, 5 rarity tiers,
  3 kiln skins (Classic free + 2 paid), Settings with restore purchases.
- AdMob: Google test IDs in DEBUG; release IDs are `TODO(Henry)` placeholders.
- App Store Connect IAP products, AdMob account/units, provisioning profile,
  and `app-store-release-kilnkeeper` secrets are still Henry/Hermes tasks.
- Release workflow YAML kept out of the repo (owner-only permission) at
  `~/workspace/your_files/kilnkeeper-apple-release.yml`.
- Not yet compiled: no Swift toolchain on Linux — first build happens on the
  macOS pipeline / Henry's side. All Swift was hand-reviewed for API
  correctness (GMA 11.x, StoreKit 2, Swift 5 language mode).

## Conventions (for any AI tool working in this repo)
- **Review branches only. Never merge to the default branch without Henry.**
- **No secrets in code.** AdMob release IDs are Henry's to paste; signing
  secrets live in the `app-store-release-kilnkeeper` environment, never here.
- **One purchase flow per platform:** StoreKit 2 only. No external billing,
  no web links, no `UIApplication.shared.open`.
- **Regenerate, don't hand-edit:** `KilnKeeper.xcodeproj/project.pbxproj`
  comes from `tools/gen_pbxproj.py`. App icons come from
  `scripts/generate_icons.py`.
- **Balance lives in one place:** `Balance` in `Game/Models.swift`.
- **Update this file's changelog with every change.**

## Changelog
- 2026-09-29: v1.0 initial build — full game, monetization, release pipeline.
