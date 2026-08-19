import Foundation
import XCTest

@testable import super_beacon

final class RunnerTests: XCTestCase {
  func testParsesAndMatchesConfiguredIBeaconRegion() throws {
    let advertisement = try XCTUnwrap(
      IBeaconAdvertisement(data: manufacturerData())
    )
    let matchingRegion = try XCTUnwrap(
      NativeRegion(
        dictionary: [
          "uuid": "00112233-4455-6677-8899-AABBCCDDEEFF",
          "identifier": "office",
          "major": 1,
          "minor": 2,
        ]
      )
    )
    let otherRegion = try XCTUnwrap(
      NativeRegion(
        dictionary: [
          "uuid": "FFFFFFFF-FFFF-FFFF-FFFF-FFFFFFFFFFFF",
          "identifier": "other",
        ]
      )
    )

    XCTAssertEqual(
      advertisement.uuid.uuidString,
      "00112233-4455-6677-8899-AABBCCDDEEFF"
    )
    XCTAssertEqual(advertisement.major, 1)
    XCTAssertEqual(advertisement.minor, 2)
    XCTAssertTrue(matchingRegion.matches(advertisement))
    XCTAssertFalse(otherRegion.matches(advertisement))
  }

  func testRejectsNonIBeaconManufacturerData() {
    let data = Data([0x4C, 0x00, 0x01, 0x02, 0x03])

    XCTAssertNil(IBeaconAdvertisement(data: data))
  }

  private func manufacturerData() -> Data {
    return Data([
      0x4C, 0x00,
      0x02, 0x15,
      0x00, 0x11, 0x22, 0x33,
      0x44, 0x55,
      0x66, 0x77,
      0x88, 0x99,
      0xAA, 0xBB, 0xCC, 0xDD, 0xEE, 0xFF,
      0x00, 0x01,
      0x00, 0x02,
      0xC5,
    ])
  }
}
