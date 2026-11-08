/*
See the LICENSE.txt file for this sample’s licensing information.

Abstract:
A representation of the various transitory states of activities performed by the app.
*/

import Foundation

public enum ActivityState {
    case idle
    case configurationLoadStart, configurationLoadEnd, configurationLoadEmpty, configurationLoadFailed
    case configurationSaveStart, configurationSaveEnd, configurationSaveFailed
    case configurationRemoveStart, configurationRemoveEnd, configurationRemoveFailed
    case configurationEnableStart, configurationEnableEnd, configurationEnableFailed
    case configurationDisableStart, configurationDisableEnd, configurationDisableFailed
    case pirCacheResetStart, pirCacheResetEnd, pirCacheResetFailed
    case pirParametersRefreshStart, pirParametersRefreshEnd, pirParametersRefreshFailed
}
