import UIKit

/// Brand palette lifted from the app icon.
enum Brand {
    static let pink = UIColor(red: 0.91, green: 0.09, blue: 0.44, alpha: 1)
    static let yellow = UIColor(red: 1.00, green: 0.83, blue: 0.09, alpha: 1)
    static let blue = UIColor(red: 0.24, green: 0.53, blue: 0.96, alpha: 1)
    static let purple = UIColor(red: 0.58, green: 0.35, blue: 0.94, alpha: 1)
}

/// Rounded gradient button that reads as the primary call to action.
final class GradientButton: UIButton {

    private let gradient = CAGradientLayer()

    init(colors: [UIColor]) {
        super.init(frame: .zero)
        gradient.colors = colors.map(\.cgColor)
        gradient.startPoint = CGPoint(x: 0, y: 0.5)
        gradient.endPoint = CGPoint(x: 1, y: 0.5)
        layer.insertSublayer(gradient, at: 0)

        titleLabel?.font = .systemFont(ofSize: 17, weight: .bold)
        titleLabel?.adjustsFontSizeToFitWidth = true
        titleLabel?.minimumScaleFactor = 0.8
        setTitleColor(.white, for: .normal)

        layer.cornerRadius = 24
        layer.cornerCurve = .continuous
        clipsToBounds = true

        // Lift it off the background a little.
        layer.shadowColor = Brand.pink.cgColor
        layer.shadowOpacity = 0.35
        layer.shadowRadius = 10
        layer.shadowOffset = CGSize(width: 0, height: 4)
        clipsToBounds = false
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layoutSubviews() {
        super.layoutSubviews()
        gradient.frame = bounds
        gradient.cornerRadius = layer.cornerRadius
    }

    override var isHighlighted: Bool {
        didSet {
            UIView.animate(withDuration: 0.12) {
                self.transform = self.isHighlighted
                    ? CGAffineTransform(scaleX: 0.97, y: 0.97) : .identity
                self.alpha = self.isHighlighted ? 0.92 : 1
            }
        }
    }
}

/// Compact banner pinned above the grid.
final class UnlockBanner: UIView {

    let unlockButton = GradientButton(colors: [Brand.pink, Brand.purple])
    let restoreButton = UIButton(type: .system)
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let card = UIView()

    init() {
        super.init(frame: .zero)

        card.translatesAutoresizingMaskIntoConstraints = false
        card.backgroundColor = UIColor.systemBackground.withAlphaComponent(0.6)
        card.layer.cornerRadius = 20
        card.layer.cornerCurve = .continuous
        card.layer.borderWidth = 1
        card.layer.borderColor = UIColor.separator.withAlphaComponent(0.4).cgColor
        addSubview(card)

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = .systemFont(ofSize: 15, weight: .bold)
        titleLabel.textColor = .label
        titleLabel.adjustsFontForContentSizeCategory = true

        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        subtitleLabel.font = .systemFont(ofSize: 12, weight: .medium)
        subtitleLabel.textColor = .secondaryLabel
        subtitleLabel.adjustsFontForContentSizeCategory = true

        unlockButton.translatesAutoresizingMaskIntoConstraints = false

        restoreButton.translatesAutoresizingMaskIntoConstraints = false
        restoreButton.setTitle("Restore", for: .normal)
        restoreButton.titleLabel?.font = .systemFont(ofSize: 12, weight: .semibold)
        restoreButton.setTitleColor(.secondaryLabel, for: .normal)

        let text = UIStackView(arrangedSubviews: [titleLabel, subtitleLabel])
        text.axis = .vertical
        text.spacing = 1
        text.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(text)
        card.addSubview(restoreButton)
        card.addSubview(unlockButton)

        NSLayoutConstraint.activate([
            card.topAnchor.constraint(equalTo: topAnchor, constant: 6),
            card.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            card.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            card.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -6),

            text.topAnchor.constraint(equalTo: card.topAnchor, constant: 10),
            text.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 14),

            restoreButton.centerYAnchor.constraint(equalTo: text.centerYAnchor),
            restoreButton.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -14),
            restoreButton.leadingAnchor.constraint(greaterThanOrEqualTo: text.trailingAnchor, constant: 8),

            unlockButton.topAnchor.constraint(equalTo: text.bottomAnchor, constant: 8),
            unlockButton.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 14),
            unlockButton.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -14),
            unlockButton.heightAnchor.constraint(equalToConstant: 48),
            unlockButton.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -12),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func update(total: Int, locked: Int, price: String?, purchasing: Bool, enabled: Bool) {
        titleLabel.text = "Unlock All \(total) Stickers"
        subtitleLabel.text = "\(locked) locked · One-time purchase"
        if purchasing {
            unlockButton.setTitle("Purchasing…", for: .normal)
        } else if let price {
            unlockButton.setTitle("Unlock Everything  ·  \(price)", for: .normal)
        } else {
            unlockButton.setTitle("Unlock Everything", for: .normal)
        }
        unlockButton.isEnabled = enabled && !purchasing
        unlockButton.alpha = unlockButton.isEnabled ? 1 : 0.45
        restoreButton.isEnabled = !purchasing
    }
}

/// Full paywall presented when a locked sticker is tapped.
final class PaywallViewController: UIViewController {

    private let total: Int
    private let locked: Int
    private var price: String?
    private let purchasing: Bool
    private let canBuy: Bool

    var onBuy: (() -> Void)?
    var onRestore: (() -> Void)?

    private let buyButton = GradientButton(colors: [Brand.pink, Brand.purple])
    private let statusLabel = UILabel()

    init(total: Int, locked: Int, price: String?, purchasing: Bool, canBuy: Bool) {
        self.total = total
        self.locked = locked
        self.price = price
        self.purchasing = purchasing
        self.canBuy = canBuy
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground

        let hero = UIImageView(image: UIImage(systemName: "sparkles"))
        hero.tintColor = Brand.yellow
        hero.contentMode = .scaleAspectFit
        hero.preferredSymbolConfiguration = UIImage.SymbolConfiguration(
            pointSize: 44, weight: .bold)

        let title = UILabel()
        title.text = "Unlock All \(total) Stickers"
        title.font = .systemFont(ofSize: 26, weight: .heavy)
        title.textAlignment = .center
        title.numberOfLines = 0
        title.adjustsFontForContentSizeCategory = true

        let blurb = UILabel()
        blurb.text = "\(locked) more animated birthday jokes.\nOne-time purchase — yours forever."
        blurb.font = .systemFont(ofSize: 15)
        blurb.textColor = .secondaryLabel
        blurb.textAlignment = .center
        blurb.numberOfLines = 0
        blurb.adjustsFontForContentSizeCategory = true

        let bullets = UIStackView(arrangedSubviews: [
            Self.bullet("checkmark.seal.fill", "All \(total) animated stickers"),
            Self.bullet("infinity", "No subscription, no ads"),
            Self.bullet("person.2.fill", "Shared with your family"),
        ])
        bullets.axis = .vertical
        bullets.spacing = 10

        buyButton.translatesAutoresizingMaskIntoConstraints = false
        buyButton.setTitle(buyTitle(), for: .normal)
        buyButton.isEnabled = canBuy && !purchasing
        buyButton.alpha = buyButton.isEnabled ? 1 : 0.45
        buyButton.addTarget(self, action: #selector(buyTapped), for: .touchUpInside)

        statusLabel.text = canBuy ? nil : "The store isn’t reachable right now."
        statusLabel.font = .systemFont(ofSize: 12)
        statusLabel.textColor = .tertiaryLabel
        statusLabel.textAlignment = .center
        statusLabel.numberOfLines = 0

        let restore = UIButton(type: .system)
        restore.setTitle("Restore Purchase", for: .normal)
        restore.titleLabel?.font = .systemFont(ofSize: 14, weight: .semibold)
        restore.addTarget(self, action: #selector(restoreTapped), for: .touchUpInside)

        let close = UIButton(type: .system)
        close.setTitle("Not Now", for: .normal)
        close.titleLabel?.font = .systemFont(ofSize: 14)
        close.setTitleColor(.secondaryLabel, for: .normal)
        close.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)

        let stack = UIStackView(arrangedSubviews: [
            hero, title, blurb, bullets, buyButton, statusLabel, restore, close,
        ])
        stack.axis = .vertical
        stack.spacing = 14
        stack.alignment = .fill
        stack.setCustomSpacing(6, after: hero)
        stack.setCustomSpacing(18, after: blurb)
        stack.setCustomSpacing(18, after: bullets)
        stack.setCustomSpacing(6, after: buyButton)
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            stack.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            buyButton.heightAnchor.constraint(equalToConstant: 52),
            hero.heightAnchor.constraint(equalToConstant: 50),
        ])
    }

    private func buyTitle() -> String {
        if purchasing { return "Purchasing…" }
        if let price { return "Unlock Everything  ·  \(price)" }
        return "Unlock Everything"
    }

    private static func bullet(_ symbol: String, _ text: String) -> UIView {
        let icon = UIImageView(image: UIImage(systemName: symbol))
        icon.tintColor = Brand.blue
        icon.contentMode = .scaleAspectFit
        icon.setContentHuggingPriority(.required, for: .horizontal)
        icon.widthAnchor.constraint(equalToConstant: 22).isActive = true

        let label = UILabel()
        label.text = text
        label.font = .systemFont(ofSize: 15, weight: .medium)
        label.numberOfLines = 0
        label.adjustsFontForContentSizeCategory = true

        let row = UIStackView(arrangedSubviews: [icon, label])
        row.axis = .horizontal
        row.spacing = 10
        row.alignment = .center
        return row
    }

    @objc private func buyTapped() { onBuy?() }
    @objc private func restoreTapped() { onRestore?() }
    @objc private func closeTapped() { dismiss(animated: true) }
}
