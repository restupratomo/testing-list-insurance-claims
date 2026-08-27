import Alamofire
import CommonCrypto
import Foundation

/// Validates the server's TLS certificate against a known-good public key pin
/// before Alamofire allows any request to complete, so a compromised or
/// spoofed CA cannot be used to intercept claims traffic.
final class SSLPinningManager {

    /// SHA-256 hash of the pinned server's SubjectPublicKeyInfo, base64-encoded.
    /// Rotate this whenever the API's certificate is renewed with a new key pair,
    /// and always ship at least one backup pin to avoid bricking the app mid-rotation.
    static let pinnedPublicKeyHashes: Set<String> = [
        ObfuscatedString("fj/LGYZh+mUuNimcCT6b6V6MLFW1SIzcsM4hgwSwVB4=").value
    ]

    /// Builds the trust manager Alamofire's `Session` should evaluate every
    /// connection to `pinnedHost` against.
    static func makeServerTrustManager(pinnedHost: String) -> ServerTrustManager {
        ServerTrustManager(evaluators: [
            pinnedHost: PublicKeyHashTrustEvaluator(pinnedHashes: pinnedPublicKeyHashes)
        ])
    }

    fileprivate static func publicKeyHash(for certificate: SecCertificate) -> String? {
        guard let publicKey = SecCertificateCopyKey(certificate),
              let publicKeyData = SecKeyCopyExternalRepresentation(publicKey, nil) as Data? else {
            return nil
        }

        // Wrap the raw key bytes with the standard RSA SPKI ASN.1 header so the
        // resulting hash matches the SPKI pin published by the server operator.
        let spkiData = SPKIHeader.header(for: publicKey) + publicKeyData
        var hash = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        spkiData.withUnsafeBytes { buffer in
            _ = CC_SHA256(buffer.baseAddress, CC_LONG(spkiData.count), &hash)
        }
        return Data(hash).base64EncodedString()
    }
}

/// A `ServerTrustEvaluating` that trusts a connection only when the leaf or
/// any intermediate certificate's public key hashes to one of `pinnedHashes`.
/// Internal rather than private so specs can evaluate it directly against a
/// locally generated certificate — pinning by definition can't be exercised
/// through a stubbed network layer.
final class PublicKeyHashTrustEvaluator: ServerTrustEvaluating {
    private let pinnedHashes: Set<String>

    init(pinnedHashes: Set<String>) {
        self.pinnedHashes = pinnedHashes
    }

    func evaluate(_ trust: SecTrust, forHost host: String) throws {
        guard SecTrustEvaluateWithError(trust, nil) else {
            throw AFError.serverTrustEvaluationFailed(reason: .trustEvaluationFailed(error: nil))
        }

        let certificateCount = SecTrustGetCertificateCount(trust)
        for index in 0..<certificateCount {
            guard let certificate = SecTrustGetCertificateAtIndex(trust, index),
                  let hash = SSLPinningManager.publicKeyHash(for: certificate),
                  pinnedHashes.contains(hash) else {
                continue
            }
            return
        }

        throw AFError.serverTrustEvaluationFailed(
            reason: .customEvaluationFailed(error: NetworkError.sslPinningFailed)
        )
    }
}

/// ASN.1 headers required to turn a raw public key (as vended by Security.framework)
/// back into a SubjectPublicKeyInfo blob, matching what `openssl x509 -pubkey` prints.
private enum SPKIHeader {
    static func header(for publicKey: SecKey) -> Data {
        guard let attributes = SecKeyCopyAttributes(publicKey) as? [CFString: Any],
              let keyType = attributes[kSecAttrKeyType] as? String,
              let keySizeInBits = attributes[kSecAttrKeySizeInBits] as? Int else {
            return Data()
        }

        if keyType == (kSecAttrKeyTypeRSA as String) {
            return keySizeInBits == 4096 ? rsa4096Header : rsa2048Header
        }
        if keyType == (kSecAttrKeyTypeECSECPrimeRandom as String) {
            return keySizeInBits == 384 ? ecSecp384r1Header : ecSecp256r1Header
        }
        return Data()
    }

    private static let rsa2048Header = Data([
        0x30, 0x82, 0x01, 0x22, 0x30, 0x0d, 0x06, 0x09, 0x2a, 0x86, 0x48, 0x86,
        0xf7, 0x0d, 0x01, 0x01, 0x01, 0x05, 0x00, 0x03, 0x82, 0x01, 0x0f, 0x00
    ])

    private static let rsa4096Header = Data([
        0x30, 0x82, 0x02, 0x22, 0x30, 0x0d, 0x06, 0x09, 0x2a, 0x86, 0x48, 0x86,
        0xf7, 0x0d, 0x01, 0x01, 0x01, 0x05, 0x00, 0x03, 0x82, 0x02, 0x0f, 0x00
    ])

    /// SPKI header for a P-256 (secp256r1) EC public key.
    private static let ecSecp256r1Header = Data([
        0x30, 0x59, 0x30, 0x13, 0x06, 0x07, 0x2a, 0x86, 0x48, 0xce, 0x3d, 0x02,
        0x01, 0x06, 0x08, 0x2a, 0x86, 0x48, 0xce, 0x3d, 0x03, 0x01, 0x07, 0x03,
        0x42, 0x00
    ])

    /// SPKI header for a P-384 (secp384r1) EC public key.
    private static let ecSecp384r1Header = Data([
        0x30, 0x76, 0x30, 0x10, 0x06, 0x07, 0x2a, 0x86, 0x48, 0xce, 0x3d, 0x02,
        0x01, 0x06, 0x05, 0x2b, 0x81, 0x04, 0x00, 0x22, 0x03, 0x62, 0x00
    ])
}
