//
//  ReuseIdentifiable.swift
//  Tekken8 Frame Data
//
//  Created by 문영균 on 3/28/25.
//

import Foundation

protocol ReuseIdentifiable {
    static var reuseIdentifier: String { get }
}

extension ReuseIdentifiable {
    static var reuseIdentifier: String {
        String(describing: self)
    }
}

