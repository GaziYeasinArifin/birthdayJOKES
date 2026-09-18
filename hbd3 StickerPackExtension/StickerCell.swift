import UIKit
import Messages

/// Grid cell for one sticker.
///
/// Unlocked cells host an `MSStickerView`, which is what grants tap-to-insert
/// and drag-to-transcript. Locked cells deliberately use a plain image view so
/// there is no path to send them — the gate is structural, not cosmetic. They
/// also show a static first frame, so only the free stickers animate until the
/// pack is unlocked.
final class StickerCell: UICollectionViewCell {

    static let reuseID = "StickerCell"

    private let stickerView = MSStickerView()
    private let lockedImageView = UIImageView()
    private let lockBadge = UIImageView()
    private let lockBackdrop = UIView()

    /// Called when a locked cell is tapped, to surface the paywall.
    var onLockedTap: (() -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        contentView.addSubview(stickerView)
        contentView.addSubview(lockedImageView)
        contentView.addSubview(lockBackdrop)
        lockBackdrop.addSubview(lockBadge)

        stickerView.translatesAutoresizingMaskIntoConstraints = false
        lockedImageView.translatesAutoresizingMaskIntoConstraints = false
        lockBackdrop.translatesAutoresizingMaskIntoConstraints = false
        lockBadge.translatesAutoresizingMaskIntoConstraints = false

        lockedImageView.contentMode = .scaleAspectFit
        lockedImageView.isUserInteractionEnabled = true

        let config = UIImage.SymbolConfiguration(pointSize: 11, weight: .bold)
        lockBadge.image = UIImage(systemName: "lock.fill", withConfiguration: config)
        lockBadge.tintColor = .white
        lockBadge.contentMode = .center

        lockBackdrop.backgroundColor = UIColor.black.withAlphaComponent(0.45)
        lockBackdrop.layer.cornerRadius = 11
        lockBackdrop.isUserInteractionEnabled = false

        NSLayoutConstraint.activate([
            stickerView.topAnchor.constraint(equalTo: contentView.topAnchor),
            stickerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            stickerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            stickerView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),

            lockedImageView.topAnchor.constraint(equalTo: contentView.topAnchor),
            lockedImageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            lockedImageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            lockedImageView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),

            lockBackdrop.widthAnchor.constraint(equalToConstant: 22),
            lockBackdrop.heightAnchor.constraint(equalToConstant: 22),
            lockBackdrop.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -4),
            lockBackdrop.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -4),

            lockBadge.centerXAnchor.constraint(equalTo: lockBackdrop.centerXAnchor),
            lockBadge.centerYAnchor.constraint(equalTo: lockBackdrop.centerYAnchor),
        ])

        let tap = UITapGestureRecognizer(target: self, action: #selector(handleLockedTap))
        lockedImageView.addGestureRecognizer(tap)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    @objc private func handleLockedTap() {
        onLockedTap?()
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        stickerView.stopAnimating()
        stickerView.sticker = nil
        lockedImageView.image = nil
        onLockedTap = nil
    }

    func configure(url: URL, name: String, locked: Bool) {
        if locked {
            stickerView.isHidden = true
            lockBackdrop.isHidden = false
            lockedImageView.isHidden = false
            // UIImage renders only the first frame of an APNG, which is both
            // the "still" look we want for locked items and much cheaper.
            lockedImageView.image = UIImage(contentsOfFile: url.path)
        } else {
            lockedImageView.isHidden = true
            lockBackdrop.isHidden = true
            stickerView.isHidden = false
            stickerView.sticker = try? MSSticker(contentsOfFileURL: url,
                                                 localizedDescription: name)
            stickerView.startAnimating()
        }
    }
}
