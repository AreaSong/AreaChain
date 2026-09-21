import CryptoKit
import Foundation

/// 有界、逐附件认证的文件格式；不把整批图片或明文临时目录作为中间产物。
enum PrivateBackupFile {
    private struct Header: Codable {
        var version = 1
        var id: UUID
        var password: PasswordKeySlot
    }
    static let magic = Data("ACBACKUP1\n".utf8)
    private static let manifestLimit = 16 * 1_024 * 1_024

    static func write(_ capture: PrivateBackupCapture, password: String, to url: URL,
                      readAttachment: (AttachmentRef) throws -> Data) throws -> VerifiedPrivateBackup {
        let keyData = try VaultCrypto.randomBytes(count: 32)
        let key = SymmetricKey(data: keyData)
        let id = UUID()
        let header = Header(id: id, password: try VaultCrypto.wrap(keyData, password: password, vaultID: id))
        var manifest = capture.manifest
        manifest.files = try manifest.snapshot.attachments.map { item in
            guard let ref = capture.references[item.id] else { throw PrivacyError.missingAttachment }
            let data = try readAttachment(ref)
            guard data.count <= VaultCrypto.maximumAttachmentBytes else { throw PrivacyError.tooLarge }
            return BackupAttachmentHeader(id: item.id, byteCount: data.count, digest: Data(SHA256.hash(data: data)))
        }
        try manifest.validate()
        let manifestData = try encodeManifest(manifest)
        guard manifestData.count <= manifestLimit else { throw PrivacyError.tooLarge }
        let normalizer = JSONDecoder()
        normalizer.dateDecodingStrategy = ExportDates.decodeStrategy()
        manifest = try normalizer.decode(PrivateBackupManifest.self, from: manifestData)
        let staging = try temporaryURL(for: url)
        defer { staging.cleanup() }
        try writeTemporary(staging.url, header: header, manifest: manifest, key: key) { attachmentID in
            guard let ref = capture.references[attachmentID] else { throw PrivacyError.missingAttachment }
            return try readAttachment(ref)
        }
        let verified = try read(from: staging.url, password: password)
        guard verified == manifest else { throw PrivacyError.corruptData }
        if FileManager.default.fileExists(atPath: url.path) {
            _ = try FileManager.default.replaceItemAt(url, withItemAt: staging.url)
        } else {
            do {
                _ = try FileManager.default.replaceItemAt(url, withItemAt: staging.url)
            } catch {
                try FileManager.default.moveItem(at: staging.url, to: url)
            }
        }
        return VerifiedPrivateBackup(sourceDigest: capture.sourceDigest, url: url, manifest: manifest,
                                     ciphertextDigest: try digest(url))
    }

    static func digest(_ url: URL) throws -> Data {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        var digest = SHA256()
        while let data = try handle.read(upToCount: 65_536), !data.isEmpty { digest.update(data: data) }
        return Data(digest.finalize())
    }

    static func read(from url: URL, password: String,
                     attachment: (UUID, Data) throws -> Void = { _, _ in }) throws -> PrivateBackupManifest {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        guard try exact(handle, count: magic.count) == magic else { throw PrivacyError.corruptData }
        let header = try JSONDecoder().decode(Header.self, from: readFrame(handle, limit: 65_536))
        guard header.version == 1 else { throw PrivacyError.unsupportedVersion }
        let keyData = try VaultCrypto.unwrap(header.password, password: password, vaultID: header.id)
        let key = SymmetricKey(data: keyData)
        let sealedManifest = try readFrame(handle, limit: manifestLimit + 28)
        let raw = try VaultCrypto.open(sealedManifest, key: key, context: "backup:\(header.id):manifest")
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = ExportDates.decodeStrategy()
        let manifest = try decoder.decode(PrivateBackupManifest.self, from: raw)
        try manifest.validate()
        for file in manifest.files {
            let sealed = try readFrame(handle, limit: VaultCrypto.maximumAttachmentBytes + 28)
            guard sealed.count == file.byteCount + 28 else { throw PrivacyError.corruptData }
            let data = try VaultCrypto.open(sealed, key: key, context: "backup:\(header.id):attachment:\(file.id)")
            guard Data(SHA256.hash(data: data)) == file.digest else { throw PrivacyError.corruptData }
            try attachment(file.id, data)
        }
        guard (try handle.read(upToCount: 1))?.isEmpty != false else { throw PrivacyError.corruptData }
        return manifest
    }

    private static func writeTemporary(_ url: URL, header: Header, manifest: PrivateBackupManifest,
                                       key: SymmetricKey, read: (UUID) throws -> Data) throws {
        guard FileManager.default.createFile(atPath: url.path, contents: nil, attributes: [.posixPermissions: 0o600]) else {
            throw PrivacyError.storageFailure
        }
        let handle = try FileHandle(forWritingTo: url)
        defer { try? handle.close() }
        try handle.write(contentsOf: magic)
        try writeFrame(JSONEncoder().encode(header), to: handle)
        let raw = try encodeManifest(manifest)
        try writeFrame(VaultCrypto.seal(raw, key: key, context: "backup:\(header.id):manifest"), to: handle)
        for file in manifest.files {
            let data = try read(file.id)
            guard data.count == file.byteCount, Data(SHA256.hash(data: data)) == file.digest else {
                throw PrivacyError.staleOperation
            }
            let sealed = try VaultCrypto.seal(data, key: key, context: "backup:\(header.id):attachment:\(file.id)")
            try writeFrame(sealed, to: handle)
        }
        try handle.synchronize()
    }

    private static func encodeManifest(_ manifest: PrivateBackupManifest) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        encoder.dateEncodingStrategy = ExportDates.encodeStrategy()
        return try encoder.encode(manifest)
    }

    private static func writeFrame(_ data: Data, to handle: FileHandle) throws {
        var length = UInt64(data.count).bigEndian
        try handle.write(contentsOf: withUnsafeBytes(of: &length) { Data($0) })
        try handle.write(contentsOf: data)
    }

    private static func readFrame(_ handle: FileHandle, limit: Int) throws -> Data {
        let length = try exact(handle, count: 8).reduce(UInt64(0)) { ($0 << 8) | UInt64($1) }
        guard length <= UInt64(limit) else { throw PrivacyError.corruptData }
        return try exact(handle, count: Int(length))
    }

    private static func exact(_ handle: FileHandle, count: Int) throws -> Data {
        var data = Data()
        while data.count < count {
            guard let next = try handle.read(upToCount: count - data.count), !next.isEmpty else { throw PrivacyError.corruptData }
            data.append(next)
        }
        return data
    }

    private static func temporaryURL(for target: URL) throws -> (url: URL, cleanup: () -> Void) {
        let manager = FileManager.default
        if let replacementDir = try? manager.url(for: .itemReplacementDirectory, in: .userDomainMask,
                                                 appropriateFor: target, create: true) {
            let fileURL = replacementDir.appending(path: "areachain-backup-\(UUID().uuidString).tmp")
            return (fileURL, { try? manager.removeItem(at: replacementDir) })
        }
        let fileURL = manager.temporaryDirectory.appending(path: ".areachain-backup-\(UUID().uuidString).tmp")
        return (fileURL, { try? manager.removeItem(at: fileURL) })
    }
}
