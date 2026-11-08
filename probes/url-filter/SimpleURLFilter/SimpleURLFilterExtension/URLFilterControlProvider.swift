/*
See the LICENSE.txt file for this sample’s licensing information.

Abstract:
The implementation of the filter control provider protocol, to provide prefilter data to the system and handle start/stop events.
*/

import NetworkExtension
import OSLog
import SwiftBloomFilter

enum ProviderFilterError: Error {
    case loadError(message: String?)
}

@main
class URLFilterControlProvider {

    let filterPlistFileName = "bloom_filter"
    var filter: BloomFilter?

    private let log = Logger.createLogger(for: URLFilterControlProvider.self)

    required init() {
    }

    func loadBloomFilter() throws {
        guard let filterFile = Bundle.main.url(forResource: filterPlistFileName, withExtension: "plist") else {
            throw ProviderFilterError.loadError(message: "Plist file '\(self.filterPlistFileName).plist' not found in the bundle.")
        }

        let data = try Data(contentsOf: filterFile)
        let decoder = PropertyListDecoder()
        filter = try decoder.decode(BloomFilter.self, from: data)
    }

    func filterTag() -> String? {
        guard let filter else {
            return nil
        }
        return filter.hashValue.description
    }

}

extension URLFilterControlProvider: NEURLFilterControlProvider {
    func start() async throws {
        log.log("URLFilterControlProvider - start")
    }

    func stop(reason: NEProviderStopReason) async throws {
        log.log("URLFilterControlProvider - stop: \(reason.description)")
    }

    // This gets called by the framework to get the bloom filter to use as a prefilter.
    // It can be called multiple times by the framework, and can be supplied with a tag for the existing prefilter.
    // Should the tag indicate the prefilter data is unchanged, return `nil`.
    // This is intended to save a potentially expensive fetch of the prefilter data.
    // Throwing an error here conveys the error to the system, and fail the installation of the filter.
    func fetchPrefilter(existingPrefilterTag: String?) async throws -> NEURLFilterPrefilter? {
        log.log("URLFilterControlProvider - fetchPrefilterWithTag: \(existingPrefilterTag ?? "(nil)")")

        // Guard against recreating and returning the same filter as before.
        guard existingPrefilterTag == nil || existingPrefilterTag != filterTag() else {
            log.debug("Prefilter unchanged since last fetch. (tag: '\(existingPrefilterTag ?? "")')")
            return nil
        }

        // Load the bloom filter if needed.
        if filter == nil {
            do {
                try loadBloomFilter()
            } catch {
                log.error("Unable load bloom filter. Error: \(error)")
                return nil
            }
        }

        guard let filter, let filterData = filter.data, let tag = filterTag() else {
            log.error("Bloom filter unexpectedly nil.")
            return nil
        }

        log.debug("Bloom filter: \(filter.description)")

        // Save the data into a temporary file, rather than pass it in-memory.
        // This is less important for this small sample data, but is the recommended approach to avoid memory pressure issues with larger datasets.
        let tmpdir = FileManager.default.temporaryDirectory
        let fileURL = tmpdir.appendingPathComponent("bloomfilterdata")

        do {
            try filterData.write(to: fileURL)
        } catch {
            log.error("Unable to write bit vector data to temp file '\(fileURL)'. Error: \(error)")
            return nil
        }

        let prefilterData: NEURLFilterPrefilter.PrefilterData = .temporaryFilepath(fileURL)
        let preFilter = NEURLFilterPrefilter(
            data: prefilterData,
            tag: tag,
            bitCount: Int(filter.bitCount),
            hashCount: Int(filter.hashCount),
            murmurSeed: filter.murmurSeed
        )
        log.debug("Fetched prefilter with tag '\(tag)'")
        return preFilter
    }
}

extension NEProviderStopReason {
    var description: String {
        var message: String
        switch self {
        case .none:
            message = "No specific reason."
        case .userInitiated:
            message = "The user stopped the provider."
        case .providerFailed:
            message = "The provider failed."
        case .noNetworkAvailable:
            message = "There is no network connectivity."
        case .unrecoverableNetworkChange:
            message = "The device attached to a new network."
        case .providerDisabled:
            message = "The provider was disabled."
        case .authenticationCanceled:
            message = "The authentication process was cancelled."
        case .configurationFailed:
            message = "The provider could not be configured."
        case .idleTimeout:
            message = "The provider was idle for too long."
        case .configurationDisabled:
            message = "The associated configuration was disabled."
        case .configurationRemoved:
            message = "The associated configuration was deleted."
        case .superceded:
            message = "A high-priority configuration was started."
        case .userLogout:
            message = "The user logged out."
        case .userSwitch:
            message = "The active user changed."
        case .connectionFailed:
            message = "Failed to establish connection."
        case .sleep:
            message = "The device went to sleep and disconnectOnSleep is enabled in the configuration."
        case .appUpdate:
            message = "The NEProvider is being updated."
        case .internalError:
            message = "An internal error occurred in the NetworkExtension framework."
        @unknown default:
            message = "Unknown reason."
        }
        return message
    }
}
