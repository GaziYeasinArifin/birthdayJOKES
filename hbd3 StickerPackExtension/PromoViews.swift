import UIKit

/// Scrolling caution-tape ribbon used as the promo section header.
///
/// A CALayer animation rather than a timer: it runs on the render server, so
/// it keeps moving smoothly while the collection view scrolls and costs no
/// main-thread work.
final class MarqueeRibbonView: UICollectionReusableView {

    static let reuseID = "MarqueeRibbonView"
    static let height: CGFloat = 26

    private static let ribbonYellow = UIColor(red: 1.0, green: 0.91, blue: 0.47, alpha: 1)
    private static let speed: CGFloat = 36          // points per second
    private static let font = UIFont.systemFont(ofSize: 10, weight: .black)

    private let scroller = UIView()
    private var unitWidth: CGFloat = 0
    private var title = ""

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = Self.ribbonYellow
        clipsToBounds = true
        scroller.translatesAutoresizingMaskIntoConstraints = false
        addSubview(scroller)
        isAccessibilityElement = true
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func configure(title: String) {
        guard self.title != title else { return }
        self.title = title
        accessibilityLabel = title
        setNeedsLayout()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        rebuild()
    }

    private func rebuild() {
        guard bounds.width > 0, !title.isEmpty else { return }

        let unit = "\(title.uppercased())   •   "
        let attrs: [NSAttributedString.Key: Any] = [
            .font: Self.font,
            .foregroundColor: UIColor.black,
            .kern: 1.4,
        ]
        let measured = (unit as NSString).size(withAttributes: attrs).width
        guard measured > 0 else { return }

        // Enough repeats to cover the bar plus one spare, so whatever the
        // offset the text always spans the full width.
        let repeats = Int((bounds.width / measured).rounded(.up)) + 2
        guard scroller.layer.sublayers?.count != repeats || unitWidth != measured else { return }

        unitWidth = measured
        scroller.layer.sublayers?.forEach { $0.removeFromSuperlayer() }
        scroller.layer.removeAllAnimations()

        for i in 0..<repeats {
            let text = CATextLayer()
            text.string = NSAttributedString(string: unit, attributes: attrs)
            text.contentsScale = UIScreen.main.scale
            text.frame = CGRect(x: CGFloat(i) * measured, y: 0,
                                width: measured, height: bounds.height)
            text.alignmentMode = .left
            // Vertically centre the glyphs inside the layer.
            text.frame.origin.y = (bounds.height - Self.font.lineHeight) / 2
            text.frame.size.height = Self.font.lineHeight
            scroller.layer.addSublayer(text)
        }
        scroller.frame = CGRect(x: 0, y: 0,
                                width: measured * CGFloat(repeats), height: bounds.height)

        let slide = CABasicAnimation(keyPath: "position.x")
        slide.byValue = -measured
        slide.duration = CFTimeInterval(measured / Self.speed)
        slide.repeatCount = .infinity
        slide.isRemovedOnCompletion = false
        scroller.layer.add(slide, forKey: "marquee")
    }
}

/// One promoted app: icon, name, tagline, price badge and a Get pill.
final class PromoRowCell: UICollectionViewCell {

    static let reuseID = "PromoRowCell"
    static let height: CGFloat = 88

    private let artwork = UIImageView()
    private let artworkFallback = CAGradientLayer()
    private let glyph = UIImageView()
    private let nameLabel = UILabel()
    private let taglineLabel = UILabel()
    private let priceLabel = PaddedLabel()
    private let getPill = UIView()

    override init(frame: CGRect) {
        super.init(frame: frame)

        contentView.backgroundColor = .tertiarySystemBackground
        contentView.layer.cornerRadius = 16
        contentView.layer.cornerCurve = .continuous
        contentView.layer.borderWidth = 1
        contentView.clipsToBounds = true

        artwork.translatesAutoresizingMaskIntoConstraints = false
        artwork.contentMode = .scaleAspectFill
        artwork.clipsToBounds = true
        artwork.layer.cornerRadius = 13
        artwork.layer.cornerCurve = .continuous
        artwork.layer.addSublayer(artworkFallback)
        artworkFallback.startPoint = CGPoint(x: 0, y: 0)
        artworkFallback.endPoint = CGPoint(x: 1, y: 1)

        glyph.translatesAutoresizingMaskIntoConstraints = false
        glyph.tintColor = .white
        glyph.contentMode = .center
        artwork.addSubview(glyph)

        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        nameLabel.font = .systemFont(ofSize: 15, weight: .semibold)
        nameLabel.textColor = .label
        nameLabel.adjustsFontSizeToFitWidth = true
        nameLabel.minimumScaleFactor = 0.85

        taglineLabel.translatesAutoresizingMaskIntoConstraints = false
        taglineLabel.font = .systemFont(ofSize: 12)
        taglineLabel.textColor = .secondaryLabel
        taglineLabel.numberOfLines = 2

        priceLabel.translatesAutoresizingMaskIntoConstraints = false
        priceLabel.font = .systemFont(ofSize: 11, weight: .bold)
        priceLabel.insets = UIEdgeInsets(top: 2, left: 6, bottom: 2, right: 6)
        priceLabel.layer.cornerRadius = 8
        priceLabel.layer.cornerCurve = .continuous
        priceLabel.clipsToBounds = true

        getPill.translatesAutoresizingMaskIntoConstraints = false
        getPill.backgroundColor = UIColor(red: 0.10, green: 0.45, blue: 0.95, alpha: 1)
        getPill.layer.cornerRadius = 15
        getPill.isUserInteractionEnabled = false

        let arrow = UIImageView(image: UIImage(systemName: "arrow.down",
            withConfiguration: UIImage.SymbolConfiguration(pointSize: 9, weight: .heavy)))
        arrow.tintColor = .white
        let get = UILabel()
        get.text = "Get"
        get.font = .systemFont(ofSize: 13, weight: .bold)
        get.textColor = .white
        let pillStack = UIStackView(arrangedSubviews: [arrow, get])
        pillStack.spacing = 4
        pillStack.alignment = .center
        pillStack.translatesAutoresizingMaskIntoConstraints = false
        getPill.addSubview(pillStack)

        let text = UIStackView(arrangedSubviews: [nameLabel, taglineLabel])
        text.axis = .vertical
        text.spacing = 2
        text.alignment = .leading
        text.translatesAutoresizingMaskIntoConstraints = false

        contentView.addSubview(artwork)
        contentView.addSubview(text)
        contentView.addSubview(priceLabel)
        contentView.addSubview(getPill)

        NSLayoutConstraint.activate([
            artwork.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 11),
            artwork.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            artwork.widthAnchor.constraint(equalToConstant: 54),
            artwork.heightAnchor.constraint(equalToConstant: 54),
            glyph.centerXAnchor.constraint(equalTo: artwork.centerXAnchor),
            glyph.centerYAnchor.constraint(equalTo: artwork.centerYAnchor),

            text.leadingAnchor.constraint(equalTo: artwork.trailingAnchor, constant: 12),
            text.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            text.trailingAnchor.constraint(lessThanOrEqualTo: getPill.leadingAnchor, constant: -8),

            priceLabel.leadingAnchor.constraint(equalTo: text.leadingAnchor),
            priceLabel.topAnchor.constraint(equalTo: text.bottomAnchor, constant: 4),
            priceLabel.bottomAnchor.constraint(lessThanOrEqualTo: contentView.bottomAnchor, constant: -10),

            getPill.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -11),
            getPill.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            getPill.heightAnchor.constraint(equalToConstant: 30),
            pillStack.centerXAnchor.constraint(equalTo: getPill.centerXAnchor),
            pillStack.centerYAnchor.constraint(equalTo: getPill.centerYAnchor),
            pillStack.leadingAnchor.constraint(equalTo: getPill.leadingAnchor, constant: 11),
            pillStack.trailingAnchor.constraint(equalTo: getPill.trailingAnchor, constant: -11),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layoutSubviews() {
        super.layoutSubviews()
        artworkFallback.frame = artwork.bounds
    }

    override var isHighlighted: Bool {
        didSet {
            UIView.animate(withDuration: 0.15) {
                self.contentView.transform = self.isHighlighted
                    ? CGAffineTransform(scaleX: 0.97, y: 0.97) : .identity
                self.contentView.alpha = self.isHighlighted ? 0.95 : 1
            }
        }
    }

    func configure(_ pack: PromoPack, image: UIImage?) {
        nameLabel.text = pack.name
        taglineLabel.text = pack.tagline
        priceLabel.text = pack.price
        priceLabel.textColor = pack.accentStart
        priceLabel.backgroundColor = pack.accentStart.withAlphaComponent(0.12)
        contentView.layer.borderColor = pack.accentStart.withAlphaComponent(0.22).cgColor

        if let image {
            artwork.image = image
            artworkFallback.isHidden = true
            glyph.isHidden = true
        } else {
            // No artwork bundled: show the accent gradient and glyph rather
            // than an empty tile.
            artwork.image = nil
            artworkFallback.isHidden = false
            artworkFallback.colors = [pack.accentStart.cgColor, pack.accentEnd.cgColor]
            glyph.isHidden = false
            glyph.image = UIImage(systemName: pack.symbolName,
                withConfiguration: UIImage.SymbolConfiguration(pointSize: 22, weight: .semibold))
        }

        isAccessibilityElement = true
        accessibilityTraits = .button
        accessibilityLabel = "\(pack.name), \(pack.price). \(pack.tagline)"
        accessibilityHint = "Opens this app's App Store page so you can install it"
    }
}

/// UILabel with content insets, for the price badge.
final class PaddedLabel: UILabel {
    var insets: UIEdgeInsets = .zero

    override func drawText(in rect: CGRect) {
        super.drawText(in: rect.inset(by: insets))
    }

    override var intrinsicContentSize: CGSize {
        let s = super.intrinsicContentSize
        return CGSize(width: s.width + insets.left + insets.right,
                      height: s.height + insets.top + insets.bottom)
    }
}
