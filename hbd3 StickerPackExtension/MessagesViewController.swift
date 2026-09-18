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
    private let headerBar = UIView()
    private let unlockButton = UIButton(type: .system)
    private let restoreButton = UIButton(type: .system)
    private var headerHeight: NSLayoutConstraint!

    private var observation: NSKeyValueObservation?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
        setUpHeader()
        setUpGrid()
        store.start()
        observeStore()
    }

    // MARK: - UI

    private func setUpHeader() {
        headerBar.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(headerBar)

        unlockButton.translatesAutoresizingMaskIntoConstraints = false
        unlockButton.titleLabel?.font = .systemFont(ofSize: 16, weight: .semibold)
        unlockButton.titleLabel?.adjustsFontForContentSizeCategory = true
        unlockButton.backgroundColor = .systemBlue
        unlockButton.setTitleColor(.white, for: .normal)
        unlockButton.layer.cornerRadius = 20
        unlockButton.addTarget(self, action: #selector(unlockTapped), for: .touchUpInside)
        headerBar.addSubview(unlockButton)

        restoreButton.translatesAutoresizingMaskIntoConstraints = false
        restoreButton.setTitle("Restore", for: .normal)
        restoreButton.titleLabel?.font = .systemFont(ofSize: 13)
        restoreButton.addTarget(self, action: #selector(restoreTapped), for: .touchUpInside)
        headerBar.addSubview(restoreButton)

        headerHeight = headerBar.heightAnchor.constraint(equalToConstant: 84)

        NSLayoutConstraint.activate([
            headerBar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            headerBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            headerBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            headerHeight,

            unlockButton.topAnchor.constraint(equalTo: headerBar.topAnchor, constant: 8),
            unlockButton.leadingAnchor.constraint(equalTo: headerBar.leadingAnchor, constant: 16),
            unlockButton.trailingAnchor.constraint(equalTo: headerBar.trailingAnchor, constant: -16),
            unlockButton.heightAnchor.constraint(equalToConstant: 40),

            restoreButton.topAnchor.constraint(equalTo: unlockButton.bottomAnchor, constant: 2),
            restoreButton.centerXAnchor.constraint(equalTo: headerBar.centerXAnchor),
        ])
    }

    private func setUpGrid() {
        let layout = UICollectionViewFlowLayout()
        layout.minimumInteritemSpacing = 8
        layout.minimumLineSpacing = 8
        layout.sectionInset = UIEdgeInsets(top: 8, left: 12, bottom: 12, right: 12)

        collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        collectionView.backgroundColor = .clear
        collectionView.alwaysBounceVertical = true
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.register(StickerCell.self,
                                forCellWithReuseIdentifier: StickerCell.reuseID)
        view.addSubview(collectionView)

        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: headerBar.bottomAnchor),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }

    /// Re-render whenever the store's displayed state changes.
    private func observeStore() {
        store.onChange = { [weak self] in
            Task { @MainActor in self?.applyState() }
        }
        applyState()
    }

    private func applyState() {
        if store.isUnlocked {
            headerBar.isHidden = true
            headerHeight.constant = 0
        } else {
            headerBar.isHidden = false
            headerHeight.constant = 84
            let title: String
            if store.isPurchasing {
                title = "Purchasing…"
            } else if let price = store.displayPrice {
                title = "Unlock All \(store.stickerNames.count) Stickers · \(price)"
            } else {
                title = "Unlock All \(store.stickerNames.count) Stickers"
            }
            unlockButton.setTitle(title, for: .normal)
            unlockButton.isEnabled = !store.isPurchasing && store.product != nil
            unlockButton.alpha = unlockButton.isEnabled ? 1 : 0.5
        }
        view.layoutIfNeeded()
        collectionView.reloadData()
    }

    // MARK: - Actions

    @objc private func unlockTapped() {
        // The compact presentation is short; expand so the sheet has room.
        if presentationStyle == .compact { requestPresentationStyle(.expanded) }
        Task { await runPurchase() }
    }

    private func runPurchase() async {
        switch await store.purchase(in: self) {
        case .unlocked:
            applyState()
        case .cancelled:
            break
        case .pending:
            show(alert: "Waiting for Approval",
                 message: "Your purchase needs approval before the stickers unlock.")
        case .failed(let message):
            show(alert: "Purchase Failed", message: message)
        }
    }

    @objc private func restoreTapped() {
        Task {
            let ok = await store.restore()
            show(alert: ok ? "Restored" : "Nothing to Restore",
                 message: ok ? "All stickers are unlocked."
                             : "No previous purchase was found for this Apple Account.")
        }
    }

    private func show(alert title: String, message: String) {
        let ac = UIAlertController(title: title, message: message, preferredStyle: .alert)
        ac.addAction(UIAlertAction(title: "OK", style: .default))
        present(ac, animated: true)
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
        guard let url = store.url(for: name) else { return cell }
        let locked = store.isLocked(index: indexPath.item)
        cell.configure(url: url, name: name, locked: locked)
        if locked {
            cell.onLockedTap = { [weak self] in self?.unlockTapped() }
        }
        return cell
    }

    /// Two per row, matching the large sticker presentation.
    func collectionView(_ collectionView: UICollectionView, layout: UICollectionViewLayout,
                        sizeForItemAt indexPath: IndexPath) -> CGSize {
        let insets: CGFloat = 12 * 2
        let gap: CGFloat = 8
        let width = (collectionView.bounds.width - insets - gap) / 2
        return CGSize(width: floor(width), height: floor(width))
    }
}
