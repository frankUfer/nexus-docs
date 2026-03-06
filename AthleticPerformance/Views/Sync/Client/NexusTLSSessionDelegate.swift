import Foundation
import Security

/// URLSession delegate that trusts the Nexus CA certificate.
///
/// The nexus-core server uses a self-signed certificate issued by our own CA.
/// The CA cert (DER format) is read from Documents/resources/tls/ at init time,
/// copied there by `setupAppDirectories()` from the app bundle on first launch.
final class NexusTLSSessionDelegate: NSObject, URLSessionDelegate {

    private let trustedCACert: SecCertificate?

    override init() {
        trustedCACert = Self.loadCACertificate()
        super.init()
    }

    /// Load the CA cert: try Documents/resources/tls/ first, fall back to app bundle.
    private static func loadCACertificate() -> SecCertificate? {
        // 1) Documents folder (copied there by setupAppDirectories)
        if let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            let tlsDir = docs.appendingPathComponent("resources/tls")
            let docURL = tlsDir.appendingPathComponent("nexus-ca-cert.txt")
            if let cert = loadPEM(from: docURL) {
                return cert
            }
        }

        // 2) Bundle fallback
        if let url = Bundle.main.url(forResource: "nexus-ca-cert", withExtension: "txt"),
           let cert = loadPEM(from: url) {
            return cert
        }

        print("[NexusTLS] WARNING — no CA cert loaded")
        return nil
    }

    private static func loadPEM(from url: URL) -> SecCertificate? {
        guard let pem = try? String(contentsOf: url, encoding: .utf8) else { return nil }
        let base64 = pem
            .replacingOccurrences(of: "-----BEGIN CERTIFICATE-----", with: "")
            .replacingOccurrences(of: "-----END CERTIFICATE-----", with: "")
            .replacingOccurrences(of: "\n", with: "")
            .replacingOccurrences(of: "\r", with: "")
            .trimmingCharacters(in: .whitespaces)
        guard let data = Data(base64Encoded: base64) else { return nil }
        return SecCertificateCreateWithData(nil, data as CFData)
    }

    func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
              let serverTrust = challenge.protectionSpace.serverTrust,
              let caCert = trustedCACert else {
            completionHandler(.performDefaultHandling, nil)
            return
        }

        SecTrustSetAnchorCertificates(serverTrust, [caCert] as CFArray)
        SecTrustSetAnchorCertificatesOnly(serverTrust, true)

        var error: CFError?
        if SecTrustEvaluateWithError(serverTrust, &error) {
            completionHandler(.useCredential, URLCredential(trust: serverTrust))
        } else {
            completionHandler(.performDefaultHandling, nil)
        }
    }
}

/// A URLSession configured to trust the Nexus CA certificate.
extension URLSession {
    static let nexus: URLSession = {
        let delegate = NexusTLSSessionDelegate()
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        return URLSession(configuration: config, delegate: delegate, delegateQueue: nil)
    }()
}
