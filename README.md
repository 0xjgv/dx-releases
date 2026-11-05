# dx

`dx` is a local-first CLI that orchestrates coding agents (Claude, Codex, Cursor, Prime Agent, Reason): it runs prompts in parallel, composes TOML/Markdown workflows, manages GitHub review approval, and keeps run evidence under `~/.dx`.

This repository hosts release binaries and the installer. The source code is not published here.

## Install

```sh
curl -fsSL https://raw.githubusercontent.com/0xjgv/dx-releases/main/install.sh | sh
```

The installer downloads the archive for your platform, verifies its SHA-256 against `checksums.txt`, and installs `dx` to `~/.local/bin`. It needs `curl` or `wget`, and `sha256sum` or `shasum`.

## Update

Re-run the install command. It replaces the binary and prints the old and new versions.

## Options

Pin a version:

```sh
curl -fsSL https://raw.githubusercontent.com/0xjgv/dx-releases/main/install.sh | DX_VERSION=v0.1.0 sh
```

Pick the install directory (default `~/.local/bin`):

```sh
curl -fsSL https://raw.githubusercontent.com/0xjgv/dx-releases/main/install.sh | DX_INSTALL_DIR=/usr/local/bin sh
```

If the directory is not on your `PATH`, the installer prints the line to add, for example:

```sh
export PATH="$HOME/.local/bin:$PATH"
```

## Platforms

- macOS: amd64, arm64 (a Rosetta shell on Apple silicon gets the native arm64 binary)
- Linux: amd64, arm64

## Manual download

Download `dx_<version>_<os>_<arch>.tar.gz` and `checksums.txt` from the [Releases](https://github.com/0xjgv/dx-releases/releases) page, then verify and extract:

```sh
shasum -a 256 -c checksums.txt --ignore-missing   # macOS
sha256sum -c checksums.txt --ignore-missing       # Linux
tar -xzf dx_<version>_<os>_<arch>.tar.gz dx
mv dx ~/.local/bin/
```

## Uninstall

```sh
rm ~/.local/bin/dx
```

`dx` keeps its config and run state in `~/.dx`. Remove that directory too if you no longer need it.
