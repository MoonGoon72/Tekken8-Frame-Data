import UIKit
import XCTest
@testable import TK8

@MainActor
final class MemoListLayoutTests: XCTestCase {
    func test_emptyListCanEnterNavigationBeforeFirstLayout() {
        verifyNavigationLayout(itemCount: 0, size: CGSize(width: 320, height: 568))
    }

    func test_populatedListCanEnterNavigationBeforeFirstLayout() {
        verifyNavigationLayout(itemCount: 10, size: CGSize(width: 393, height: 852))
    }

    private func verifyNavigationLayout(itemCount: Int, size: CGSize) {
        let list = MemoListView()
        let collection = list.collectionView
        // Navigation and snapshot updates can touch scroll geometry before Auto Layout.
        XCTAssertFalse(collection.frame.isInfinite)
        XCTAssertLessThanOrEqual(collection.bounds.width, size.width)
        XCTAssertLessThanOrEqual(collection.bounds.height, size.height)

        let dataSource = UICollectionViewDiffableDataSource<Int, Int>(collectionView: collection) {
            collection, indexPath, _ in
            collection.dequeueReusableCell(
                withReuseIdentifier: MemoCollectionViewCell.reuseIdentifier,
                for: indexPath
            )
        }
        dataSource.supplementaryViewProvider = { collection, kind, indexPath in
            collection.dequeueReusableSupplementaryView(
                ofKind: kind,
                withReuseIdentifier: MemoSectionHeaderView.reuseIdentifier,
                for: indexPath
            )
        }
        var snapshot = NSDiffableDataSourceSnapshot<Int, Int>()
        snapshot.appendSections([0])
        snapshot.appendItems(Array(0..<itemCount))
        dataSource.apply(snapshot, animatingDifferences: false)

        let controller = UIViewController()
        controller.view = list
        controller.navigationItem.searchController = UISearchController(searchResultsController: nil)
        controller.navigationItem.hidesSearchBarWhenScrolling = false
        let navigation = UINavigationController(rootViewController: UIViewController())
        let window = UIWindow(frame: CGRect(origin: .zero, size: size))
        window.rootViewController = navigation
        window.makeKeyAndVisible()
        defer { window.isHidden = true }

        navigation.pushViewController(controller, animated: false)
        window.layoutIfNeeded()
        list.layoutIfNeeded()
        collection.flashScrollIndicators()

        XCTAssertEqual(collection.frame, list.bounds)
        XCTAssertGreaterThan(collection.bounds.width, 0)
        XCTAssertGreaterThan(collection.bounds.height, 0)
        let inset = collection.adjustedContentInset
        let geometry = [collection.frame.origin.x, collection.frame.origin.y,
                        collection.bounds.width, collection.bounds.height,
                        collection.contentSize.width, collection.contentSize.height,
                        collection.contentOffset.x, collection.contentOffset.y,
                        inset.top, inset.left, inset.bottom, inset.right]
        XCTAssertTrue(geometry.allSatisfy { $0.isFinite })
        withExtendedLifetime(dataSource) {}
    }
}
