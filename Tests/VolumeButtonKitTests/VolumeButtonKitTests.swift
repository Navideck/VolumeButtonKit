import Testing
@testable import VolumeButtonKit

@Test func releaseWindowBridgesInitialButtonRepeatDelay() {
    #expect(VolumeButtonListener.releaseInactivityInterval >= 0.7)
}
