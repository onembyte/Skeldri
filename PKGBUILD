# Maintainer: Franco Michetti <franco@example.com>
pkgname=skeldri
pkgver=0.1.0
pkgrel=1
pkgdesc="iPad wireless screen mirroring and live mouse-transparent annotation overlay for Omarchy/Linux"
arch=('x86_64' 'aarch64')
url="https://github.com/onembyte/Skeldri"
license=('MIT')
depends=('glibc' 'gcc-libs' 'ffmpeg')
makedepends=('cargo' 'rust')
optdepends=(
    'hyprland: Wayland compositor support'
    'avahi: mDNS daemon for LAN discovery'
)
source=("$pkgname-$pkgver.tar.gz::$url/archive/refs/tags/v$pkgver.tar.gz")
sha256sums=('SKIP')

build() {
    cd "$srcdir/$pkgname-$pkgver/linux"
    export RUSTUP_TOOLCHAIN=stable
    cargo build --release --locked --bin skeldri
}

package() {
    cd "$srcdir/$pkgname-$pkgver"
    install -Dm755 "linux/target/release/skeldri" "$pkgdir/usr/bin/skeldri"
    install -Dm644 "skeldri.desktop" "$pkgdir/usr/share/applications/skeldri.desktop"
    install -Dm644 "skeldri.service" "$pkgdir/usr/lib/systemd/user/skeldri.service"

    # Omarchy QuickShell plugin
    install -Dm644 "plugins/skeldri/manifest.json" "$pkgdir/usr/share/omarchy/shell/plugins/skeldri/manifest.json"
    install -Dm644 "plugins/skeldri/Panel.qml" "$pkgdir/usr/share/omarchy/shell/plugins/skeldri/Panel.qml"
}
