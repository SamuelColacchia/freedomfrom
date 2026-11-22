/*
See the LICENSE.txt file for this sample’s licensing information.

Abstract:
A structure containing error details such as a title and message to display in an alert when an error occurs.
*/

import Foundation

struct ErrorDetails: Identifiable {
    let title: String
    let message: String
    let id = UUID()
}
