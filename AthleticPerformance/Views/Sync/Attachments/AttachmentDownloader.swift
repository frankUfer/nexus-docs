import Foundation

/// Downloads attachments referenced in pull changes and saves them to the patient's media directory.
enum AttachmentDownloader {

    struct DownloadResult {
        let filename: String
        let success: Bool
    }

    /// Downloads all attachments from a pull change and saves them to the patient's media directory.
    static func downloadAttachments(
        for change: SyncPullChange,
        client: NexusSyncClient
    ) async -> [DownloadResult] {
        guard let attachments = change.attachments, !attachments.isEmpty else { return [] }
        guard let patientId = change.patientId else { return [] }

        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let mediaDir = documentsURL
            .appendingPathComponent("patients", isDirectory: true)
            .appendingPathComponent(patientId.uuidString, isDirectory: true)
            .appendingPathComponent("media", isDirectory: true)

        // Ensure media directory exists
        try? FileManager.default.createDirectory(at: mediaDir, withIntermediateDirectories: true)

        var results: [DownloadResult] = []

        for attachment in attachments {
            do {
                let data = try await client.download(token: attachment.downloadUrl)
                let fileURL = mediaDir.appendingPathComponent(attachment.filename)
                try data.write(to: fileURL, options: .atomic)
                results.append(DownloadResult(filename: attachment.filename, success: true))
            } catch {
                results.append(DownloadResult(filename: attachment.filename, success: false))
            }
        }

        return results
    }
}
