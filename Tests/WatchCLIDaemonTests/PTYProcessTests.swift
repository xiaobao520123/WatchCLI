import XCTest
@testable import WatchCLIDaemon

final class PTYProcessTests: XCTestCase {

    /// Spawn `/bin/cat`, write a line, expect it echoed back through the PTY,
    /// then close stdin and expect a clean exit.
    func testPTYEchoesInputAndExits() async throws {
        let pty = try PTYProcess.spawn(executable: "/bin/cat", arguments: [], cols: 40, rows: 10)

        let collector = ByteCollector()
        let readTask = Task {
            for await chunk in pty.read() {
                await collector.append(chunk)
            }
        }
        defer { readTask.cancel() }

        try pty.write(Data("hello world\n".utf8))

        // Wait for the echoed line, with a timeout.
        let deadline = ContinuousClock.now.advanced(by: .seconds(2))
        while ContinuousClock.now < deadline {
            try await Task.sleep(for: .milliseconds(50))
            if await collector.contains("hello world") { break }
        }
        let snapshot = await collector.string
        XCTAssertTrue(snapshot.contains("hello world"),
                      "expected echoed line, got: \(snapshot)")

        // EOT to make `cat` exit cleanly.
        try pty.write(Data([0x04]))
        let code = await pty.waitForExit()
        XCTAssertEqual(code, 0, "expected clean exit, got \(code)")
    }

    func testPTYResizeDoesNotCrash() async throws {
        let pty = try PTYProcess.spawn(executable: "/bin/cat", arguments: [], cols: 40, rows: 10)
        pty.resize(cols: 100, rows: 30)
        XCTAssertGreaterThan(pty.pid, 0)
        pty.signal(SIGKILL)
        _ = await pty.waitForExit()
    }

    func testSignalKillsChild() async throws {
        let pty = try PTYProcess.spawn(executable: "/bin/sleep", arguments: ["30"], cols: 40, rows: 10)
        try await Task.sleep(for: .milliseconds(100))
        let killResult = kill(pty.pid, SIGKILL)
        let killErrno = errno
        XCTAssertEqual(killResult, 0, "kill returned \(killResult), errno=\(killErrno)")
        let code = await pty.waitForExit()
        XCTAssertNotEqual(code, 0, "expected non-zero exit after SIGKILL, got \(code)")
    }
}

actor ByteCollector {
    private var buffer = Data()
    func append(_ d: Data) { buffer.append(d) }
    var string: String { String(decoding: buffer, as: UTF8.self) }
    func contains(_ s: String) -> Bool { string.contains(s) }
}
