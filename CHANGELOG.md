# Changelog

## 2026-09-29 — Initial build (v1.0)
- New game: **Kiln Keeper**, cozy idle kiln-tending (SwiftUI + SpriteKit, iOS 17+, portrait).
- Core loop: shelves fire glass pieces over real time → tap finished pieces to
  collect → sell for coins → three upgrade tracks (shelf slots, firing speed,
  rarer glass colors in 5 rarity tiers).
- Offline progress: kiln keeps firing while the app is closed, capped at 8
  hours, with a "While you were away…" summary sheet.
- Procedural Molten-style art (no assets): studio backdrop, skin-themed kiln
  arch with flickering fire, translucent glass pieces, embers, collect bursts.
- Juice: collect pop + burst, coin-counter pop, fire flicker, confetti-lite on
  upgrades, haptics + synthesized SFX throughout.
- Monetization from day one: Google Mobile Ads via SPM (rewarded: 2x speed
  10 min / instant-finish one shelf; interstitials ≤1 per 5 min, transitions
  only, never first session), StoreKit 2 (Remove Ads $4.99, two kiln skins
  $1.99 each with live previews + equip, restore purchases, refund revocation).
- PrivacyInfo.xcprivacy: Device ID for third-party advertising, tracking=false.
- Release pipeline: deterministic pbxproj generator, apple-release-check.py /
  apple-release.py scripts, workflow YAML for manual upload
  (`~/workspace/your_files/kilnkeeper-apple-release.yml`).


## September 30, 2026 - Independent source verification

Declared the app-scoped UserDefaults required-reason API (CA92.1), based on the app's actual preferences and local save calls. This does not certify App Store privacy answers or third-party SDK behavior. Final signed archive privacy reports and actual-device/network behavior remain release gates.
Fixed unquoted spaced display names in both the Xcode project and its generator.

Versioned the previously missing release workflow with pinned actions, app-specific identity/environment, manual main-branch signing and upload disabled by default. Removed the incorrect requirement that workflows must stay outside GitHub. Signing environments/secrets, account budget and actual Mac builds remain unverified; nothing dispatched.
