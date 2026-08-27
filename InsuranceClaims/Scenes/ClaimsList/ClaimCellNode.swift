import AsyncDisplayKit

/// A single row in the claims list: bold title, a two-line description
/// preview, and the claim/claimant identifiers, laid out with Texture's
/// automatic layout system so cell sizing stays off the main thread.
final class ClaimCellNode: ASCellNode {
    private let titleNode = ASTextNode()
    private let descriptionNode = ASTextNode()
    private let metadataNode = ASTextNode()

    init(claim: Claim) {
        super.init()
        automaticallyManagesSubnodes = true
        selectionStyle = .default

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

        return ASInsetLayoutSpec(
            insets: UIEdgeInsets(top: 12, left: 16, bottom: 12, right: 16),
            child: textStack
        )
    }
}
