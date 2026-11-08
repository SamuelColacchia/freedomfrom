/*
See the LICENSE.txt file for this sample’s licensing information.

Abstract:
A Swift implementation of the FNV1a hashing algorithm.
*/

// See https://www.ietf.org/archive/id/draft-eastlake-fnv-22.html for more information on this algorithm.

import Foundation

extension Data {

	public func fnvHash() -> UInt32 {
		var fnvHash: UInt32 = 0x811c9dc5 // Initialize with the 32-bit offset basis.
		let fnvPrime: UInt32 = 0x01000193 // 2**24 + 2**8 + 0x93

		for byte in self {
			fnvHash = fnvPrime &* (fnvHash ^ UInt32(byte))
		}

		return fnvHash
	}

}
