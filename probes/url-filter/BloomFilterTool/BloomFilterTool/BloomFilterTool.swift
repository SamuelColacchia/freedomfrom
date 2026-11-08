/*
See the LICENSE.txt file for this sample’s licensing information.

Abstract:
A command-line interface implementation providing the means to generate bloom filter data,
 and associated metadata, as well as a Protobuf file suitable to use to confiugre a PIR server instance.
*/

import Foundation
import ArgumentParser
import SwiftBloomFilter
import SwiftProtobuf

internal struct BloomFilterToolDefaults {
	static let falsePositiveTolerance: Double = 0.001
	static let filterOutputFileName = "bloom_filter.plist"
	static let pirDataOutputFileName = "input.txtpb"
}

@main
struct BloomFilterTool: AsyncParsableCommand {
	static let configuration = CommandConfiguration(
		abstract: "Create a bloom filter, and PIR server data file, from a list of URLs.",
		discussion: """
			Given an input file containing one string (URL) per line, this tool will generate a plist containing the resulting bloom filter data, and associated metadata, as well as a txtpb protobuf file suitable to use to confiugre a PIR server instance (see https://github.com/apple/pir-service-example).
			
			By default the bloom filter file will be output to the working directory as '\(BloomFilterToolDefaults.filterOutputFileName)', and the PIR server configuration file will be output to the working directory as '\(BloomFilterToolDefaults.pirDataOutputFileName)'.
			If desired, the false positive tolerance percentage can be changed from the default of \(BloomFilterToolDefaults.falsePositiveTolerance).
			
			Please note that lines of the input file are not validated as URLs (though empty lines are skipped), and the given URLs must adhere to the ASCII character subset used for Internet hostnames (any needed puny-code conversions must have already been made).
			"""
	)

	@Argument(help: "Input file containing URLs (one per line).", transform: URL.init(fileURLWithPath:))
	var inputFile: URL

	@Option(name: [.customShort("f"), .long],
			help: "The bloom filter data output file. (default: '\(BloomFilterToolDefaults.filterOutputFileName)')",
			transform: URL.init(fileURLWithPath:))
	var filterOutputFile: URL?

	@Option(name: [.customShort("d"), .long],
			help: "The PIR server data output file. (default: '\(BloomFilterToolDefaults.pirDataOutputFileName)')",
			transform: URL.init(fileURLWithPath:))
	var pirDataOutputFile: URL?

	@Option(name: [.customShort("t"), .long], help: "The tolerance for false positives, as a percentage (> 0 & < 1).")
	var falsePositiveTolerance: Double = BloomFilterToolDefaults.falsePositiveTolerance

	@Flag(name: .shortAndLong, help: "Output status information during execution.")
	var verbose = false

	mutating func run() async throws {

		// Handle options.
		if filterOutputFile == nil {
			filterOutputFile = URL.currentDirectory().appending(path: BloomFilterToolDefaults.filterOutputFileName)
		}
		guard let filterOutputFile else {
			throw RuntimeError("Unable to determine bloom filter file output location.")
		}

		if pirDataOutputFile == nil {
			pirDataOutputFile = URL.currentDirectory().appending(path: BloomFilterToolDefaults.pirDataOutputFileName)
		}
		guard let pirDataOutputFile else {
			throw RuntimeError("Unable to determine PIR server data file output location.")
		}

		if verbose {
			print("Input file: '\(inputFile.path(percentEncoded: false))'")
			print("Bloom filter output file: '\(filterOutputFile.path(percentEncoded: false))'")
			print("PIR server data output file: '\(pirDataOutputFile.path(percentEncoded: false))'")
			print("False positive tolerance: \(falsePositiveTolerance)")
		}

		// Read in the input file, storing nonempty lines to an array.
		var input = [String]()
		var pirElements = [Apple_SwiftHomomorphicEncryption_Pir_V1_KeywordDatabaseRow]()
		do {
			try await readTo(input: &input, pirElements: &pirElements)
		} catch {
			throw RuntimeError("Couldn't read from '\(inputFile)'.", error: error)
		}

		// Create the Bloom filter.
		do {
			try createBloomFilterFile(input: input, outputFile: filterOutputFile)
		} catch {
			throw RuntimeError("Unable to create bloom filter.", error: error)
		}

		// Create the PIR data file.
		do {
			try createPIRDataFile(elements: pirElements, outputFile: pirDataOutputFile)
		} catch {
			throw RuntimeError("Unable to create PIR data file.", error: error)
		}
	}

	func readTo(input: inout [String], pirElements: inout [Apple_SwiftHomomorphicEncryption_Pir_V1_KeywordDatabaseRow]) async throws {
		let fileHandle = try FileHandle(forReadingFrom: inputFile)
		var lineCount = 0
		// Note: Reading the file in this way automatically skips empty lines.
		let lines = try await fileHandle.bytes.lines.reduce(into: [String]()) {

			// Strip whitespace from the line.
			// Empty lines are skipped already, but ensure no additional whitespace is included.
			let line = $1.trimmingCharacters(in: .whitespacesAndNewlines)

			// Append the line to the input array.
			$0.append(line)
			lineCount += 1

			// Create a PIR data element for the line.
			var element = Apple_SwiftHomomorphicEncryption_Pir_V1_KeywordDatabaseRow()
			if let keyword = line.data(using: .utf8), let value = "1".data(using: .utf8) {
				element.keyword = keyword
				element.value = value
				pirElements.append(element)
			} else {
				if verbose {
					print("Skipping PIR data element '\($1)' due to invalid UTF-8 encoding.")
				}
			}
		}

		input.append(contentsOf: lines)

		if verbose {
			print("Read \(lineCount) line\(lineCount == 1 ? "" : "s") from '\(inputFile.path(percentEncoded: false))'")
		}
	}

	func createBloomFilterFile(input: [String], outputFile: URL) throws {
		let clock = ContinuousClock()
		var filter: BloomFilter?
		let elapsed = try clock.measure {
			filter = try BloomFilter(items: input, falsePositiveTolerance: falsePositiveTolerance)
		}
		if verbose {
			print("Created bloom filter in \(elapsed).")
		}
		guard let filter else {
			throw RuntimeError("Unable to create bloom filter")
		}
		let encoder = PropertyListEncoder()
		encoder.outputFormat = .xml
		let encoded = try encoder.encode(filter)
		try encoded.write(to: outputFile, options: [.atomic])
		if verbose {
			print("Bloom filter written to '\(outputFile.path(percentEncoded: false))'")
		}
	}

	func createPIRDataFile(elements: [Apple_SwiftHomomorphicEncryption_Pir_V1_KeywordDatabaseRow], outputFile: URL) throws {
		var pirData = Apple_SwiftHomomorphicEncryption_Pir_V1_KeywordDatabase()
		pirData.rows = elements
		guard let encoded = pirData.textFormatString().data(using: .utf8) else {
			throw RuntimeError("Unable to create PIR data file.")
		}
		try encoded.write(to: outputFile, options: [.atomic])
		if verbose {
			print("PIR server data written to '\(outputFile.path(percentEncoded: false))'")
		}
	}
}

struct RuntimeError: Error, CustomStringConvertible {
	var description: String

	init(_ description: String, error: Error? = nil) {
		self.description = "\(description)\n\tError: \(String(describing: error))"
	}
}
