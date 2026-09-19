import Foundation
import StoreKit
import UIKit

/// Catalog of the bundled stickers plus the unlock entitlement.
///
/// The first `freeCount` stickers are always usable. The rest stay locked
/// until the non-consumable `unlockAll` product is purchased.
/// Not using `@Observable`: that requires iOS 17, and the deployment target is
/// 15.0 (the minimum StoreKit 2 needs). A change callback keeps the same effect.
@MainActor
final class StickerStore {

    /// Must match the Product ID configured in App Store Connect exactly.
    static let unlockProductID = "com.ari.hbd3.unlockall"

    /// Number of stickers playable without purchasing.
    static let freeCount = 4

    #if DEBUG
    /// Debug builds only: unlock everything without a purchase.
    /// Set to `false` to test the locked grid and paywall on device.
    /// This has no effect on Release — the check is compiled out entirely.
    static let debugUnlockEverything = true
    #endif

    private(set) var stickerNames: [String] = []
    private(set) var product: Product? { didSet { onChange?() } }
    private(set) var isUnlocked = false { didSet { onChange?() } }
    private(set) var isPurchasing = false { didSet { onChange?() } }
    private(set) var loadFailed = false

    /// Fired whenever displayed state changes, so the UI can re-render.
    var onChange: (() -> Void)?

    private var updatesTask: Task<Void, Never>?

    init() {
        stickerNames = Self.discoverStickers()
    }

    deinit {
        updatesTask?.cancel()
    }

    /// Stickers are copied as a folder reference, so they live in a
    /// subdirectory rather than at the bundle root.
    static let assetsFolder = "StickerAssets"

    /// Sticker files ship as `s1.png` … `s103.png`. Sort numerically so the
    /// free ones are the first six by number, not by string order.
    private static func discoverStickers() -> [String] {
        let urls = Bundle.main.urls(forResourcesWithExtension: "png",
                                    subdirectory: assetsFolder) ?? []
        let names = urls.map { $0.deletingPathExtension().lastPathComponent }
            .filter { $0.hasPrefix("s") && Int($0.dropFirst()) != nil }
        return names.sorted {
            (Int($0.dropFirst()) ?? 0) < (Int($1.dropFirst()) ?? 0)
        }
    }

    func isLocked(index: Int) -> Bool {
        !isUnlocked && index >= Self.freeCount
    }

    /// Icon artwork used as the paywall hero.
    func appIconHero() -> UIImage? {
        guard let url = Bundle.main.url(forResource: "AppIconHero",
                                        withExtension: "png",
                                        subdirectory: Self.assetsFolder)
        else { return nil }
        return UIImage(contentsOfFile: url.path)
    }

    func url(for name: String) -> URL? {
        Bundle.main.url(forResource: name, withExtension: "png",
                        subdirectory: Self.assetsFolder)
    }

    var lockedCount: Int {
        max(0, stickerNames.count - Self.freeCount)
    }

    /// Price to show on the unlock button, or nil while loading.
    var displayPrice: String? { product?.displayPrice }

    func start() {
        updatesTask = Task { [weak self] in
            for await update in Transaction.updates {
                guard let self else { return }
                if case .verified(let transaction) = update {
                    await self.apply(transaction)
                }
            }
        }
        Task { await refresh() }
    }

    func refresh() async {
        await loadProduct()
        await refreshEntitlement()
    }

    private func loadProduct() async {
        do {
            let products = try await Product.products(for: [Self.unlockProductID])
            product = products.first
            loadFailed = products.isEmpty
        } catch {
            loadFailed = true
        }
    }

    /// Source of truth for access. Runs on launch so purchases made on other
    /// devices or reinstalls unlock without the customer tapping Restore.
    func refreshEntitlement() async {
        #if DEBUG
        // Debug convenience: treat the pack as bought so the full catalogue
        // is usable for review and screenshots without a real transaction.
        // Flip `debugUnlockEverything` to false to exercise the locked and
        // paywall flow. Compiled out of Release, so the shipping build
        // always enforces the purchase.
        if Self.debugUnlockEverything {
            isUnlocked = true
            return
        }
        #endif

        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result,
               transaction.productID == Self.unlockProductID,
               transaction.revocationDate == nil {
                isUnlocked = true
                return
            }
        }
        isUnlocked = false
    }

    private func apply(_ transaction: Transaction) async {
        if transaction.productID == Self.unlockProductID {
            isUnlocked = transaction.revocationDate == nil
        }
        await transaction.finish()
    }

    enum PurchaseOutcome {
        case unlocked
        case cancelled
        case pending
        case failed(String)
    }

    func purchase(in viewController: UIViewController) async -> PurchaseOutcome {
        guard let product else {
            return .failed("The unlock isn’t available right now. Please try again.")
        }
        guard !isPurchasing else { return .cancelled }
        isPurchasing = true
        defer { isPurchasing = false }

        do {
            // purchase(confirmIn:) anchors the sheet to our view controller but
            // is iOS 18.2+; fall back to the plain call on earlier systems.
            let result: Product.PurchaseResult
            if #available(iOS 18.2, *) {
                result = try await product.purchase(confirmIn: viewController)
            } else {
                result = try await product.purchase()
            }
            switch result {
            case .success(let verification):
                switch verification {
                case .verified(let transaction):
                    await apply(transaction)
                    return .unlocked
                case .unverified:
                    return .failed("That purchase couldn’t be verified.")
                }
            case .userCancelled:
                return .cancelled
            case .pending:
                return .pending
            @unknown default:
                return .cancelled
            }
        } catch {
            return .failed(error.localizedDescription)
        }
    }

    func restore() async -> Bool {
        try? await AppStore.sync()
        await refreshEntitlement()
        return isUnlocked
    }
}
