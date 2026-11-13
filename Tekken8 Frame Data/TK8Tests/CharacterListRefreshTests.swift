import Combine
import XCTest
@testable import TK8

final class CharacterListRefreshTests: XCTestCase {
    @MainActor
    func testCacheReplacementKeepsActiveSearchAndResetClearsIt() async {
        let king = Character(id: 1, nameEN: "King", nameKR: "킹", imageURL: "")
        let armorKing = Character(id: 2, nameEN: "Armor King", nameKR: "아머 킹", imageURL: "")
        let alisa = Character(id: 3, nameEN: "Alisa", nameKR: "알리사", imageURL: "")
        let repository = RefreshCharacterRepository(characters: [king, alisa])
        let viewModel = CharacterListViewModel(characterRepository: repository)
        let initial = expectation(description: "Initial search")
        let initialSubscription = viewModel.$filteredCharacters.first { $0 == [king] }.sink { _ in initial.fulfill() }
        viewModel.filter(by: "King")
        viewModel.fetchCharacters()
        await fulfillment(of: [initial], timeout: 2)
        initialSubscription.cancel()

        repository.characters = [king, armorKing, alisa]
        let refreshed = expectation(description: "Search reapplied after cache replacement")
        let refreshSubscription = viewModel.$filteredCharacters.dropFirst().first().sink {
            XCTAssertEqual(Set($0), [king, armorKing])
            refreshed.fulfill()
        }
        NotificationCenter.default.post(name: .frameDataReplaced, object: nil)
        await fulfillment(of: [refreshed], timeout: 2)
        refreshSubscription.cancel()

        viewModel.resetFilter()
        XCTAssertEqual(Set(viewModel.filteredCharacters), [king, armorKing, alisa])
    }
}

private final class RefreshCharacterRepository: CharacterRepository {
    var characters: [Character]

    init(characters: [Character]) { self.characters = characters }

    @MainActor
    func fetchCharacters() async throws -> [Character] { characters }

    func characterImageURL(character: Character) throws -> URL { throw URLError(.badURL) }
}
