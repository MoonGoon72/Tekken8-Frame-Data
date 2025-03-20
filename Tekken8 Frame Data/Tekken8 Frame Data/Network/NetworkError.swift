//
//  NetworkError.swift
//  Tekken8 Frame Data
//
//  Created by 문영균 on 2/20/25.
//

import Foundation

enum NetworkError: LocalizedError {
    case invalidURL
    case invalidResource
    case decodingError(error: Error)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            "올바르지 않은 URL 입니다."
        case .invalidResource:
            "요청이 정상적으로 처리되지 않았습니다."
        case .decodingError(let error):
            "디코딩이 실패하였습니다. 에러: \(error.localizedDescription)"
        }
    }
}
