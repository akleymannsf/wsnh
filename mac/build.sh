#!/bin/bash
set -euo pipefail

APP_NAME="WSNH"
BUILD_DIR=".build/release"
APP_BUNDLE="${APP_NAME}.app"

# We sign with a local self-signed certificate instead of ad-hoc (`--sign -`).
# Ad-hoc signatures are derived from the binary's own contents, so they change
# on every rebuild — macOS then treats each rebuild as a "new" app and drops
# any Accessibility permission you already granted. Signing with a stable
# certificate identity instead means macOS recognizes rebuilt versions as the
# same app, so the Accessibility grant survives rebuilds. This certificate is
# still free and local-only — no Apple Developer account involved, and it
# never leaves this Mac.
CERT_NAME="WSNH Local Dev"
KEYCHAIN="${HOME}/Library/Keychains/login.keychain-db"

# Deliberately no `-v` here: that flag restricts the list to identities
# macOS considers "valid" (i.e. chains to a trusted root), and our
# intentionally-untrusted self-signed cert would never show up under that
# filter -- every build would then think no cert existed yet and create a
# fresh duplicate, eventually making the name ambiguous to `codesign`.
if ! security find-identity -p codesigning "${KEYCHAIN}" 2>/dev/null | grep -q "${CERT_NAME}"; then
    echo "==> No local signing certificate found — creating '${CERT_NAME}' (one-time setup)..."
    CERT_DIR="$(mktemp -d)"
    trap 'rm -rf "${CERT_DIR}"' EXIT

    cat > "${CERT_DIR}/codesign.conf" <<EOF
[req]
distinguished_name = dn
x509_extensions = ext
prompt = no

[dn]
CN = ${CERT_NAME}

[ext]
basicConstraints = critical,CA:false
keyUsage = critical,digitalSignature
extendedKeyUsage = critical,codeSigning
EOF

    openssl req -x509 -newkey rsa:2048 -sha256 -days 3650 -nodes \
        -keyout "${CERT_DIR}/key.pem" -out "${CERT_DIR}/cert.pem" \
        -config "${CERT_DIR}/codesign.conf" -extensions ext

    # OpenSSL 3.x changed the default PKCS#12 encryption/MAC algorithms to
    # ones macOS's own importer can't read, which fails with a misleading
    # "wrong password?" error even though the password is correct. Detect
    # OpenSSL 3.x and fall back to the older, Apple-compatible algorithms in
    # that case; OpenSSL 1.1.x and Apple's own LibreSSL-based `openssl` are
    # fine with the plain command (and don't understand `-legacy` at all).
    if openssl version | grep -q "^OpenSSL 3"; then
        openssl pkcs12 -export \
            -inkey "${CERT_DIR}/key.pem" -in "${CERT_DIR}/cert.pem" \
            -out "${CERT_DIR}/cert.p12" -passout pass:wsnh \
            -legacy -nomaciter -descert -keypbe PBE-SHA1-3DES -certpbe PBE-SHA1-3DES
    else
        openssl pkcs12 -export \
            -inkey "${CERT_DIR}/key.pem" -in "${CERT_DIR}/cert.pem" \
            -out "${CERT_DIR}/cert.p12" -passout pass:wsnh
    fi

    # -T grants codesign/security access to the private key without a
    # keychain prompt on every future build. We deliberately don't mark this
    # certificate as "trusted" system-wide (that needs admin authorization
    # and isn't needed here) — codesign can sign with an untrusted
    # certificate just fine; trust only affects separate verification checks,
    # not the signing operation or Accessibility/TCC identity matching.
    security import "${CERT_DIR}/cert.p12" -k "${KEYCHAIN}" -P wsnh \
        -T /usr/bin/codesign -T /usr/bin/security

    echo "==> Certificate created. This only happens once per Mac."
fi

echo "==> Building ${APP_NAME} (release)..."
swift build -c release

echo "==> Assembling ${APP_BUNDLE}..."
rm -rf "${APP_BUNDLE}"
mkdir -p "${APP_BUNDLE}/Contents/MacOS"
mkdir -p "${APP_BUNDLE}/Contents/Resources"

cp "${BUILD_DIR}/${APP_NAME}" "${APP_BUNDLE}/Contents/MacOS/${APP_NAME}"
cp Info.plist "${APP_BUNDLE}/Contents/Info.plist"

if [ -d "Resources/AppIcon.iconset" ]; then
    echo "==> Building app icon..."
    iconutil -c icns "Resources/AppIcon.iconset" -o "${APP_BUNDLE}/Contents/Resources/AppIcon.icns"
fi

echo "==> Code signing with '${CERT_NAME}'..."
codesign --force --deep --sign "${CERT_NAME}" "${APP_BUNDLE}"

echo ""
echo "Done. ${APP_BUNDLE} is ready."
echo "Move it to /Applications, then right-click > Open the first time (unsigned app)."
echo "You'll be asked to grant Accessibility permission the first time you trigger a hotkey."
echo "Because this build is signed with a stable local certificate, that grant will"
echo "survive future rebuilds — no more re-granting Accessibility every time."
