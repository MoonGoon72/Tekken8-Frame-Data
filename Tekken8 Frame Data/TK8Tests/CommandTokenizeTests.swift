//
//  CommandTokenizeTests.swift
//  TK8Tests
//

import Foundation
import XCTest

final class CommandTokenizeTests: XCTestCase {
    override func setUp() {
        super.setUp()
    }
    
    override func tearDown() {
        super.tearDown()
    }
    
    func test_correct_command_tokenized() {
        // given
        let commands = ["666_ap", "lkrp", "일어나는 도중 lk"]
        let correctParsedCommands = [["6", "6", "6_", "ap"], ["lk", "rp"], ["일어나는 도중", "lk"]]
        // when
        
        // then
        for (i, command) in commands.enumerated() {
            let tokenizedCommand = command.tokenizeCommands()
            XCTAssertEqual(tokenizedCommand, correctParsedCommands[i])
        }
    }
}
