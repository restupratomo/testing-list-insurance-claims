import AsyncDisplayKit

/// Full-detail screen for a single claim: title, complete description and
/// identifiers, laid out with Texture so it composes with the rest of the app.
final class ClaimDetailViewController: ASDKViewController<ClaimDetailContentNode> {

    init(viewModel: ClaimDetailViewModel) {
        let contentNode = ClaimDetailContentNode(viewModel: viewModel)
        super.init(node: contentNode)
        title = viewModel.screenTitle
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
