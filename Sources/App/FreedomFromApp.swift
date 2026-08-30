import FreedomFromKit
import FreedomFromPlatform
import SwiftUI

/// The walking skeleton's host app.
///
/// This is work item 2 of the build spec: the real three targets with their
/// real bundle identifiers and entitlements, doing nothing but authorizing,
/// picking, storing, shielding, and letting the extensions read. The targets,
/// the entitlements, and the record codec are kept; this screen is not — the
/// seven real screens replace it at work item 5.
@main
struct FreedomFromApp: App {
    @State private var model = SkeletonModel()

    var body: some Scene {
        WindowGroup {
            SkeletonView(model: model)
                .task { await model.onLaunch() }
        }
    }
}
