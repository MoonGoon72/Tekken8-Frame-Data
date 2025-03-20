//
//  SupabaseAPITests.swift
//  SupabaseAPITests
//
//  Created by 문영균 on 3/20/25.
//

import XCTest

final class SupabaseAPITests: XCTestCase {
    private var supabaseManager: SupabaseManageable?
    
    override func setUp() {
        super.setUp()
        
        supabaseManager = SupabaseManager()
    }
    
    func test_SUPABASE_프레임데이터_패치가_잘_되는지() async throws {
        // given
        
        // when
        let responseData = try await supabaseManager?.fetchFrame()
        let frameData = try XCTUnwrap(responseData)
        
        // then
        XCTAssertNotNil(frameData)
    }
}
