/*
See the LICENSE.txt file for this sample’s licensing information.

Abstract:
An extension to the bundle type that adds a method for finding the first app extension configured as a URL filter control.
*/

import Foundation

extension Bundle {
    
    // Traverse the main bundle to identify the bundle ID of the first encountered bundle representing a EXAppExtension configured as a `url-filter-control`.
    // The NEURLFilterManager needs this bundle identifier as part of the configuration used to identify the app extension providing the `NEURLFilterControlProvider` implementation.
    static func findURLFilterControlNetworkExtensionBundleID() -> String? {
        /* Look for a bundle whose information property list contains the `com.apple.networkextension.url-filter-control`
           value for the `EXExtensionPointIdentifier` key inside the `EXAppExtensionAttributes` dictionary.

           <key>EXAppExtensionAttributes</key>
               <dict>
               <key>EXExtensionPointIdentifier</key>
                   <string>com.apple.networkextension.url-filter-control</string>
               </dict>
         */

        let enumerator = FileManager.default.enumerator(at: Bundle.main.bundleURL, includingPropertiesForKeys: [.nameKey])
        while let url = enumerator?.nextObject() as? URL {
            let name = (try? url.resourceValues(forKeys: [.nameKey]))?.name ?? ""
            if name.hasSuffix(".appex") {
                guard let bundle = Bundle(url: url),
                      let appExtAttrDict = bundle.infoDictionary?["EXAppExtensionAttributes"] as? [String: Any],
                      let extensionPointIdentifier = appExtAttrDict["EXExtensionPointIdentifier"] as? String,
                      extensionPointIdentifier == "com.apple.networkextension.url-filter-control" else {
                    continue
                }
                return bundle.bundleIdentifier
            }
        }
        return nil
    }
}
