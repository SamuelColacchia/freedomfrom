/*
See the LICENSE.txt file for this sample’s licensing information.

Abstract:
A Swift implementation of the Murmur3A 32-bit hashing algorithm.
*/

// For more information, see:
// * https://en.wikipedia.org/wiki/MurmurHash
// * https://github.com/aappleby/smhasher/blob/master/src/MurmurHash3.cpp

import Foundation

extension Data {

	public func murmurHash3(seed: UInt32) -> UInt32 {
		let length = self.count
		var hash1 = seed
		let const1: UInt32 = 0xcc9e2d51
		let const2: UInt32 = 0x1b873593

		let nblocks = length / 4

		// Handle body.
		for index in 0..<nblocks {
			var block: UInt32 = self.block(at: index)

			// Hash the block.
			block &*= const1
			block = block.rotateLeft(15)
			block &*= const2

			hash1 ^= block
			hash1 = hash1.rotateLeft(13)
			hash1 = hash1 &* 5 &+ 0xe6546b64
		}

		// Handle remaining bytes.
		var block: UInt32 = 0
		let blockedLength = length / 4 * 4
		let remainingLength = length - blockedLength
		switch remainingLength {
		case 3:
			block ^= UInt32(self[blockedLength + 2]) << 16
			fallthrough
		case 2:
			block ^= UInt32(self[blockedLength + 1]) << 8
			fallthrough
		case 1:
			block ^= UInt32(self[blockedLength])
			block &*= const1
			block = block.rotateLeft(15)
			block &*= const2
			hash1 ^= block
		default:
			break
		}

		// Perform finalization.
		hash1 ^= UInt32(length)
		hash1 = hash1.fmix()
		return hash1
	}

	func block<T: FixedWidthInteger>(at index: Int) -> T {
		var block: T = 0

		for byteIndex in 0..<MemoryLayout<T>.size {
			block |= T(self[index * MemoryLayout<T>.size + byteIndex]) << (byteIndex * 8)
		}

		return block
	}
}

extension UInt32 {

	func rotateLeft(_ bitCount: UInt32) -> UInt32 {
		guard bitCount <= 32 else {
			return self
		}
		return (self << bitCount) | (self >> (32 - bitCount))
	}

	func fmix() -> UInt32 {
		var hash = UInt32(self)
		hash ^= hash >> 16
		hash &*= 0x85ebca6b
		hash ^= hash >> 13
		hash &*= 0xc2b2ae35
		hash ^= hash >> 16
		return hash
	}
}
