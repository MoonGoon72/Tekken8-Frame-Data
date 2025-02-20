//
//  DefaultNetworkService.swift
//  Tekken8 Frame Data
//
//  Created by 문영균 on 2/20/25.
//

import Foundation

final class DefaultNetworkService: NetworkService {
    func request<T>(_ endpoint: any APIRequest) async throws -> T where T : Decodable {
        guard var urlComponents = URLComponents(string: endpoint.baseURL + endpoint.path) else {
            throw NetworkError.invalidURL
        }
        
        if let queryParameters = endpoint.queryParameters {
            urlComponents.queryItems = queryParameters.map { URLQueryItem(name: $0, value: $1) }
        }
        
        guard let url = urlComponents.url else { throw NetworkError.invalidURL }
        
        var request = URLRequest(url: url)
        request.httpMethod = endpoint.method.rawValue
        endpoint.headers?.forEach { request.setValue($1, forHTTPHeaderField: $0) }
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResopnse = response as? HTTPURLResponse, (200...299).contains(httpResopnse.statusCode) else {
            throw NetworkError.invalidResource
        }
        
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw NetworkError.decodingError(error: error)
        }
    }
}
