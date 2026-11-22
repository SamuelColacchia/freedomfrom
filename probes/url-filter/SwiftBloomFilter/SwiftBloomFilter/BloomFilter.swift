/*
See the LICENSE.txt file for this sample’s licensing information.

Abstract:
A Swift implementation of a Bloom filter.
*/

import Foundation

public enum BloomFilterError: Error {
	case invalidParameters(message: String?)
	case encodingIssue(message: String?)
}

public struct BloomFilter {

	public let itemCount: Int
	public let falsePositiveTolerance: Double
	public let murmurSeed: UInt32
	public let bitCount: UInt32
	public let byteCount: Int
	public let hashCount: UInt32
	public var data: Data? {
		Data(bits)
	}
	private var bits: Data

	public init(items: [String], falsePositiveTolerance: Double = 0.001) throws {
		try self.init(items: items, falsePositiveTolerance: falsePositiveTolerance, murmurSeed: arc4random())
	}

	internal init(items: [String], falsePositiveTolerance: Double = 0.001, murmurSeed: UInt32) throws {
		let itemCount = items.count
		guard itemCount > 0 else {
			throw BloomFilterError.invalidParameters(message: "items must not be empty")
		}
		guard falsePositiveTolerance > 0.0 && falsePositiveTolerance < 1.0 else {
			throw BloomFilterError.invalidParameters(message: "falsePositiveTolerance must be greater than zero and less than one")
		}

		self.itemCount = itemCount
		self.falsePositiveTolerance = falsePositiveTolerance
		self.murmurSeed = murmurSeed

		bitCount = Self.calculateBitCount(itemCount: itemCount, falsePositiveTolerance: falsePositiveTolerance)
		hashCount = Self.calculateHashCount(itemCount: itemCount, bitCount: bitCount)

		// Create the bit field of an appropriate size.
		byteCount = Self.calculateByteCount(bitCount: bitCount)
		bits = Data(count: byteCount)

		// Create the filter by inserting the given items.
		for item in items {
			try insert(value: item)
		}
	}

	internal static func calculateBitCount(itemCount: Int, falsePositiveTolerance: Double) -> UInt32 {
		let itemCountD = Double(itemCount)
		return UInt32((ceil(-(itemCountD * log(falsePositiveTolerance) / pow(M_LN2, 2.0)))))
	}

	internal static func calculateHashCount(itemCount: Int, bitCount: UInt32) -> UInt32 {
		let itemCountD = Double(itemCount)
		let bitCountD = Double(bitCount)
		return UInt32(ceil((bitCountD / itemCountD) * M_LN2))
	}

	internal static func calculateByteCount(bitCount: UInt32) -> Int {
		return Int((bitCount + 7) / 8)
	}

	internal mutating func insert(value: String) throws {
		guard let data = value.data(using: .utf8) else {
			throw BloomFilterError.encodingIssue(message: "Unable to encode string '\(value)' to UTF8")
		}

		for count in 0..<hashCount {
			let fnv = data.fnvHash()
			let murmur = data.murmurHash3(seed: murmurSeed)
			let index = Int((fnv &+ count &* murmur) % bitCount)
			bits.setBit(at: index, to: true)
		}
	}
}

extension BloomFilter: Codable, Hashable {

	enum CodingKeys: String, CodingKey {
		case itemCount
		case falsePositiveTolerance
		case murmurSeed
		case bitCount
		case byteCount
		case hashCount
		case bits = "data"
	}
}

extension BloomFilter: CustomStringConvertible {

	public var description: String {
		return "<BloomFilter itemCount: \(itemCount), falsePositiveTolerance: \(falsePositiveTolerance), murmurSeed: \(murmurSeed), bitCount: \(bitCount), byteCount: \(byteCount), hashCount: \(hashCount) data bytes: \(bits.count) >"
	}
}

extension Data {

	public mutating func setBit(at index: Int, to value: Bool) {
		let byteIndex = index / 8
		guard byteIndex >= self.startIndex && byteIndex < self.endIndex else {
			return
		}

		let bitPosition = index % 8

		if value {
			self[byteIndex] |= (1 << bitPosition)  // Set the bit to 1
		} else {
			self[byteIndex] &= ~(1 << bitPosition) // Set the bit to 0
		}
	}

	func bit(at index: Int) -> Bool {
		guard index >= 0 && index < count * 8 else {
			return false
		}

		let byteIndex = index / 8
		let bitIndex = index % 8
		let mask = 1 << bitIndex

		return (self[byteIndex] & UInt8(mask)) != 0
	}

}
