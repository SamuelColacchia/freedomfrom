/*
See the LICENSE.txt file for this sample’s licensing information.

Abstract:
Tests for the Bloom filter implementation.
*/

import Testing
@testable import SwiftBloomFilter
import Foundation

struct SwiftBloomFilterTests {

	@Suite("Bloom Filter Internals")
	struct BloomFilterInternalsTests {
		@Test func bitCount100() {
			let itemCount = 10
			let falsePositiveTolerance = 0.001
			let count = BloomFilter.calculateBitCount(itemCount: itemCount, falsePositiveTolerance: falsePositiveTolerance)
			#expect(count == 144)
		}

		@Test func hashCount100() {
			let itemCount = 10
			let bitCount: UInt32 = 144
			let count = BloomFilter.calculateHashCount(itemCount: itemCount, bitCount: bitCount)
			#expect(count == 10)
		}

		@Test func byteCount100() {
			let bitCount: UInt32 = 144
			let count = BloomFilter.calculateByteCount(bitCount: bitCount)
			#expect(count == 18)
		}

		@Test func filter100() async throws {
			// Create a bloom filter with known data and a known seed.
			let items = [
				"example.com",
				"example2.com",
				"example3.com",
				"example4.com",
				"example5.com",
				"example6.com",
				"example7.com",
				"example8.com",
				"example9.com",
				"example10.com/resource?query=bugs"
			]
			let filter = try BloomFilter(items: items, murmurSeed: 1_267_652_889)
			// Ensure metadata is as expected.
			#expect(filter.bitCount == 144)
			#expect(filter.byteCount == 18)
			#expect(filter.hashCount == 10)
			#expect(filter.murmurSeed == 1_267_652_889)

			// Ensure the actual bloom data is as expected.
			let data = try #require(filter.data)
			#expect(!data.isEmpty)
			#expect(data.count == 18)
			let expected = "JGguOvZzlBEHYkUWJC5vw/eH"
			let expectedData = Data(base64Encoded: expected)
			#expect(data == expectedData)

			// Encode the filter to an information property list, as this is the use case for the SimpleURLFilter.
			let encoder = PropertyListEncoder()
			encoder.outputFormat = .xml
			let encoded = try encoder.encode(filter)
			let plist = try #require(String(data: encoded, encoding: .utf8))

			// Use a regular expression to extract the bloom filter data string.
			let regex = #/<key>data</key>\s*?<data>\s*?(\S+)\s*?</data>/#
			let match = try #require(plist.firstMatch(of: regex))
			// Ensure the encoded value matches the expected base64 encoded string.
			#expect(match.1 == expected)
		}
	}

	@Suite("Bits")
	struct BitTests {

		// Test setting of all individual bits in four bytes.
		@Test(arguments: 0..<32)
		func setBit100(bit: Int) throws {
			var data = Data(count: 4)
			data.setBit(at: bit, to: true)
			let byteIndex = bit / 8
			let int: UInt8 = data[byteIndex]
			let bitIndex = bit - (byteIndex * 8)
			#expect(int == UInt8(pow(Double(2), Double(bitIndex))))
		}

		@Test("Set Random Bit Combinations")
		func testSetRandomBitCombinations() throws {
			let dataSize = 4 // Bytes
			let totalBits = dataSize * 8
			let totalCombinations = Int(pow(2.0, Double(totalBits)))
			let numberOfRandomSamples = 1000 // Adjust this value to control the number of random tests.

			for _ in 0..<numberOfRandomSamples {
				// Generate a random combination.
				let randomCombination = Int.random(in: 0..<totalCombinations)

				var data = Data(count: dataSize) // Start with all bits set to 0.
				var expectedData = Data(count: dataSize)

				// Set the bits based on the current combination.
				for bitIndex in 0..<totalBits {
					let bitIsSet = (randomCombination >> bitIndex) & 1 == 1
					expectedData.setBit(at: bitIndex, to: bitIsSet)
					data.setBit(at: bitIndex, to: bitIsSet)
				}

				// Verify that the data matches the expected data.
				#expect(data == expectedData, "Failed for combination: \(randomCombination)")

				// Verify individual bits.
				for bitIndex in 0..<totalBits {
					let expectedBitValue = (randomCombination >> bitIndex) & 1 == 1
					#expect(data.bit(at: bitIndex) == expectedBitValue, "Failed bit check for combination: \(randomCombination), bit: \(bitIndex)")
				}
			}
		}

		// CAUTION: This exhaustively tests every bit combination in a 32-bit set and can take a long time to execute (10s of hours)
		/*
		@Test("Set All Bit Combinations")
		func testSetAllBitCombinations() throws {
			let dataSize = 4 // Bytes
			let totalBits = dataSize * 8
			let totalCombinations = Int(pow(2.0, Double(totalBits)))

			for indx in 0..<totalCombinations {
				var data = Data(count: dataSize) // Start with all bits set to 0
				var expectedData = Data(count: dataSize)

				// Set the bits based on the current combination
				for bitIndex in 0..<totalBits {
					let bitIsSet = (indx >> bitIndex) & 1 == 1
					expectedData.setBit(at: bitIndex, to: bitIsSet)
					data.setBit(at: bitIndex, to: bitIsSet)

				}

				// Verify that the data matches the expected data
				#expect(data == expectedData, "Failed for combination: \(indx)")

				// Verify individual bits
				for bitIndex in 0..<totalBits {
					let expectedBitValue = (indx >> bitIndex) & 1 == 1
					#expect(data.bit(at: bitIndex) == expectedBitValue, "Failed bit check for combination: \(indx), bit: \(bitIndex)")
				}
			}
		}
		*/

	}
}
