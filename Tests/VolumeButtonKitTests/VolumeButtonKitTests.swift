import Testing
@testable import VolumeButtonKit

@Test func separatesDoublePressesFromHeldButtonRepeats() {
    #expect(!VolumeButtonListener.shouldReleasePendingPress(elapsed: 0.18))
    #expect(VolumeButtonListener.shouldReleasePendingPress(elapsed: 0.181))
}
