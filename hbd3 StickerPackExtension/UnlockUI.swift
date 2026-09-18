import UIKit

/// Brand palette lifted from the app icon.
enum Brand {
    static let pink = UIColor(red: 0.91, green: 0.09, blue: 0.44, alpha: 1)
    static let yellow = UIColor(red: 1.00, green: 0.82, blue: 0.08, alpha: 1)
    static let blue = UIColor(red: 0.24, green: 0.53, blue: 0.96, alpha: 1)
    static let purple = UIColor(red: 0.58, green: 0.35, blue: 0.94, alpha: 1)
    static let ink = UIColor(red: 0.07, green: 0.07, blue: 0.09, alpha: 1)
}

/// Solid-fill pill button with press feedback.
final class PillButton: UIButton {

    private let fill: UIColor

    init(fill: UIColor, title: UIColor, size: CGFloat = 15, weight: UIFont.Weight = .bold) {
        self.fill = fill
        super.init(frame: .zero)
        backgroundColor = fill
        setTitleColor(title, for: .normal)
        titleLabel?.font = .systemFont(ofSize: size, weight: weight)
        titleLabel?.adjustsFontSizeToFitWidth = true
        titleLabel?.minimumScaleFactor = 0.75
        titleLabel?.lineBreakMode = .byClipping
        layer.cornerCurve = .continuous
        layer.shadowColor = fill.cgColor
        layer.shadowOpacity = 0.4
        layer.shadowRadius = 8
        layer.shadowOffset = CGSize(width: 0, height: 3)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layoutSubviews() {
        super.layoutSubviews()
        layer.cornerRadius = min(bounds.height / 2, 22)
    }

    override var isHighlighted: Bool {
        didSet {
            UIView.animate(withDuration: 0.12) {
                self.transform = self.isHighlighted
                    ? CGAffineTransform(scaleX: 0.96, y: 0.96) : .identity
            }
        }
    }

    override var isEnabled: Bool {
        didSet { alpha = isEnabled ? 1 : 0.4 }
    }
}

/// Top bar: dark blurred gradient that melts into the grid, with the title on
/// the left and Restore / Get stacked on the right.
final class UnlockBanner: UIView {

    /// Height of the row holding the title and button, below any safe-area inset.
    static let rowHeight: CGFloat = 76

    let unlockButton = PillButton(fill: Brand.yellow, title: Brand.ink, size: 15)

    private let titleLabel = UILabel()
    /// `.systemChromeMaterial` follows light/dark automatically, unlike the
    /// `...Dark` variants which are pinned.
    private let blur = UIVisualEffectView(effect: UIBlurEffect(style: .systemChromeMaterial))
    private let tint = CAGradientLayer()
    private let blurMask = CAGradientLayer()
    private let row = UIView()

    /// Scrim under the bar: darkens in dark mode, lightens in light mode, so
    /// the blur reads as a blend against either background.
    private static let scrim = UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor.black.withAlphaComponent(0.80)
            : UIColor.white.withAlphaComponent(0.82)
    }

    init() {
        super.init(frame: .zero)

        // Blur fades out toward the bottom so the bar blends into the grid
        // rather than ending on a hard edge.
        blur.translatesAutoresizingMaskIntoConstraints = false
        blur.isUserInteractionEnabled = false
        addSubview(blur)

        blurMask.colors = [
            UIColor.white.cgColor,
            UIColor.white.cgColor,
            UIColor.white.withAlphaComponent(0).cgColor,
        ]
        blurMask.locations = [0, 0.62, 1]
        blur.layer.mask = blurMask

        tint.locations = [0, 0.6, 1]
        layer.insertSublayer(tint, at: 0)
        applyScrimColors()

        // The bar extends under the status bar so nothing scrolls through the
        // gap above it; the title/button row sits in the bottom portion.
        row.translatesAutoresizingMaskIntoConstraints = false
        addSubview(row)

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.text = "Unlock All for Lifetime"
        titleLabel.font = .systemFont(ofSize: 19, weight: .heavy)
        titleLabel.textColor = .label
        titleLabel.numberOfLines = 2
        titleLabel.adjustsFontSizeToFitWidth = true
        titleLabel.minimumScaleFactor = 0.7
        titleLabel.adjustsFontForContentSizeCategory = true
        row.addSubview(titleLabel)

        unlockButton.translatesAutoresizingMaskIntoConstraints = false
        row.addSubview(unlockButton)

        NSLayoutConstraint.activate([
            blur.topAnchor.constraint(equalTo: topAnchor),
            blur.leadingAnchor.constraint(equalTo: leadingAnchor),
            blur.trailingAnchor.constraint(equalTo: trailingAnchor),
            blur.bottomAnchor.constraint(equalTo: bottomAnchor),

            row.leadingAnchor.constraint(equalTo: leadingAnchor),
            row.trailingAnchor.constraint(equalTo: trailingAnchor),
            row.bottomAnchor.constraint(equalTo: bottomAnchor),
            row.heightAnchor.constraint(equalToConstant: Self.rowHeight),

            // Title and button share one baseline: both centred in the row.
            titleLabel.leadingAnchor.constraint(equalTo: row.leadingAnchor, constant: 18),
            titleLabel.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: unlockButton.leadingAnchor,
                                                 constant: -12),

            unlockButton.trailingAnchor.constraint(equalTo: row.trailingAnchor, constant: -18),
            unlockButton.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            unlockButton.heightAnchor.constraint(equalToConstant: 42),
            unlockButton.widthAnchor.constraint(equalTo: widthAnchor, multiplier: 0.33),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layoutSubviews() {
        super.layoutSubviews()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        tint.frame = bounds
        blurMask.frame = blur.bounds
        CATransaction.commit()
    }

    /// CAGradientLayer holds raw CGColors, which don't follow trait changes
    /// the way UIColor does — so resolve them again whenever the style flips.
    override func traitCollectionDidChange(_ previous: UITraitCollection?) {
        super.traitCollectionDidChange(previous)
        if traitCollection.hasDifferentColorAppearance(comparedTo: previous) {
            applyScrimColors()
        }
    }

    private func applyScrimColors() {
        let base = Self.scrim.resolvedColor(with: traitCollection)
        var alpha: CGFloat = 0
        base.getWhite(nil, alpha: &alpha)
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        tint.colors = [
            base.cgColor,
            base.withAlphaComponent(alpha * 0.68).cgColor,
            base.withAlphaComponent(0).cgColor,
        ]
        CATransaction.commit()
    }

    func update(price: String?, purchasing: Bool, enabled: Bool) {
        if purchasing {
            unlockButton.setTitle("…", for: .normal)
        } else if let price {
            unlockButton.setTitle("Get \(price)", for: .normal)
        } else {
            unlockButton.setTitle("Get", for: .normal)
        }
        unlockButton.isEnabled = enabled && !purchasing
    }
}

/// Full paywall, presented when a locked sticker or the Get button is tapped.
final class PaywallViewController: UIViewController {

    private let total: Int
    private let locked: Int
    private let price: String?
    private let purchasing: Bool
    private let canBuy: Bool
    private let heroImage: UIImage?

    var onBuy: (() -> Void)?
    var onRestore: (() -> Void)?

    private let buyButton = PillButton(fill: Brand.yellow, title: Brand.ink,
                                       size: 18, weight: .heavy)

    init(total: Int, locked: Int, price: String?, purchasing: Bool,
         canBuy: Bool, heroImage: UIImage?) {
        self.total = total
        self.locked = locked
        self.price = price
        self.purchasing = purchasing
        self.canBuy = canBuy
        self.heroImage = heroImage
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground

        // Soft brand glow behind the hero.
        let glow = CAGradientLayer()
        glow.type = .radial
        glow.startPoint = CGPoint(x: 0.5, y: 0.5)
        glow.endPoint = CGPoint(x: 1, y: 1)
        view.layer.insertSublayer(glow, at: 0)
        self.glowLayer = glow
        applyGlowColors()

        // iMessage app icons are 4:3, not square — the artwork here is the
        // 1024x768 icon, shown at iOS's continuous-curve corner radius.
        let heroW: CGFloat = 248
        let heroH: CGFloat = heroW * 3 / 4
        let hero = UIImageView(image: heroImage)
        hero.translatesAutoresizingMaskIntoConstraints = false
        hero.contentMode = .scaleAspectFill
        hero.clipsToBounds = true
        hero.layer.cornerRadius = heroH * 0.2237
        hero.layer.cornerCurve = .continuous

        // Shadow needs its own view, since the image view clips to its corners.
        let heroShadow = UIView()
        heroShadow.translatesAutoresizingMaskIntoConstraints = false
        // Needs an opaque fill: a layer shadow is cast by the layer's own
        // contents, not by its subviews, so a clear wrapper casts nothing.
        heroShadow.backgroundColor = .systemBackground
        heroShadow.layer.cornerRadius = hero.layer.cornerRadius
        heroShadow.layer.cornerCurve = .continuous
        heroShadow.layer.shadowColor = Brand.purple.cgColor
        heroShadow.layer.shadowOpacity = 0.45
        heroShadow.layer.shadowRadius = 22
        heroShadow.layer.shadowOffset = CGSize(width: 0, height: 10)
        heroShadow.addSubview(hero)

        let title = UILabel()
        title.text = "Unlock All for Lifetime"
        title.font = .systemFont(ofSize: 28, weight: .heavy)
        title.textColor = .label
        title.textAlignment = .center
        title.numberOfLines = 0
        title.adjustsFontForContentSizeCategory = true

        let blurb = UILabel()
        blurb.text = "\(locked) more animated birthday jokes,\nunlocked forever."
        blurb.font = .systemFont(ofSize: 15, weight: .medium)
        blurb.textColor = .secondaryLabel
        blurb.textAlignment = .center
        blurb.numberOfLines = 0
        blurb.adjustsFontForContentSizeCategory = true

        let bullets = UIStackView(arrangedSubviews: [
            Self.bullet("sparkles", "All \(total) animated stickers", Brand.yellow),
            Self.bullet("bolt.heart.fill", "One payment, no subscription", Brand.pink),
            Self.bullet("person.2.fill", "Shared with your family", Brand.blue),
        ])
        bullets.axis = .vertical
        bullets.spacing = 14

        buyButton.translatesAutoresizingMaskIntoConstraints = false
        buyButton.setTitle(buyTitle(), for: .normal)
        buyButton.isEnabled = canBuy && !purchasing
        buyButton.addTarget(self, action: #selector(buyTapped), for: .touchUpInside)

        let note = UILabel()
        note.text = canBuy ? "One-time purchase · Restores on all your devices"
                           : "The store isn’t reachable right now."
        note.font = .systemFont(ofSize: 11, weight: .medium)
        note.textColor = .tertiaryLabel
        note.textAlignment = .center
        note.numberOfLines = 0

        let restore = UIButton(type: .system)
        restore.setTitle("Restore Purchase", for: .normal)
        restore.titleLabel?.font = .systemFont(ofSize: 14, weight: .semibold)
        restore.setTitleColor(.label, for: .normal)
        restore.addTarget(self, action: #selector(restoreTapped), for: .touchUpInside)

        let close = UIButton(type: .system)
        close.setTitle("Not Now", for: .normal)
        close.titleLabel?.font = .systemFont(ofSize: 14)
        close.setTitleColor(.secondaryLabel, for: .normal)
        close.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)

        let stack = UIStackView(arrangedSubviews: [
            heroShadow, title, blurb, bullets, buyButton, note, restore, close,
        ])
        stack.axis = .vertical
        stack.spacing = 16
        stack.alignment = .center
        stack.setCustomSpacing(22, after: heroShadow)
        stack.setCustomSpacing(10, after: title)
        stack.setCustomSpacing(26, after: blurb)
        stack.setCustomSpacing(26, after: bullets)
        stack.setCustomSpacing(8, after: buyButton)
        stack.setCustomSpacing(18, after: note)
        stack.translatesAutoresizingMaskIntoConstraints = false

        // Scrollable so the sheet survives small iPhones, large Dynamic Type
        // and the short compact presentation without clipping.
        let scroll = UIScrollView()
        scroll.translatesAutoresizingMaskIntoConstraints = false
        scroll.alwaysBounceVertical = true
        scroll.showsVerticalScrollIndicator = false
        view.addSubview(scroll)

        // A container pinned to the content guide gives the scroll view an
        // unambiguous content size; the stack is then centred inside it.
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false
        scroll.addSubview(container)
        container.addSubview(stack)

        // Prefer filling the visible height (so short content centres), but
        // grow when the content is taller.
        let fillHeight = container.heightAnchor.constraint(
            equalTo: scroll.frameLayoutGuide.heightAnchor)
        fillHeight.priority = .defaultLow

        let centring = stack.centerYAnchor.constraint(equalTo: container.centerYAnchor)
        centring.priority = .defaultLow

        // Width is min(container - 48, 420): the cap keeps it readable on
        // iPad, the preferred width lets it reach the cap when there's room.
        let preferredWidth = stack.widthAnchor.constraint(equalToConstant: 420)
        preferredWidth.priority = .defaultHigh

        NSLayoutConstraint.activate([
            scroll.topAnchor.constraint(equalTo: view.topAnchor),
            scroll.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scroll.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            container.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor),
            container.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor),
            container.leadingAnchor.constraint(equalTo: scroll.contentLayoutGuide.leadingAnchor),
            container.trailingAnchor.constraint(equalTo: scroll.contentLayoutGuide.trailingAnchor),
            // Matching the frame width prevents horizontal scrolling.
            container.widthAnchor.constraint(equalTo: scroll.frameLayoutGuide.widthAnchor),
            container.heightAnchor.constraint(greaterThanOrEqualTo: stack.heightAnchor,
                                              constant: 48),
            fillHeight,

            stack.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            stack.topAnchor.constraint(greaterThanOrEqualTo: container.topAnchor,
                                       constant: 24),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: container.bottomAnchor,
                                          constant: -24),
            stack.widthAnchor.constraint(lessThanOrEqualTo: container.widthAnchor,
                                         constant: -48),
            stack.widthAnchor.constraint(lessThanOrEqualToConstant: 420),
            centring, preferredWidth,

            heroShadow.widthAnchor.constraint(equalToConstant: heroW),
            heroShadow.heightAnchor.constraint(equalToConstant: heroH),
            hero.topAnchor.constraint(equalTo: heroShadow.topAnchor),
            hero.leadingAnchor.constraint(equalTo: heroShadow.leadingAnchor),
            hero.trailingAnchor.constraint(equalTo: heroShadow.trailingAnchor),
            hero.bottomAnchor.constraint(equalTo: heroShadow.bottomAnchor),

            buyButton.heightAnchor.constraint(equalToConstant: 56),
            buyButton.leadingAnchor.constraint(equalTo: stack.leadingAnchor),
            buyButton.trailingAnchor.constraint(equalTo: stack.trailingAnchor),
            bullets.leadingAnchor.constraint(equalTo: stack.leadingAnchor, constant: 8),
            bullets.trailingAnchor.constraint(equalTo: stack.trailingAnchor, constant: -8),
            title.widthAnchor.constraint(equalTo: stack.widthAnchor),
            blurb.widthAnchor.constraint(equalTo: stack.widthAnchor),
            note.widthAnchor.constraint(equalTo: stack.widthAnchor),
        ])
    }

    /// Radial glow holds CGColors, so re-resolve it when the style flips.
    override func traitCollectionDidChange(_ previous: UITraitCollection?) {
        super.traitCollectionDidChange(previous)
        if traitCollection.hasDifferentColorAppearance(comparedTo: previous) {
            applyGlowColors()
        }
    }

    private func applyGlowColors() {
        let strength = traitCollection.userInterfaceStyle == .dark ? 0.55 : 0.22
        glowLayer?.colors = [Brand.purple.withAlphaComponent(strength).cgColor,
                             UIColor.clear.cgColor]
    }

    private var glowLayer: CAGradientLayer?

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let side = max(view.bounds.width, 460)
        glowLayer?.frame = CGRect(x: view.bounds.midX - side / 2,
                                  y: view.bounds.midY - side * 0.85,
                                  width: side, height: side)
    }

    private func buyTitle() -> String {
        if purchasing { return "Purchasing…" }
        if let price { return "Get \(price)" }
        return "Unlock Everything"
    }

    private static func bullet(_ symbol: String, _ text: String,
                               _ tint: UIColor) -> UIView {
        let icon = UIImageView(image: UIImage(systemName: symbol))
        icon.tintColor = tint
        icon.contentMode = .scaleAspectFit
        icon.setContentHuggingPriority(.required, for: .horizontal)
        icon.widthAnchor.constraint(equalToConstant: 26).isActive = true

        let label = UILabel()
        label.text = text
        label.font = .systemFont(ofSize: 15, weight: .semibold)
        label.textColor = UIColor.white.withAlphaComponent(0.9)
        label.numberOfLines = 0
        label.adjustsFontForContentSizeCategory = true

        let row = UIStackView(arrangedSubviews: [icon, label])
        row.axis = .horizontal
        row.spacing = 12
        row.alignment = .center
        return row
    }

    @objc private func buyTapped() { onBuy?() }
    @objc private func restoreTapped() { onRestore?() }
    @objc private func closeTapped() { dismiss(animated: true) }
}
