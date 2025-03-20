//
//  NetworkService.swift
//  Tekken8 Frame Data
//
//  Created by 문영균 on 2/20/25.
//

import Foundation

protocol NetworkService {
    func request<T: Decodable>(_ endpoint: APIRequest) async throws -> T
}
