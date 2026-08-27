import AsyncDisplayKit

/// A single row in the claims list: bold title, a two-line description
/// preview, and the claim/claimant identifiers, laid out with Texture's
/// automatic layout system so cell sizing stays off the main thread.
final class ClaimCellNode: ASCellNode {
    /// Shared with the separator's insets so the divider lines up with the
    /// content's left/right edges instead of running edge-to-edge.
    private static let horizontalContentInset: CGFloat = 16

    private let titleNode = ASTextNode()
    private let descriptionNode = ASTextNode()
    private let metadataNode = ASTextNode()
    private let separatorNode = ASDisplayNode()

    init(claim: Claim) {
        super.init()
        automaticallyManagesSubnodes = true
        selectionStyle = .default
        separatorNode.backgroundColor = .adaptiveSeparator

        titleNode.attributedText = NSAttributedString(
            string: claim.title.capitalized,
            attributes: [
                .font: UIFont.preferredFont(forTextStyle: .headline),
                .foregroundColor: UIColor.adaptiveLabel
            ]
        )

        descriptionNode.attributedText = NSAttributedString(
            string: claim.description,
            attributes: [
                .font: UIFont.preferredFont(forTextStyle: .subheadline),
                .foregroundColor: UIColor.adaptiveSecondaryLabel
            ]
        )
        descriptionNode.maximumNumberOfLines = 2
        descriptionNode.truncationMode = .byTruncatingTail

        metadataNode.attributedText = NSAttributedString(
            string: "Claim #\(claim.id) · Claimant #\(claim.claimantId)",
            attributes: [
                .font: UIFont.preferredFont(forTextStyle: .caption1),
                .foregroundColor: UIColor.adaptiveTertiaryLabel
            ]
        )
    }

    override func layoutSpecThatFits(_ constrainedSize: ASSizeRange) -> ASLayoutSpec {
        let textStack = ASStackLayoutSpec(
            direction: .vertical,
            spacing: 4,
            justifyContent: .start,
            alignItems: .stretch,
            children: [titleNode, descriptionNode, metadataNode]
        )

        let insetText = ASInsetLayoutSpec(
            insets: UIEdgeInsets(
                top: 12,
                left: Self.horizontalContentInset,
                bottom: 12,
                right: Self.horizontalContentInset
            ),
            child: textStack
        )

        // A full point, not a hairline, so the grey divider between rows
        // reads clearly rather than disappearing at a glance.
        separatorNode.style.height = ASDimensionMake(1.0)
        let insetSeparator = ASInsetLayoutSpec(
            insets: UIEdgeInsets(
                top: 0,
                left: Self.horizontalContentInset,
                bottom: 0,
                right: Self.horizontalContentInset
            ),
            child: separatorNode
        )

        return ASStackLayoutSpec(
            direction: .vertical,
            spacing: 0,
            justifyContent: .start,
            alignItems: .stretch,
            children: [insetText, insetSeparator]
        )
    }
}
