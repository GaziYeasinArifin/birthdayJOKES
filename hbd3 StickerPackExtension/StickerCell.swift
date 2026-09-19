import UIKit
import Messages

/// Grid cell for one sticker.
///
/// Both locked and unlocked cells use `MSStickerView` so everything animates.
/// Locked cells add a transparent touch-catcher above the sticker view: it wins
/// hit-testing, so `MSStickerView` never receives the tap or the long-press
/// that starts a drag. The gate stays structural — a locked sticker cannot be
/// inserted or dragged — while still playing its animation.
final class StickerCell: UICollectionViewCell {

    static let reuseID = "StickerCell"

    private let stickerView = MSStickerView()
    private let touchCatcher = UIControl()
    private let lockBadge = UIImageView()
    private let lockBackdrop = UIVisualEffectView(
        effect: UIBlurEffect(style: .systemUltraThinMaterialDark))

    /// Called when a locked cell is tapped, to surface the paywall.
    var onLockedTap: (() -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)

        stickerView.translatesAutoresizingMaskIntoConstraints = false
        touchCatcher.translatesAutoresizingMaskIntoConstraints = false
        lockBackdrop.translatesAutoresizingMaskIntoConstraints = false
        lockBadge.translatesAutoresizingMaskIntoConstraints = false

        contentView.addSubview(stickerView)
        contentView.addSubview(touchCatcher)
        contentView.addSubview(lockBackdrop)
        lockBackdrop.contentView.addSubview(lockBadge)

        let cfg = UIImage.SymbolConfiguration(pointSize: 11, weight: .bold)
        lockBadge.image = UIImage(systemName: "lock.fill", withConfiguration: cfg)
        lockBadge.tintColor = .white

        lockBackdrop.layer.cornerRadius = 12
        lockBackdrop.clipsToBounds = true
        lockBackdrop.isUserInteractionEnabled = false
        lockBackdrop.layer.borderWidth = 0.5
        lockBackdrop.layer.borderColor = UIColor.white.withAlphaComponent(0.35).cgColor

        touchCatcher.addTarget(self, action: #selector(lockedTapped), for: .touchUpInside)

        NSLayoutConstraint.activate([
            stickerView.topAnchor.constraint(equalTo: contentView.topAnchor),
            stickerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            stickerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            stickerView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),

            touchCatcher.topAnchor.constraint(equalTo: contentView.topAnchor),
            touchCatcher.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            touchCatcher.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            touchCatcher.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),

            lockBackdrop.widthAnchor.constraint(equalToConstant: 24),
            lockBackdrop.heightAnchor.constraint(equalToConstant: 24),
            lockBackdrop.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -2),
            lockBackdrop.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -2),

            lockBadge.centerXAnchor.constraint(equalTo: lockBackdrop.contentView.centerXAnchor),
            lockBadge.centerYAnchor.constraint(equalTo: lockBackdrop.contentView.centerYAnchor),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    @objc private func lockedTapped() {
        // Brief press feedback so the tap clearly registers.
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        UIView.animate(withDuration: 0.09, animations: {
            self.contentView.transform = CGAffineTransform(scaleX: 0.94, y: 0.94)
        }, completion: { _ in
            UIView.animate(withDuration: 0.12) { self.contentView.transform = .identity }
        })
        onLockedTap?()
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        stickerView.stopAnimating()
        stickerView.sticker = nil
        contentView.transform = .identity
        onLockedTap = nil
    }

    func configure(sticker: MSSticker?, name: String, locked: Bool) {
        stickerView.sticker = sticker
        stickerView.startAnimating()

        touchCatcher.isHidden = !locked
        touchCatcher.isUserInteractionEnabled = locked
        lockBackdrop.isHidden = !locked

        isAccessibilityElement = locked
        accessibilityLabel = locked ? "\(name), locked. Tap to unlock all stickers." : nil
        accessibilityTraits = locked ? .button : .none
    }
}
