import UIKit
import Messages
import StoreKit

/// Custom sticker browser with a free tier and a one-time unlock.
///
/// A plain sticker-pack extension can't gate content or draw a badge, so this
/// builds the grid from `MSStickerView` cells instead of the system browser.
final class MessagesViewController: MSMessagesAppViewController {

    private let store = StickerStore()
    private var collectionView: UICollectionView!
    private let banner = UnlockBanner()
    private var bannerHeight: NSLayoutConstraint!
    private weak var paywall: PaywallViewController?
    private var pendingPaywall = false

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
        setUpBanner()
        setUpGrid()
        store.onChange = { [weak self] in
            Task { @MainActor in self?.applyState() }
        }
        store.start()
        applyState()
    }

    // MARK: - UI

    private func setUpBanner() {
        banner.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(banner)
        banner.unlockButton.addTarget(self, action: #selector(unlockTapped),
                                      for: .touchUpInside)
        bannerHeight = banner.heightAnchor.constraint(
            equalToConstant: UnlockBanner.rowHeight)
        NSLayoutConstraint.activate([
            // Pinned to the true top, not the safe area, so nothing scrolls
            // through the strip above the bar.
            banner.topAnchor.constraint(equalTo: view.topAnchor),
            banner.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            banner.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            bannerHeight,
        ])
    }

    private func setUpGrid() {
        let layout = UICollectionViewFlowLayout()
        layout.minimumInteritemSpacing = 8
        layout.minimumLineSpacing = 8
        layout.sectionInset = UIEdgeInsets(top: 8, left: 12, bottom: 16, right: 12)

        collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        collectionView.backgroundColor = .clear
        collectionView.alwaysBounceVertical = true
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.register(StickerCell.self,
                                forCellWithReuseIdentifier: StickerCell.reuseID)
        view.insertSubview(collectionView, belowSubview: banner)

        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: view.topAnchor),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }

    override func viewSafeAreaInsetsDidChange() {
        super.viewSafeAreaInsetsDidChange()
        applyState()
    }

    /// Rotation and the compact/expanded transition both change the width, so
    /// the column count has to be recalculated.
    override func viewWillTransition(to size: CGSize,
                                     with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        coordinator.animate(alongsideTransition: { [weak self] _ in
            self?.collectionView?.collectionViewLayout.invalidateLayout()
        })
    }

    override func didTransition(to presentationStyle: MSMessagesAppPresentationStyle) {
        super.didTransition(to: presentationStyle)
        collectionView?.collectionViewLayout.invalidateLayout()
        applyState()
        if pendingPaywall, presentationStyle == .expanded {
            pendingPaywall = false
            showPaywall()
        }
    }

    private func applyState() {
        // Layout callbacks can arrive before viewDidLoad finishes wiring these.
        guard collectionView != nil, bannerHeight != nil else { return }
        let unlocked = store.isUnlocked
        banner.isHidden = unlocked
        let barHeight = view.safeAreaInsets.top + UnlockBanner.rowHeight
        bannerHeight.constant = unlocked ? 0 : barHeight
        if !unlocked {
            banner.update(price: store.displayPrice,
                          purchasing: store.isPurchasing,
                          enabled: store.product != nil)
        }
        // The grid scrolls underneath the translucent bar, so inset it rather
        // than pinning below — that's what makes the blur read as a blend.
        let top = unlocked ? view.safeAreaInsets.top + 8 : barHeight
        collectionView.contentInset.top = top
        collectionView.verticalScrollIndicatorInsets.top = top
        view.layoutIfNeeded()
        collectionView.reloadData()

        // Keep an open paywall in sync, and close it once unlocked.
        if unlocked, let paywall {
            paywall.dismiss(animated: true)
            self.paywall = nil
        }
    }

    // MARK: - Purchase flow

    /// Tapping a locked sticker opens the paywall.
    ///
    /// `requestPresentationStyle` is asynchronous, so presenting straight
    /// after it renders the sheet into the compact strip. Defer until
    /// `didTransition(to:)` reports the expanded style.
    private func presentPaywall() {
        guard paywall == nil, !store.isUnlocked else { return }
        if presentationStyle == .compact {
            pendingPaywall = true
            requestPresentationStyle(.expanded)
            return
        }
        showPaywall()
    }

    private func showPaywall() {
        guard paywall == nil, !store.isUnlocked else { return }
        let vc = PaywallViewController(total: store.stickerNames.count,
                                       locked: store.lockedCount,
                                       price: store.displayPrice,
                                       purchasing: store.isPurchasing,
                                       canBuy: store.product != nil,
                                       heroImage: store.appIconHero())
        vc.onBuy = { [weak self] in Task { await self?.runPurchase() } }
        vc.onRestore = { [weak self] in Task { await self?.runRestore() } }
        vc.modalPresentationStyle = .overFullScreen
        vc.modalTransitionStyle = .coverVertical
        paywall = vc
        present(vc, animated: true)
    }

    @objc private func unlockTapped() {
        presentPaywall()
    }

    private func runPurchase() async {
        switch await store.purchase(in: paywall ?? self) {
        case .unlocked:
            applyState()
        case .cancelled:
            break
        case .pending:
            notify("Waiting for Approval",
                   "Your purchase needs approval before the stickers unlock.")
        case .failed(let message):
            notify("Purchase Failed", message)
        }
    }

    private func runRestore() async {
        let ok = await store.restore()
        if ok {
            applyState()
        } else {
            notify("Nothing to Restore",
                   "No previous purchase was found for this Apple Account.")
        }
    }

    /// Alerts must come from whatever is frontmost, or they never appear.
    private func notify(_ title: String, _ message: String) {
        let ac = UIAlertController(title: title, message: message,
                                   preferredStyle: .alert)
        ac.addAction(UIAlertAction(title: "OK", style: .default))
        (presentedViewController ?? self).present(ac, animated: true)
    }
}

// MARK: - Collection view

extension MessagesViewController: UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {

    func collectionView(_ collectionView: UICollectionView,
                        numberOfItemsInSection section: Int) -> Int {
        store.stickerNames.count
    }

    func collectionView(_ collectionView: UICollectionView,
                        cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: StickerCell.reuseID, for: indexPath) as! StickerCell
        let name = store.stickerNames[indexPath.item]
        let locked = store.isLocked(index: indexPath.item)
        cell.configure(sticker: store.sticker(named: name), name: name, locked: locked)
        if locked {
            cell.onLockedTap = { [weak self] in self?.presentPaywall() }
        }
        return cell
    }

    /// Two per row on a phone, matching the large sticker presentation; wider
    /// screens (iPad, landscape) add columns rather than inflating the cells.
    func collectionView(_ collectionView: UICollectionView, layout: UICollectionViewLayout,
                        sizeForItemAt indexPath: IndexPath) -> CGSize {
        let insets: CGFloat = 12 * 2
        let gap: CGFloat = 8
        let available = collectionView.bounds.width - insets
        guard available > 0 else { return CGSize(width: 1, height: 1) }

        let targetCell: CGFloat = 190
        let columns = max(2, min(6, Int((available + gap) / (targetCell + gap))))
        let width = (available - gap * CGFloat(columns - 1)) / CGFloat(columns)
        return CGSize(width: floor(width), height: floor(width))
    }
}
