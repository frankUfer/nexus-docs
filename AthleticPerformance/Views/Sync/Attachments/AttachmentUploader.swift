import Foundation
import CommonCrypto

/// Uploads pending attachments after a push response.
/// Iterates pendingUploads from the push response, loads file data from disk,
/// computes SHA256 checksum, and uploads via the sync client.
enum AttachmentUploader {

    struct UploadResult {
        let entityId: UUID
        let filename: String
        let success: Bool
    }

    /// Uploads all pending attachments from a push response.
    /// - Parameter relativePaths: entityId → relativePath mapping from buildAttachmentRefs
    static func uploadPending(
        _ pendingUploads: [SyncPendingUpload],
        relativePaths: [UUID: String],
        client: NexusSyncClient
    ) async -> [UploadResult] {
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        var results: [UploadResult] = []

        for pending in pendingUploads {
            // Use the known relativePath from the push; fall back to search
            let fileURL: URL?
            if let path = relativePaths[pending.entityId] {
                let candidate = documentsURL.appendingPathComponent(path)
                fileURL = FileManager.default.fileExists(atPath: candidate.path) ? candidate : nil
            } else {
                fileURL = findMediaFile(filename: pending.filename, documentsURL: documentsURL)
            }

            guard let fileURL, let fileData = try? Data(contentsOf: fileURL) else {
                results.append(UploadResult(entityId: pending.entityId, filename: pending.filename, success: false))
                continue
            }

            let contentType = mimeType(for: pending.filename)

            do {
                let response = try await client.upload(
                    token: pending.uploadToken,
                    fileData: fileData,
                    filename: pending.filename,
                    contentType: contentType
                )
                results.append(UploadResult(
                    entityId: response.entityId,
                    filename: response.filename,
                    success: response.stored
                ))
            } catch {
                results.append(UploadResult(entityId: pending.entityId, filename: pending.filename, success: false))
            }
        }

        return results
    }

    /// Computes SHA256 checksum for a file.
    static func sha256(data: Data) -> String {
        var hash = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        data.withUnsafeBytes { buffer in
            _ = CC_SHA256(buffer.baseAddress, CC_LONG(buffer.count), &hash)
        }
        return hash.map { String(format: "%02x", $0) }.joined()
    }

    // MARK: - Helpers

    private static func findMediaFile(filename: String, documentsURL: URL) -> URL? {
        let patientsDir = documentsURL.appendingPathComponent("patients", isDirectory: true)
        let fm = FileManager.default

        guard let patientDirs = try? fm.contentsOfDirectory(at: patientsDir, includingPropertiesForKeys: nil) else {
            return nil
        }

        for dir in patientDirs {
            // Search media/ directly under patient dir
            let mediaDir = dir.appendingPathComponent("media", isDirectory: true)
            let candidate = mediaDir.appendingPathComponent(filename)
            if fm.fileExists(atPath: candidate.path) {
                return candidate
            }

            // Search media/ under therapy subdirectories (patients/{uuid}/therapy_{uuid}/media/)
            guard let subdirs = try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) else {
                continue
            }
            for subdir in subdirs {
                let nestedMedia = subdir.appendingPathComponent("media", isDirectory: true).appendingPathComponent(filename)
                if fm.fileExists(atPath: nestedMedia.path) {
                    return nestedMedia
                }
            }
        }

        return nil
    }

    static func mimeType(for filename: String) -> String {
        let ext = (filename as NSString).pathExtension.lowercased()
        switch ext {
        case "jpg", "jpeg": return "image/jpeg"
        case "png": return "image/png"
        case "heic": return "image/heic"
        case "pdf": return "application/pdf"
        case "mp4": return "video/mp4"
        case "mov": return "video/quicktime"
        case "m4a": return "audio/mp4"
        case "mp3": return "audio/mpeg"
        case "csv": return "text/csv"
        default: return "application/octet-stream"
        }
    }
}
