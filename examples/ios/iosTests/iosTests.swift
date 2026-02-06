//
//  iosTests.swift
//  iosTests
//
//  Created by Andrea Bueide on 1/29/26.
//

import XCTest
@testable import ios

final class iosTests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testMathOperations() throws {
        // Test basic math operations
        XCTAssertEqual(2 + 2, 4)
        XCTAssertEqual(10 / 2, 5)
        XCTAssertEqual(5 * 2, 10)
    }

    func testStringOperations() throws {
        // Test string operations
        let hello = "Hello"
        let world = "World"
        XCTAssertEqual("\(hello) \(world)", "Hello World")
        XCTAssertTrue(hello.starts(with: "H"))
    }

    func testArrayOperations() throws {
        // Test array operations
        var numbers = [1, 2, 3, 4, 5]
        numbers.append(6)
        XCTAssertEqual(numbers.count, 6)
        XCTAssertEqual(numbers.last, 6)
        XCTAssertEqual(numbers.first, 1)
    }

    func testContentViewExists() throws {
        // Test that ContentView can be instantiated
        let view = ContentView()
        XCTAssertNotNil(view)
    }

    func testPerformanceExample() throws {
        // This is an example of a performance test case.
        self.measure {
            // Put the code you want to measure the time of here.
            let _ = (0..<1000).map { $0 * 2 }
        }
    }

}
