//
//  VersionManageable.swift
//  TK8
//
//  Created by 문영균 on 5/4/25.
//

protocol VersionManageable {
    func checkFrameDataVersion() async throws
    func checkTekkenVersion() async throws
}
