import UIKit

/// Another app by the same developer, promoted after the sticker grid.
struct PromoPack {
    /// App Store numeric app ID, used as the iTunes item identifier when
    /// loading the product page.
    let appStoreID: String
    let name: String
    let tagline: String
    /// Localized App Store price, shown as a badge.
    let price: String
    /// PNG in StickerAssets. Falls back to an accent gradient with
    /// `symbolName` if the file is missing.
    let artworkName: String
    let symbolName: String
    /// Accent pair used for the artwork fallback and the price badge.
    let accentStart: UIColor
    let accentEnd: UIColor
}

/// The other apps advertised at the end of the browser. Names and prices come
/// from the live App Store listings.
enum PromoCatalog {

    static let packs: [PromoPack] = [
        PromoPack(
            appStoreID: "6444010768",
            name: "350 Hilarious Emojis & Memes",
            tagline: "Hundreds of funny emoji and meme stickers for any chat.",
            price: "Free",
            artworkName: "PromoEmojis",
            symbolName: "face.smiling.inverse",
            accentStart: UIColor(red: 0.98, green: 0.72, blue: 0.09, alpha: 1),
            accentEnd: UIColor(red: 0.95, green: 0.35, blue: 0.22, alpha: 1)
        ),
        PromoPack(
            appStoreID: "6761229621",
            name: "Mes: AI Reply & Translate",
            tagline: "AI replies, instant translation, polls and more.",
            price: "Free",
            artworkName: "PromoMes",
            symbolName: "sparkles.rectangle.stack",
            accentStart: UIColor(red: 0.20, green: 0.45, blue: 0.98, alpha: 1),
            accentEnd: UIColor(red: 0.45, green: 0.28, blue: 0.96, alpha: 1)
        ),
        PromoPack(
            appStoreID: "6443983112",
            name: "100+ Christmas Stickers",
            tagline: "Over 100 festive stickers for spreading holiday cheer.",
            price: "Free",
            artworkName: "PromoChristmas",
            symbolName: "snowflake",
            accentStart: UIColor(red: 0.85, green: 0.16, blue: 0.20, alpha: 1),
            accentEnd: UIColor(red: 0.10, green: 0.55, blue: 0.32, alpha: 1)
        ),
        PromoPack(
            appStoreID: "6443983171",
            name: "100+ Thanksgiving Stickers",
            tagline: "Unique feline sticker expressions for the whole holiday.",
            price: "Free",
            artworkName: "PromoThanksgiving",
            symbolName: "leaf.fill",
            accentStart: UIColor(red: 0.86, green: 0.51, blue: 0.10, alpha: 1),
            accentEnd: UIColor(red: 0.55, green: 0.24, blue: 0.10, alpha: 1)
        )
    ]
}
