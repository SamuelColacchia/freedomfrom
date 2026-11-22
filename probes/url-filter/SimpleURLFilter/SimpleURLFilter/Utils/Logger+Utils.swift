/*
See the LICENSE.txt file for this sample’s licensing information.

Abstract:
An extension to the system logger that provides a logger with a subsystem and category specific to a given type.
*/

import OSLog

extension Logger {
    static func createLogger(for atype: Any.Type) -> Logger {
        let bundle = Bundle.main
        let appName = bundle.infoDictionary?["CFBundleDisplayName"] as? String ?? bundle.infoDictionary?["CFBundleName"] as? String ?? "<unknown>"
        let typeName = String(describing: atype)
        return Logger(subsystem: appName, category: typeName)
    }
}
