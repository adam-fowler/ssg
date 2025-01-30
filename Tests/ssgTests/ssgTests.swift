import XCTest

@testable import ssg

final class ssgTests: XCTestCase {
    func testShell() {
        shell("swift", "--version")
        shell("magick")
    }
}
