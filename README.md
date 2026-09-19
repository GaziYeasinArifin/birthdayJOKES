# Animated Birthday Wishes Jokes

An iMessage sticker app: 103 animated birthday joke stickers, four free and
the rest behind a one-time unlock.

- **App Store:** [id6450862803](https://apps.apple.com/app/id6450862803)
- **Bundle ID:** `com.ari.hbd3`
- **Deployment target:** iOS 15.0 · iPhone + iPad

> This app has **no Home Screen icon**. It is a Messages-only app
> (`LSApplicationLaunchProhibited`), reachable from Messages → a conversation
> → the ⊕ button → **Birthday Jokes**. This trips up almost everyone who
> tests it for the first time, App Review included.

## Layout

```
Birthday.xcodeproj
Birthday.storekit                        local StoreKit config for testing the paywall
hbd3/
  Info.plist                             host app
  Assets.xcassets/AppIcon.appiconset     1024pt icon; CFBundleIconName points here
hbd3 StickerPackExtension/
  Info.plist                             NSExtensionPrincipalClass = MessagesViewController
  MessagesViewController.swift           grid, paywall flow, cross-promo
  StickerStore.swift                     catalog, StoreKit entitlement, grandfathering
  StickerCell.swift                      one sticker; lock gate lives here
  UnlockUI.swift                         unlock bar + paywall
  PromoCatalog.swift / PromoViews.swift  "more from us" section
  StickerAssets/                         103 stickers, promo icons, paywall hero
  Stickers.xcstickers/                   iMessage app icon only
```

## Two targets

`Birthday` is a Messages-only host app with no code. `Birthday
StickerPackExtension` is the real app: product type
`com.apple.product-type.app-extension.messages`, built around
`MSMessagesAppViewController`.

It began as an asset-only sticker pack. That product type has **no code at
all**, so it cannot gate content, draw a lock badge, or run StoreKit — it was
converted to a code extension when the paywall was added.

## Paywall

Four stickers are free; the other 99 need the non-consumable
`com.ari.hbd3.unlockall`. That string must match App Store Connect exactly —
it is `StickerStore.unlockProductID`.

Unlocked cells are `MSStickerView`. Locked cells are the **same view with a
transparent `UIControl` above them**: it wins hit-testing, so `MSStickerView`
never receives the tap or the long-press that begins a drag. The gate is
structural — a locked sticker cannot be inserted or dragged — while still
animating. Tapping one opens the paywall.

Entitlement comes from `Transaction.currentEntitlements` at launch, so
reinstalls and other devices unlock without anyone tapping Restore.
`Transaction.updates` covers purchases made elsewhere.

### Grandfathering — read before changing the build number

1.0 was a **paid** app: buying it gave you every sticker. Going free + IAP
would have asked those customers to pay again for content they already owned.

`StickerStore.isLegacyPaidCustomer()` reads
`AppTransaction.originalAppVersion` — the `CFBundleVersion` the customer
first downloaded — and unlocks everything when it is below
`firstFreeBuild`.

> **`firstFreeBuild` must equal the build number that actually ships.**
> It is `5`, and `CURRENT_PROJECT_VERSION` is `5`. If the shipped build
> changes, change the constant with it, or real customers get charged twice.

`AppTransaction` is iOS 16+, so iOS 15 customers cannot be grandfathered.

### Product loading is deliberately stubborn

`loadProduct()` retries three times with 0.5s/1s/2s backoff, the paywall
retries on open, and the Get button is **never disabled for a missing
product** — it shows "Loading…" and still opens the paywall.

This is not defensive padding. A single un-retried lookup failure previously
left the button dimmed and untappable for the whole session, and App Review
rejected the build under Guideline 2.1(b): *"we cannot locate the In-App
Purchases."* The purchase existed; there was simply no working way to reach
it.

## Sticker assets

103 APNGs, generated from static art rather than hand-animated.

| | |
|---|---|
| Size | 618×618 (`grid-size: large`, 2 per row) |
| Budget | **500 KB per file, enforced by Messages** |
| Frames | ~14, roughly 1.6s |
| Effects | sparkle, chase, confetti, bubbles, pop, shine, bounce, float, sway, pulse, shake, flash |

The animations keep the base artwork **static** and confine motion to one
compact zone. APNG stores a single changed rectangle per frame, so a
full-canvas effect costs ~80% of the canvas per frame and blows the 500 KB
cap; a localised one costs ~11%. `flash` is the one whole-canvas effect and
is capped at 8 frames and quantised to 128 colours to fit.

Assets load from `StickerAssets/` by path, not from an asset catalog.
`MSSticker` instances are cached — `MSSticker(contentsOfFileURL:)` touches
the filesystem, and building one per cell dequeue meant disk I/O throughout
every scroll.

## Building

```sh
xcodebuild -project Birthday.xcodeproj \
  -scheme "Birthday StickerPackExtension" \
  -destination 'generic/platform=iOS' -configuration Release build
```

Xcode sometimes builds from its own in-memory copy of the project and
ignores on-disk edits — if a change seems not to apply, close and reopen the
project. Swapping sticker files also leaves orphaned PNGs in the built
`.appex`; `xcodebuild clean` does not remove them, so delete DerivedData.

### Testing the paywall

Set **Edit Scheme → Run → Options → StoreKit Configuration** to
`Birthday.storekit` to exercise purchases without App Store Connect.

For screenshots or review, `StickerStore.debugUnlockEverything = true`
unlocks the whole pack. It is inside `#if DEBUG` and
`SWIFT_ACTIVE_COMPILATION_CONDITIONS` is set only on the Debug
configuration, so it is compiled out of Release.

### iOS caches sticker renders

Replacing artwork without changing its filename will keep showing the old
image, however many times you reinstall. Uninstall the app first.

## Submission notes

- `CFBundleIconName` must resolve to a **real `.appiconset`**. Pointing it at
  the `.stickersiconset` looks correct in the Info.plist but fails upload —
  the validator resolves it against the compiled catalog and finds nothing.
- App and extension `CFBundleVersion` must match.
- The two `LSApplicationLaunchProhibited` warnings about visionOS and Apple
  silicon are expected: that key is required for a Messages-only app and
  simply makes it unavailable on those platforms.
- Attach the IAP to the version, or review rejects it.
- The binary reports **Includes Stickers: No** — there is no `.stickerpack`
  any more. A consequence is that stickers no longer appear system-wide in
  the emoji keyboard; they live in the Messages app drawer only. That is the
  cost of being able to gate them.
