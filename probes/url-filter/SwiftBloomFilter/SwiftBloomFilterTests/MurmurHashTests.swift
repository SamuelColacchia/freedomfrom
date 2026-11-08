/*
See the LICENSE.txt file for this sample’s licensing information.

Abstract:
Tests for the Murmur Hash implementation.
*/

import Testing
@testable import SwiftBloomFilter
import Foundation

@Suite("Murmur Hash")
struct MurmurHashTests {

	@Test(arguments: [
		("", 0x00000000, 0x00000000),
		("", 0x00000001, 0x514E28B7),
		("", 0xffffffff, 0x81F16F39),
		("test", 0x00000000, 0xba6bd213),
		("test", 0x9747b28c, 0x704b81dc),
		("foobar", 0x00000000, 0xa4c4d4bd),
		("Hello, world!", 0x00000000, 0xc0363e43),
		("Hello, world!", 0x9747b28c, 0x24884CBA),
		("The quick brown fox jumps over the lazy dog", 0x00000000, 0x2e4ff723),
		("The quick brown fox jumps over the lazy dog", 0x9747b28c, 0x2FA826CD)
	])
	func murmurHash100(_ test: (in: String, seed: UInt32, expect: UInt32)) async throws {
		let data = test.in.data(using: .utf8)!
		let hashValue = data.murmurHash3(seed: test.seed)
		let expectedHashValue = test.expect
		#expect(hashValue == expectedHashValue, "For input '\(test.in)'")
	}
}
