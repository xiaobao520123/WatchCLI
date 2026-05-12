import Foundation
import CWatchCLIPTY

/// A child process attached to a freshly-allocated PTY. Provides an async
/// stream of output bytes plus `write` / `resize` / `signal`. Use
/// `waitForExit()` to learn when the child terminates.
public final class PTYProcess: @unchecked Sendable {
    public let pid: Int32
    public let masterFD: Int32

    private let lock = NSLock()
    private var exited = false
    private var cachedExitCode: Int32?
    private var fdClosed = false

    public static func spawn(
        executable: String,
        arguments: [String],
        environment: [String: String]? = nil,
        cols: UInt16 = 80,
        rows: UInt16 = 24
    ) throws -> PTYProcess {
        let argv: [UnsafeMutablePointer<CChar>?] = ([executable] + arguments).map { strdup($0) }
        defer { for p in argv { free(p) } }
        var argvPtr = argv + [nil]

        let envBuf: [UnsafeMutablePointer<CChar>?]?
        if let environment {
            let strings: [String] = environment.map { "\($0.key)=\($0.value)" }
            envBuf = strings.map { strdup($0) }
        } else {
            envBuf = nil
        }
        defer { envBuf?.forEach { free($0) } }

        var handle = wcli_pty_t(master_fd: -1, pid: -1)
        let result: Int32 = argvPtr.withUnsafeMutableBufferPointer { argvBuf in
            if var envBuf {
                envBuf.append(nil)
                return envBuf.withUnsafeMutableBufferPointer { envPtr in
                    wcli_pty_spawn(executable, argvBuf.baseAddress, envPtr.baseAddress, cols, rows, &handle)
                }
            } else {
                return wcli_pty_spawn(executable, argvBuf.baseAddress, nil, cols, rows, &handle)
            }
        }
        if result != 0 {
            throw POSIXError(.init(rawValue: errno) ?? .EIO)
        }
        // Switch master fd to BLOCKING mode so the dedicated reader thread
        // can call read(2) without spinning.
        let flags = fcntl(handle.master_fd, F_GETFL, 0)
        if flags >= 0 {
            _ = fcntl(handle.master_fd, F_SETFL, flags & ~O_NONBLOCK)
        }
        return PTYProcess(masterFD: handle.master_fd, pid: handle.pid)
    }

    private init(masterFD: Int32, pid: Int32) {
        self.masterFD = masterFD
        self.pid = pid
    }

    deinit {
        closeFD()
        if !exited { kill(pid, SIGKILL) }
    }

    /// Bytes streamed from the PTY master. The stream completes when the
    /// child closes the slave (typically on exit).
    public func read() -> AsyncStream<Data> {
        let fd = masterFD
        return AsyncStream { continuation in
            let thread = Thread { [weak self] in
                var buffer = [UInt8](repeating: 0, count: 4096)
                while true {
                    let n = buffer.withUnsafeMutableBufferPointer { Darwin.read(fd, $0.baseAddress, $0.count) }
                    if n > 0 {
                        continuation.yield(Data(buffer.prefix(n)))
                    } else if n == 0 {
                        break
                    } else {
                        if errno == EINTR { continue }
                        break
                    }
                    if self == nil { break }
                }
                continuation.finish()
            }
            thread.name = "wcli.pty.read.\(pid)"
            thread.start()
            continuation.onTermination = { @Sendable _ in
                // Best-effort: closing the fd elsewhere will unblock the reader.
            }
        }
    }

    public func write(_ data: Data) throws {
        guard !data.isEmpty else { return }
        try data.withUnsafeBytes { (ptr: UnsafeRawBufferPointer) -> Void in
            var remaining = ptr.count
            var base = ptr.baseAddress
            while remaining > 0 {
                let n = Darwin.write(masterFD, base, remaining)
                if n < 0 {
                    if errno == EINTR { continue }
                    throw POSIXError(.init(rawValue: errno) ?? .EIO)
                }
                remaining -= n
                base = base?.advanced(by: n)
            }
        }
    }

    public func resize(cols: UInt16, rows: UInt16) {
        _ = wcli_pty_resize(masterFD, cols, rows)
    }

    public func signal(_ sig: Int32) {
        kill(pid, sig)
    }

    /// Waits for the child to exit. Safe to call concurrently from multiple
    /// callers; they will all observe the same exit code.
    public func waitForExit() async -> Int32 {
        if let cached = lock.withLock({ cachedExitCode }) { return cached }
        return await withCheckedContinuation { (cont: CheckedContinuation<Int32, Never>) in
            DispatchQueue.global(qos: .utility).async { [self] in
                while true {
                    var status: Int32 = 0
                    let r = wcli_pty_try_wait(pid, &status)
                    if r == 1 {
                        lock.withLock {
                            exited = true
                            cachedExitCode = status
                        }
                        // Closing the fd unblocks any reader thread.
                        closeFD()
                        cont.resume(returning: status)
                        return
                    } else if r < 0 {
                        cont.resume(returning: -1)
                        return
                    }
                    Thread.sleep(forTimeInterval: 0.05)
                }
            }
        }
    }

    private func closeFD() {
        lock.withLock {
            if !fdClosed {
                Darwin.close(masterFD)
                fdClosed = true
            }
        }
    }
}

extension NSLock {
    @inlinable
    func withLock<T>(_ body: () throws -> T) rethrows -> T {
        lock(); defer { unlock() }
        return try body()
    }
}
