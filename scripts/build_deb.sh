#!/bin/bash
# Build and package BitMusic as a .deb file for Linux (amd64)
# Usage: ./scripts/build_deb.sh

set -euo pipefail

APP=bitmusic
VERSION=1.0.0
ARCH=amd64
PKG="${APP}_${VERSION}-1_${ARCH}"
BUNDLE=build/linux/x64/release/bundle

echo "==> Building Flutter Linux release..."
flutter build linux --release

echo "==> Creating .deb structure in /tmp/${PKG}..."
PKGDIR="/tmp/${PKG}"
rm -rf "${PKGDIR}"

install -d "${PKGDIR}/usr/bin"
install -d "${PKGDIR}/usr/lib/${APP}"
install -d "${PKGDIR}/usr/share/${APP}/data"
install -d "${PKGDIR}/usr/share/applications"
install -d "${PKGDIR}/DEBIAN"

# Binary
install -m 755 "${BUNDLE}/${APP}" "${PKGDIR}/usr/bin/${APP}"

# Shared libraries Flutter uses
cp -r "${BUNDLE}/lib/." "${PKGDIR}/usr/lib/${APP}/"

# Assets (Flutter data directory)
cp -r "${BUNDLE}/data/." "${PKGDIR}/usr/share/${APP}/data/"

# DEBIAN/control
cat > "${PKGDIR}/DEBIAN/control" << EOF
Package: ${APP}
Version: ${VERSION}
Architecture: ${ARCH}
Maintainer: SyberianIT <info@syberianit.com>
Installed-Size: $(du -sk "${PKGDIR}" | cut -f1)
Depends: libgtk-3-0 (>= 3.24), liblzma5, libglib2.0-0, libgstreamer1.0-0, libgstreamer-plugins-base1.0-0, gstreamer1.0-plugins-good, ffmpeg
Section: sound
Priority: optional
Description: BitMusic - Music Search & Download
 Search YouTube, download audio, play offline.
EOF

# DEBIAN/postinst
cat > "${PKGDIR}/DEBIAN/postinst" << 'POSTINST'
#!/bin/sh
set -e
cat > /usr/share/applications/bitmusic.desktop << 'DESKTOP'
[Desktop Entry]
Name=BitMusic
Exec=/usr/bin/bitmusic
Icon=bitmusic
Type=Application
Categories=Audio;Music;
DESKTOP
update-desktop-database /usr/share/applications/ 2>/dev/null || true
POSTINST
chmod 0755 "${PKGDIR}/DEBIAN/postinst"

# Desktop file
cat > "${PKGDIR}/usr/share/applications/bitmusic.desktop" << 'EOF'
[Desktop Entry]
Name=BitMusic
Comment=Search and download music from YouTube
Exec=/usr/bin/bitmusic
Icon=bitmusic
Terminal=false
Type=Application
Categories=Audio;Music;Network;
EOF

echo "==> Creating RPATH wrapper so .so files are found..."
cat > /tmp/bitmusic_wrapper << 'WRAPPER'
#!/bin/sh
export LD_LIBRARY_PATH=/usr/lib/bitmusic:$LD_LIBRARY_PATH
exec /usr/lib/bitmusic/bitmusic_bin "$@"
WRAPPER
# (optional — you can also use patchelf or ldd checks instead)

echo "==> Building .deb..."
dpkg-deb --build "${PKGDIR}" "${PKG}.deb"

echo ""
echo "Done! Package: ${PKG}.deb"
echo "Install with:  sudo dpkg -i ${PKG}.deb && sudo apt-get install -f"
