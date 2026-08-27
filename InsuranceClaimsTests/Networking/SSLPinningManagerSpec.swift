@testable import InsuranceClaims
import Nimble
import Quick
import Security

/// A self-signed EC P-256 certificate generated offline for these specs
/// (subject "unit-test.local", 10-year validity). Its SPKI SHA-256 pin,
/// computed the same way `SSLPinningManager` computes it (and cross-checked
/// against `openssl x509 -pubkey | openssl pkey -pubin | openssl dgst -sha256`),
/// is `gSHJhfcmF1IB7Bhznq7i3gMxyKg94XOq6Q6vhYS3BTU=`.
private let testCertificateBase64 = """
MIIBIjCBygIJANXXgaUUEWOEMAoGCCqGSM49BAMCMBoxGDAWBgNVBAMMD3VuaXQtdGVzdC5sb2NhbDAeFw0y\
NjA4MjcwNTM3NThaFw0zNjA4MjQwNTM3NThaMBoxGDAWBgNVBAMMD3VuaXQtdGVzdC5sb2NhbDBZMBMGByqGS\
M49AgEGCCqGSM49AwEHA0IABKppGM/yONOhhWYjhtCcp5rH3BMuwXmojlkkRHfEdCtojPo2r9F1hhQzYsEQ7y\
lF3y8eOGXldRJxN25ED4GCBm4wCgYIKoZIzj0EAwIDRwAwRAIgNIFVrMnKLTjiCQapZHC+238EytrJh5FTeF9\
kttfkXAsCIE/NNGG2vd58Qy3orqINUncmQsNNadiIYUQ88JVG3c1U
"""

private let testCertificatePin = "gSHJhfcmF1IB7Bhznq7i3gMxyKg94XOq6Q6vhYS3BTU="

/// A self-signed RSA-2048 certificate (subject "unit-test-rsa.local"),
/// generated and pinned the same way as the EC certificate above — used to
/// exercise the evaluator's RSA SPKI header path alongside the EC one.
private let testRSACertificateBase64 = """
MIICuDCCAaACCQCHeq/2hrcmADANBgkqhkiG9w0BAQsFADAeMRwwGgYDVQQDDBN1bml0LXRlc3QtcnNhLmxvY2\
FsMB4XDTI2MDgyNzA1NDIxN1oXDTM2MDgyNDA1NDIxN1owHjEcMBoGA1UEAwwTdW5pdC10ZXN0LXJzYS5sb2Nhb\
DCCASIwDQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEBAM0RLxeLtM47hC0jRZDyBp72LA8yrRxn6rzwYGtRbpy5\
F6pMUQEvOVQpaHfOJsiQZU2stT16g1Y4c+jQl7ddm3v1mdIOb3LDnzKPhvFaPgTwP4xo7mYYPerat1sOh7AIZQD\
H3ZNW9AZgeqw1x89W5kYv/soSgWLBDyMlJ7W2iWKZXqtD3Xlobr9+gv7iPQ/MKD8wiNd7vNdzsBPWmvRfzVwFyD\
foM/bXBjFA6+xIuaA+Q3yLLM+uVig5O/5TejY+BmL6Qtn/vY3KThT9vMeTVcIUoXSUy0iCFys9MuI4BZcSz0yNr\
4nQPx1pQx6FuqzQJMEftpfagn0wQensUatHIMMCAwEAATANBgkqhkiG9w0BAQsFAAOCAQEAOr/8DG+e4dCJ3wJY\
ZhMh0lYqPAqhKh/MouJXdV1uN/GPMGpksQJT/uF8bimEDxcyImdtBgYWl90IXdwca78yJK7TZVZv+Y8Qj5+agMO\
ijGd18FcO8kQcIOv/w6P/NZ2GWsF9BEAvbT0nwoqbJ7s3MfrsqU+N0xdWOQgNTAHqvvvzo+A4p5b1jTqK3ZiehOn\
wt/blzzbDpT0k+umHl+lEiO1aFxt98nIoXtsKts9EENWLAdPgSlj/MCZB40HnC3AjwEqPfXToUgpBeNro+qLBK7\
3q7kQwxYL6rycFkDy9USIJoj9u4B5qOztjDylgdKkTS5fKthybgp+0vDykUJG3rQ==
"""

private func makeTestCertificate() -> SecCertificate {
    let der = Data(base64Encoded: testCertificateBase64)!
    return SecCertificateCreateWithData(nil, der as CFData)!
}

private func makeTestRSACertificate() -> SecCertificate {
    let der = Data(base64Encoded: testRSACertificateBase64)!
    return SecCertificateCreateWithData(nil, der as CFData)!
}

/// A self-signed DSA-2048 certificate (subject "unit-test-dsa.local"). DSA
/// isn't supported by iOS's X.509 chain validation, so evaluating a trust
/// built from it is rejected at the trust-evaluation step itself, before
/// SSLPinningManager ever gets to inspect the key — this exercises that
/// real-world rejection, while the SPKIHeader mock-based specs below cover
/// the "unrecognized key algorithm" branch directly.
private let testDSACertificateBase64 = """
MIIEHTCCA8ICCQCSo+qFvx5pBjALBglghkgBZQMEAwIwHjEcMBoGA1UEAwwTdW5pdC10ZXN0LWRzYS5sb2Nhb\
DAeFw0yNjA4MjcwNTQ0NDdaFw0zNjA4MjQwNTQ0NDdaMB4xHDAaBgNVBAMME3VuaXQtdGVzdC1kc2EubG9jYWw\
wggNGMIICOQYHKoZIzjgEATCCAiwCggEBAKyFyIp3Ap6Y6rhrld5m3/ur7wxiHVlFrfz9hQLOlgpdKhvMbuMSX\
EjdJWhz+kukuPeJbtKGo7QDRsxaxs8L2IGu90GKpISZmkIzLcdbuHpLwuftfaxU3lZnjeBoWPKxxEdUxI/27Ll\
gat3zKQGBk7AZ9pZb/gQvbSprbZuwJu/Yjjn2xWxx/97Elwi7ONTf67xG/OV3QHBamHPReqSacY59QmDhXYXn\
tO2F5os3mi33dkbbJG2lrsHx3tY2WqIWZjEG8H5t/aFVZn7KCoYVvX7YanVa7ycwIM2mGKa6Z5Qr6gCHJGg9wg\
Jo5XS9cpsymXJhHPk3hSz+1LFXyDwGQXsCIQDsIajdQBBu3Q238nCVj4wUAOEsOvXwFBp8JoIMEhmf9wKCAQA\
636AA9jAezGXMvPjKHw4n5dY546h7HuSUZ4HvmHsc+Nvl2scLds0eC9SgEXn2Icxnzpxzy100fl/m2sSYcpjz\
mWafOukmCUqdTIJrAqUneXgsPiMk876O9ywo0vqZ0rk60mZU+WGzpska/FmSpEXIVQCe/I4ghMGvVe2BtNWU/\
6UVfBJF0If13x6HFE4Hmmg/2Dxu4EzojGT0coOu39b9OEeZbq70wqeSd48b51zQ1CBkDWqZ8PSaD4OUI3aVws\
83+FQKTUJH1vfOWz0PqJeB36k5eTMKC/T/ccnBxSnO5nGcgrLSSPpbGUVUR3BwpUTW297EQ9BTVUcU8Enggfl\
vA4IBBQACggEAaTS4zBQec49MFZeo7VQ6xkC4SW6PJmAY9JCXTD9HzaeS4gCjwuYWlNWxRvkhoyD/Jt48IkkT\
n5sS++a0kuNQn+eJmV6qESlSnon50rsH1x2y7qCfUt2JDm0AGAnN3W3USQNXn8JuGdZLHy7Y5Dp0nu50NelNx\
wrDHu5HP1IT2tkj5ukQkw8AVm2lePKWFWkvbxR89of+y9ud6bpJRUM3nG0q9nQrn93IjNRCBBYrupMdvvkn4i\
3TcylK/1sG5/fzM2EUBqqaXGtKrVxNZ700fe2Q8YEyl0OzVSiV7GOf01O0NvAfavY2sVK2GtOqOnP7Wz5Dy1a\
kim/lbYTQX8JKYTALBglghkgBZQMEAwIDSAAwRQIhAObZCA8m2LbQbNSkHBoQ3HVSjOIiy1OhyN0nGVVTQnUx\
AiBZ6e+sVkCkY/vBtPm/YzOo1+H9Lg3HgdaqxXNU9j+/vA==
"""

private func makeTestDSACertificate() -> SecCertificate {
    let der = Data(base64Encoded: testDSACertificateBase64)!
    return SecCertificateCreateWithData(nil, der as CFData)!
}

/// A trust object for the test certificate, evaluated as its own anchor so
/// `SecTrustEvaluateWithError` succeeds without any real certificate
/// authority — this is what lets the "matching pin" and "no matching pin"
/// branches run completely offline.
private func makeSelfAnchoredTrust() -> SecTrust {
    let certificate = makeTestCertificate()
    var trust: SecTrust?
    SecTrustCreateWithCertificates(certificate, SecPolicyCreateBasicX509(), &trust)
    SecTrustSetAnchorCertificates(trust!, [certificate] as CFArray)
    SecTrustSetAnchorCertificatesOnly(trust!, true)
    return trust!
}

final class SSLPinningManagerSpec: QuickSpec {
    override class func spec() {
        describe("SSLPinningManager") {
            it("decodes the pinned public key hash to a well-formed base64 SHA-256 digest") {
                expect(SSLPinningManager.pinnedPublicKeyHashes).toNot(beEmpty())
                for hash in SSLPinningManager.pinnedPublicKeyHashes {
                    let decoded = Data(base64Encoded: hash)
                    expect(decoded).toNot(beNil())
                    expect(decoded?.count).to(equal(32))
                }
            }

            it("builds a server trust manager with an evaluator for the pinned host") {
                let manager = SSLPinningManager.makeServerTrustManager(pinnedHost: "example.com")
                expect(manager.evaluators["example.com"]).toNot(beNil())
            }
        }

        describe("PublicKeyHashTrustEvaluator") {
            it("accepts a trust whose certificate matches a pinned hash") {
                let evaluator = PublicKeyHashTrustEvaluator(pinnedHashes: [testCertificatePin])
                expect {
                    try evaluator.evaluate(makeSelfAnchoredTrust(), forHost: "unit-test.local")
                }.toNot(throwError())
            }

            it("rejects a trust whose certificate matches none of the pinned hashes") {
                let evaluator = PublicKeyHashTrustEvaluator(pinnedHashes: ["not-the-right-pin"])
                expect {
                    try evaluator.evaluate(makeSelfAnchoredTrust(), forHost: "unit-test.local")
                }.to(throwError())
            }

            it("hashes an RSA certificate's SPKI using the RSA ASN.1 header") {
                let certificate = makeTestRSACertificate()
                var trust: SecTrust?
                SecTrustCreateWithCertificates(certificate, SecPolicyCreateBasicX509(), &trust)
                SecTrustSetAnchorCertificates(trust!, [certificate] as CFArray)
                SecTrustSetAnchorCertificatesOnly(trust!, true)

                let evaluator = PublicKeyHashTrustEvaluator(pinnedHashes: ["cm+IC98aXi7lEgXiB0ki0RQi9IsuXU/BN8piwjR3E4M="])
                expect {
                    try evaluator.evaluate(trust!, forHost: "unit-test-rsa.local")
                }.toNot(throwError())
            }

            it("rejects a certificate whose key algorithm is neither RSA nor EC") {
                let certificate = makeTestDSACertificate()
                var trust: SecTrust?
                SecTrustCreateWithCertificates(certificate, SecPolicyCreateBasicX509(), &trust)
                SecTrustSetAnchorCertificates(trust!, [certificate] as CFArray)
                SecTrustSetAnchorCertificatesOnly(trust!, true)

                let evaluator = PublicKeyHashTrustEvaluator(pinnedHashes: ["irrelevant-for-this-case"])
                expect {
                    try evaluator.evaluate(trust!, forHost: "unit-test-dsa.local")
                }.to(throwError())
            }

            it("rejects a trust that doesn't chain to a trusted anchor") {
                var trust: SecTrust?
                SecTrustCreateWithCertificates(makeTestCertificate(), SecPolicyCreateBasicX509(), &trust)
                // No anchor certificates configured, so this self-signed
                // certificate is not trusted by the evaluating system.

                let evaluator = PublicKeyHashTrustEvaluator(pinnedHashes: [testCertificatePin])
                expect {
                    try evaluator.evaluate(trust!, forHost: "unit-test.local")
                }.to(throwError())
            }
        }

        // The Security framework itself never fails these calls for a
        // certificate it agreed to construct in the first place — these
        // defensive guards only exist for API contracts Apple documents as
        // "can return nil," so they're exercised here via a mocked
        // PublicKeyExtracting rather than by trying to manufacture a
        // certificate that corrupts them for real.
        describe("SSLPinningManager.publicKeyHash, with a mocked key extractor") {
            afterEach {
                SSLPinningManager.keyExtractor = RealPublicKeyExtractor()
            }

            it("rejects the certificate when the public key itself can't be extracted") {
                var stub = StubPublicKeyExtractor()
                stub.publicKeyOverride = .value(nil)
                SSLPinningManager.keyExtractor = stub

                let evaluator = PublicKeyHashTrustEvaluator(pinnedHashes: [testCertificatePin])
                expect {
                    try evaluator.evaluate(makeSelfAnchoredTrust(), forHost: "unit-test.local")
                }.to(throwError())
            }

            it("rejects the certificate when the key's external representation can't be extracted") {
                var stub = StubPublicKeyExtractor()
                stub.externalRepresentationOverride = .value(nil)
                SSLPinningManager.keyExtractor = stub

                let evaluator = PublicKeyHashTrustEvaluator(pinnedHashes: [testCertificatePin])
                expect {
                    try evaluator.evaluate(makeSelfAnchoredTrust(), forHost: "unit-test.local")
                }.to(throwError())
            }
        }

        describe("SPKIHeader.header, with a mocked key extractor") {
            afterEach {
                SSLPinningManager.keyExtractor = RealPublicKeyExtractor()
            }

            it("falls back to an empty header when the key's attributes can't be read") {
                var stub = StubPublicKeyExtractor()
                stub.attributesOverride = .value(nil)
                SSLPinningManager.keyExtractor = stub

                // A mismatched pin is expected either way — what this proves
                // is that the whole evaluation still completes (rather than
                // crashing) when the attributes lookup itself fails.
                let evaluator = PublicKeyHashTrustEvaluator(pinnedHashes: [testCertificatePin])
                expect {
                    try evaluator.evaluate(makeSelfAnchoredTrust(), forHost: "unit-test.local")
                }.to(throwError())
            }

            it("falls back to an empty header for a key algorithm that's neither RSA nor EC") {
                var stub = StubPublicKeyExtractor()
                stub.attributesOverride = .value([
                    kSecAttrKeyType: "unsupportedAlgorithm" as CFString,
                    kSecAttrKeySizeInBits: 256
                ])
                SSLPinningManager.keyExtractor = stub

                let evaluator = PublicKeyHashTrustEvaluator(pinnedHashes: [testCertificatePin])
                expect {
                    try evaluator.evaluate(makeSelfAnchoredTrust(), forHost: "unit-test.local")
                }.to(throwError())
            }
        }
    }
}

/// Delegates to `RealPublicKeyExtractor` for whichever calls aren't
/// overridden, so a spec can fail just one step of the extraction chain
/// without having to fake every other value it doesn't care about. A plain
/// `T?` can't distinguish "not overridden" from "overridden to nil", hence
/// the explicit `Override` enum rather than a double-optional.
private struct StubPublicKeyExtractor: PublicKeyExtracting {
    enum Override<T> {
        case unset
        case value(T)
    }

    private let real = RealPublicKeyExtractor()
    var publicKeyOverride: Override<SecKey?> = .unset
    var externalRepresentationOverride: Override<Data?> = .unset
    var attributesOverride: Override<[CFString: Any]?> = .unset

    func publicKey(for certificate: SecCertificate) -> SecKey? {
        if case .value(let override) = publicKeyOverride { return override }
        return real.publicKey(for: certificate)
    }

    func externalRepresentation(for key: SecKey) -> Data? {
        if case .value(let override) = externalRepresentationOverride { return override }
        return real.externalRepresentation(for: key)
    }

    func attributes(for key: SecKey) -> [CFString: Any]? {
        if case .value(let override) = attributesOverride { return override }
        return real.attributes(for: key)
    }
}
