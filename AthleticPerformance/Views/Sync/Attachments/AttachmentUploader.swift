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
    static func uploadPending(
        _ pendingUploads: [SyncPendingUpload],
        client: NexusSyncClient
    ) async -> [UploadResult] {
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        var results: [UploadResult] = []

        for pending in pendingUploads {
            // Find the file on disk — search in patients/*/media/
            let fileURL = findMediaFile(filename: pending.filename, documentsURL: documentsURL)

            guard let fileURL, let fileData = try? Data(contentsOf: fileURL) else {
                results.append(UploadResult(entityId: pending.entityId, filename: pending.filename, success: false))
                continue
            }

            let contentType = mimeType(for: pending.filename)

            do {
                let response = try await client.upload(
                    token: pending.uploadUrl,
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
            let mediaDir = dir.appendingPathComponent("media", isDirectory: true)
            let candidate = mediaDir.appendingPathComponent(filename)
            if fm.fileExists(atPath: candidate.path) {
                return candidate
            }
        }

        return nil
    }

    private static func mimeType(for filename: String) -> String {
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
