//
//  APIRequest.swift
//  Tekken8 Frame Data
//
//  Created by 문영균 on 2/20/25.
//

import Foundation

protocol APIRequest {
    var baseURL: String { get }
    var path: String { get }
    var method: HTTPMethod { get }
    var headers: [String: String]? { get }
    var queryParameters: [String: String]? { get }
}
