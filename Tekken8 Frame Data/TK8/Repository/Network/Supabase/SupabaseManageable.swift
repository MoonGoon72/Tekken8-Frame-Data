//
//  SupabaseManageable.swift
//  Tekken8 Frame Data
//
//  Created by 문영균 on 3/11/25.
//

import Foundation

protocol MoveVideoPlaybackURLDataSource {
    func fetchMoveVideoPlaybackURL(objectKey: String) async throws -> URL
}

enum MoveVideoPlaybackURLDataSourceError: Error {
    case unavailable
}

extension MoveVideoPlaybackURLDataSource {
    func fetchMoveVideoPlaybackURL(objectKey: String) async throws -> URL {
        throw MoveVideoPlaybackURLDataSourceError.unavailable
    }
}

protocol MoveVideoRemoteDataSource {
    func fetchMoveVideos(characterName: String) async throws -> [MoveVideoRemoteRecord]
}

struct MoveVideoRemoteRecord: Decodable, Sendable {
    struct MoveReference: Decodable, Sendable {
        let id: Int64
    }

    let characterName: String
    let moveKey: String
    let objectKey: String
    let videoRevision: String?
    let enabled: Bool
    let move: MoveReference?

    enum CodingKeys: String, CodingKey {
        case characterName = "character_name"
        case moveKey = "move_key"
        case objectKey = "object_key"
        case videoRevision = "video_revision"
        case enabled
        case move
    }
}

protocol SupabaseManageable: MoveVideoRemoteDataSource, MoveVideoPlaybackURLDataSource {
    func fetchCharacter() async throws -> [Character]
    func fetchMoves(characterName name: String) async throws -> [Move]
    func fetchFrameDataVersion() async throws -> Int
    func fetchTekkenVersion() async throws -> String
}
