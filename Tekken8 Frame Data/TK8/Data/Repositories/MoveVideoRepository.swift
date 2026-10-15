import Foundation

struct MoveVideoReference: Equatable, Sendable {
    let moveID: Int64
    let objectKey: String
    let revision: String?
    /// A public playback URL when the deployment uses one. Private R2 buckets
    /// leave this nil and resolve a short lived URL only after the user taps.
    let playbackURL: URL?
}

protocol MoveVideoPlaybackURLProviding {
    func playbackURL(for reference: MoveVideoReference) async throws -> URL
}

struct DefaultMoveVideoPlaybackURLProvider: MoveVideoPlaybackURLProviding {
    private let dataSource: MoveVideoPlaybackURLDataSource

    init(dataSource: MoveVideoPlaybackURLDataSource) {
        self.dataSource = dataSource
    }

    func playbackURL(for reference: MoveVideoReference) async throws -> URL {
        if let playbackURL = reference.playbackURL {
            return playbackURL
        }
        return try await dataSource.fetchMoveVideoPlaybackURL(objectKey: reference.objectKey)
    }
}

enum MoveVideoRepositoryError: LocalizedError, Equatable {
    case missingPlaybackBaseURL
    case invalidPlaybackBaseURL
    case invalidObjectKey(String)
    case missingMoveRelationship(String)
    case duplicateMoveID(Int64)

    var errorDescription: String? {
        switch self {
        case .missingPlaybackBaseURL:
            "MOVE_VIDEO_BASE_URL is not configured."
        case .invalidPlaybackBaseURL:
            "MOVE_VIDEO_BASE_URL must be an HTTPS base URL without credentials, query, or fragment."
        case .invalidObjectKey(let key):
            "Invalid move-video object key: \(key)"
        case .missingMoveRelationship(let key):
            "The move_video row has no related move for key \(key)."
        case .duplicateMoveID(let id):
            "More than one enabled move video is linked to move id \(id)."
        }
    }
}

protocol MoveVideoURLBuilding {
    var isConfigured: Bool { get }
    func validateObjectKey(_ objectKey: String) throws
    func playbackURL(for objectKey: String) throws -> URL
}

struct ConfiguredMoveVideoURLBuilder: MoveVideoURLBuilding {
    private let baseURL: URL?

    /// Explicit nil represents a deployment without a public media endpoint.
    init(baseURL: URL?) {
        self.baseURL = baseURL
    }

    init() {
        if let configuredBaseURL = Bundle.main.object(forInfoDictionaryKey: "MOVE_VIDEO_BASE_URL") as? String,
                  let parsedBaseURL = URL(string: configuredBaseURL) {
            self.baseURL = parsedBaseURL
        } else {
            self.baseURL = nil
        }
    }

    var isConfigured: Bool {
        (try? validatedBaseURLComponents()) != nil
    }

    func validateObjectKey(_ objectKey: String) throws {
        let segments = objectKey.split(separator: "/", omittingEmptySubsequences: false).map(String.init)
        guard !segments.isEmpty,
              segments.allSatisfy({
                  !$0.isEmpty && $0 != "." && $0 != ".." && !$0.contains("\\")
              }) else {
            throw MoveVideoRepositoryError.invalidObjectKey(objectKey)
        }
    }

    func playbackURL(for objectKey: String) throws -> URL {
        var components = try validatedBaseURLComponents()
        try validateObjectKey(objectKey)
        let segments = objectKey.split(separator: "/", omittingEmptySubsequences: false).map(String.init)

        var allowedSegmentCharacters = CharacterSet.urlPathAllowed
        allowedSegmentCharacters.remove(charactersIn: "/?#%")
        let encodedSegments = segments.compactMap {
            $0.addingPercentEncoding(withAllowedCharacters: allowedSegmentCharacters)
        }
        guard encodedSegments.count == segments.count else {
            throw MoveVideoRepositoryError.invalidObjectKey(objectKey)
        }

        let basePath = components.percentEncodedPath.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let objectPath = encodedSegments.joined(separator: "/")
        components.percentEncodedPath = "/" + [basePath, objectPath]
            .filter { !$0.isEmpty }
            .joined(separator: "/")
        guard let url = components.url else {
            throw MoveVideoRepositoryError.invalidPlaybackBaseURL
        }
        return url
    }

    private func validatedBaseURLComponents() throws -> URLComponents {
        guard let baseURL else {
            throw MoveVideoRepositoryError.missingPlaybackBaseURL
        }
        guard let components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false),
              components.scheme?.lowercased() == "https",
              components.host != nil,
              components.user == nil,
              components.password == nil,
              components.query == nil,
              components.fragment == nil else {
            throw MoveVideoRepositoryError.invalidPlaybackBaseURL
        }
        return components
    }
}

protocol MoveVideoRepository {
    var isConfigured: Bool { get }
    func fetchVideos(characterName: String) async throws -> [Int64: MoveVideoReference]
}

struct DefaultMoveVideoRepository: MoveVideoRepository {
    private let dataSource: MoveVideoRemoteDataSource
    private let urlBuilder: MoveVideoURLBuilding

    init(dataSource: MoveVideoRemoteDataSource, urlBuilder: MoveVideoURLBuilding) {
        self.dataSource = dataSource
        self.urlBuilder = urlBuilder
    }

    // Metadata can be read from a private bucket deployment as well. The
    // playback URL is resolved separately after an explicit row tap.
    var isConfigured: Bool { true }

    func fetchVideos(characterName: String) async throws -> [Int64: MoveVideoReference] {
        let rows = try await dataSource.fetchMoveVideos(characterName: characterName)
        var references: [Int64: MoveVideoReference] = [:]
        var seenMoveIDs = Set<Int64>()
        var rejectedMoveIDs = Set<Int64>()

        for row in rows where row.enabled {
            guard let moveID = row.move?.id else {
                NSLog("Skipping move video without a move relationship: %@", row.moveKey)
                continue
            }
            guard !rejectedMoveIDs.contains(moveID) else { continue }
            guard seenMoveIDs.insert(moveID).inserted else {
                references.removeValue(forKey: moveID)
                rejectedMoveIDs.insert(moveID)
                NSLog("Skipping duplicate move-video mapping for move id %@", String(moveID))
                continue
            }
            do {
                try urlBuilder.validateObjectKey(row.objectKey)
                let playbackURL = urlBuilder.isConfigured
                    ? try urlBuilder.playbackURL(for: row.objectKey)
                    : nil
                references[moveID] = MoveVideoReference(
                    moveID: moveID,
                    objectKey: row.objectKey,
                    revision: row.videoRevision,
                    playbackURL: playbackURL
                )
            } catch {
                NSLog("Skipping invalid move-video mapping for %@: %@", row.moveKey, error.localizedDescription)
            }
        }
        return references
    }
}
