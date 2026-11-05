#!/bin/sh
# Install or update dx. Re-run to update.
#
#   curl -fsSL https://raw.githubusercontent.com/0xjgv/dx-releases/main/install.sh | sh
#
# DX_VERSION        release tag to install (default: latest), e.g. v1.2.3
# DX_INSTALL_DIR    target directory (default: $HOME/.local/bin)
# DX_DOWNLOAD_BASE  releases base: URL or local directory laid out like
#                   GitHub's latest/download/<asset> and download/<tag>/<asset>
set -eu

REPO=0xjgv/dx-releases

die() {
	echo "dx install: $*" >&2
	exit 1
}

fetch() {
	case $1 in
	/*) cp "$1" "$2" ;;
	*)
		if command -v curl >/dev/null 2>&1; then
			curl -fsSL "$1" -o "$2"
		elif command -v wget >/dev/null 2>&1; then
			wget -q -O "$2" "$1"
		else
			die "curl or wget is required"
		fi
		;;
	esac || die "download failed: $1"
}

sha256() {
	if command -v sha256sum >/dev/null 2>&1; then
		sha256sum "$1" | awk '{print $1}'
	elif command -v shasum >/dev/null 2>&1; then
		shasum -a 256 "$1" | awk '{print $1}'
	else
		die "sha256sum or shasum is required"
	fi
}

case $(uname -s) in
Darwin) os=darwin ;;
Linux) os=linux ;;
*) die "unsupported OS: $(uname -s)" ;;
esac

case $(uname -m) in
x86_64 | amd64) arch=amd64 ;;
aarch64 | arm64) arch=arm64 ;;
*) die "unsupported architecture: $(uname -m)" ;;
esac

# A shell under Rosetta reports x86_64; prefer the native binary.
if [ "$os" = darwin ] && [ "$arch" = amd64 ] &&
	[ "$(sysctl -n sysctl.proc_translated 2>/dev/null || true)" = 1 ]; then
	arch=arm64
fi

base=${DX_DOWNLOAD_BASE:-https://github.com/$REPO/releases}
version=${DX_VERSION:-}
case $version in
"") release=$base/latest/download ;;
v*) release=$base/download/$version ;;
*) release=$base/download/v$version ;;
esac

install_dir=${DX_INSTALL_DIR:-$HOME/.local/bin}
target=$install_dir/dx
tmpdir=$(mktemp -d)
tmpbin=
trap 'rm -rf "$tmpdir"; [ -z "$tmpbin" ] || rm -f "$tmpbin"' EXIT
trap 'exit 1' HUP INT TERM

fetch "$release/checksums.txt" "$tmpdir/checksums.txt"
# The checksums list names the archive, and with it the version.
archive=$(awk '{sub(/^\*/, "", $2); print $2}' "$tmpdir/checksums.txt" |
	grep "^dx_.*_${os}_${arch}\.tar\.gz\$" | head -n 1 || true)
[ -n "$archive" ] || die "no $os/$arch archive in $release/checksums.txt"
expected=$(awk -v f="$archive" '{sub(/^\*/, "", $2)} $2 == f {print $1}' "$tmpdir/checksums.txt")

fetch "$release/$archive" "$tmpdir/$archive"
actual=$(sha256 "$tmpdir/$archive")
[ "$actual" = "$expected" ] ||
	die "checksum mismatch for $archive: expected $expected, got $actual"

tar -xzf "$tmpdir/$archive" -C "$tmpdir" dx || die "cannot extract dx from $archive"

previous=
if [ -x "$target" ]; then
	previous=$("$target" --version 2>/dev/null || true)
fi

mkdir -p "$install_dir"
tmpbin=$(mktemp "$install_dir/.dx.XXXXXX")
cp "$tmpdir/dx" "$tmpbin"
chmod 755 "$tmpbin"
mv -f "$tmpbin" "$target"
tmpbin=

current=$("$target" --version 2>/dev/null) || die "installed $target does not run"
if [ -n "$previous" ] && [ "$previous" != "$current" ]; then
	echo "Updated $target: $previous -> $current"
else
	echo "Installed $target: $current"
fi

case :$PATH: in
*":$install_dir:"*) ;;
*) echo "Add $install_dir to PATH: export PATH=\"$install_dir:\$PATH\"" ;;
esac
