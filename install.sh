#!/bin/sh
# Install or update dx. Re-run to update.
#
#   curl -fsSL https://raw.githubusercontent.com/0xjgv/dx-releases/main/install.sh | sh
#
# DX_VERSION        release tag to install (default: latest), e.g. v1.2.3
# DX_INSTALL_DIR    target directory (default: $HOME/.local/bin)
# DX_DOWNLOAD_BASE  releases base: URL or local directory laid out like
#                   GitHub's latest/download/<asset> and download/<tag>/<asset>
#
# A first install also creates ~/.dx/config.toml and ~/.dx/workflows from the
# release presets. Existing files, directories, and symlinks are never touched.
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

# fetch_verified downloads $1 from the release into $tmpdir and checks it
# against checksums.txt.
fetch_verified() {
	expected=$(awk -v f="$1" '{sub(/^\*/, "", $2)} $2 == f {print $1}' "$tmpdir/checksums.txt")
	fetch "$release/$1" "$tmpdir/$1"
	actual=$(sha256 "$tmpdir/$1")
	[ "$actual" = "$expected" ] ||
		die "checksum mismatch for $1: expected $expected, got $actual"
}

# missing reports whether nothing (not even a dangling symlink) is at $1.
missing() {
	[ ! -e "$1" ] && [ ! -L "$1" ]
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
fetch_verified "$archive"

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

dx_home=$HOME/.dx
presets=$(awk '{sub(/^\*/, "", $2); print $2}' "$tmpdir/checksums.txt" |
	grep '^dx_presets_.*\.tar\.gz$' | head -n 1 || true)
if [ -n "$presets" ] && { missing "$dx_home/config.toml" || missing "$dx_home/workflows"; }; then
	fetch_verified "$presets"
	mkdir -p "$tmpdir/presets" "$dx_home"
	tar -xzf "$tmpdir/$presets" -C "$tmpdir/presets" || die "cannot extract $presets"
	if missing "$dx_home/config.toml"; then
		cp "$tmpdir/presets/config.example.toml" "$dx_home/config.toml"
		echo "Created $dx_home/config.toml"
	fi
	if missing "$dx_home/workflows"; then
		cp -R "$tmpdir/presets/workflows" "$dx_home/workflows"
		echo "Created $dx_home/workflows"
	fi
fi

case :$PATH: in
*":$install_dir:"*) ;;
*) echo "Add $install_dir to PATH: export PATH=\"$install_dir:\$PATH\"" ;;
esac
