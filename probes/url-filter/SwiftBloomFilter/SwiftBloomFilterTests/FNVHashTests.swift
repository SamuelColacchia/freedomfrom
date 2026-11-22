/*
See the LICENSE.txt file for this sample’s licensing information.

Abstract:
Tests for the FNV Hash implementation.
*/

import Testing
@testable import SwiftBloomFilter
import Foundation

@Suite("FNV Hash")
struct FNVHashTests {

	// Test FNV Hash for String input.
	@Test(arguments: [
		("", 0x811c9dc5), ("a", 0xe40c292c),
		("test", 0xafd071e5),
		("foobar", 0xbf9cf968),
		("Hello, world!", 0xed90f094),
		("The quick brown fox jumps over the lazy dog", 0x048fff90)
	])
	func fnvHash100(_ test: (in: String, expect: UInt32)) async throws {
		let data = test.in.data(using: .utf8)!
		let expectedHashValue = test.expect
		let hashValue = data.fnvHash()
		#expect(hashValue == expectedHashValue, "For input '\(test.in)'")
	}

	// Test the `char * hello = "Hello!\x01\xFF\xED"` test case.
	@Test("Hello!\\x01\\xFF\\xED")
	func fnvHash110() async throws {
		let validUTF8: [UInt8] = [0x01, 0xFF, 0xED]
		var data = "Hello!".data(using: .utf8)!
		data.append(Data(validUTF8))
		let expectedHashValue = UInt32(0xfd9d3881)
		let hashValue = data.fnvHash()
		#expect(hashValue == expectedHashValue)
	}

}
