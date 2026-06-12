import Foundation

/// On-disk bearer token. If the file doesn't exist at the configured path,
/// a fresh 32-byte URL-safe token is generated and persisted with 0600 perms.
public enum TokenStore {
    public static func loadOrCreate(at path: String) throws -> String {
        let url = URL(fileURLWithPath: path)
        if let data = try? Data(contentsOf: url),
           let token = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
           !token.isEmpty {
            return token
        }
        try ensureDirectory(for: url)
        let token = generate()
        try Data(token.utf8).write(to: url, options: .atomic)
        try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: path)
        return token
    }

    static func generate(byteCount: Int = 32) -> String {
        var bytes = [UInt8](repeating: 0, count: byteCount)
        _ = bytes.withUnsafeMutableBytes { SecRandomFillIfAvailable($0) }
        return Data(bytes).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    private static func ensureDirectory(for url: URL) throws {
        let dir = url.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }
}

#if canImport(Security)
import Security
private func SecRandomFillIfAvailable(_ buf: UnsafeMutableRawBufferPointer) -> Int32 {
    SecRandomCopyBytes(kSecRandomDefault, buf.count, buf.baseAddress!)
}
#else
private func SecRandomFillIfAvailable(_ buf: UnsafeMutableRawBufferPointer) -> Int32 {
    let fd = open("/dev/urandom", O_RDONLY)
    defer { close(fd) }
    _ = read(fd, buf.baseAddress, buf.count)
    return 0
}
#endif

/// Constant-time string comparison to avoid token-timing side channels.
public func constantTimeEquals(_ a: String, _ b: String) -> Bool {
    let ab = Array(a.utf8), bb = Array(b.utf8)
    if ab.count != bb.count { return false }
    var diff: UInt8 = 0
    for i in 0..<ab.count { diff |= ab[i] ^ bb[i] }
    return diff == 0
}
