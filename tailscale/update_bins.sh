#!/bin/sh
set -e

DIR="$(cd "$(dirname "$0")" && pwd)"
BIN_DIR_32="${DIR}/tailscale/bin_32"
BIN_DIR_64="${DIR}/tailscale/bin_64"

UPX_BIN="${UPX_BIN:-upx}"
UPX_ARGS="--lzma --ultra-brute"

TMPDIR="$(mktemp -d)"
trap 'rm -rf "${TMPDIR}"' EXIT

latest_tag="$(curl -fsSL https://api.github.com/repos/tailscale/tailscale/releases/latest | sed -n 's/.*\"tag_name\"[[:space:]]*:[[:space:]]*\"\\([^\"]*\\)\".*/\\1/p' | head -n 1)"
if [ -z "${latest_tag}" ]; then
	echo "failed to detect latest tailscale release tag" >&2
	exit 1
fi

version="${latest_tag#v}"
echo "tailscale latest: ${latest_tag}"

fetch_one() {
	arch="$1"    # arm / arm64
	out_dir="$2" # bin_32 / bin_64

	pkg="tailscale_${version}_${arch}.tgz"
	url="https://pkgs.tailscale.com/stable/${pkg}"

	echo "downloading: ${url}"
	curl -fsSL -o "${TMPDIR}/${pkg}" "${url}"
	( cd "${TMPDIR}" && tar -zxf "${pkg}" )

	src_dir="${TMPDIR}/tailscale_${version}_${arch}"
	if [ ! -f "${src_dir}/tailscale" ] || [ ! -f "${src_dir}/tailscaled" ]; then
		echo "missing tailscale/tailscaled in tarball" >&2
		exit 1
	fi

	mkdir -p "${out_dir}"

	cat "${src_dir}/tailscaled" "${src_dir}/tailscale" > "${out_dir}/tailscale.combined"
	chmod 755 "${out_dir}/tailscale.combined"

	if command -v "${UPX_BIN}" >/dev/null 2>&1; then
		echo "upx: ${out_dir}/tailscale.combined"
		"${UPX_BIN}" ${UPX_ARGS} "${out_dir}/tailscale.combined" >/dev/null 2>&1 || true
	else
		echo "upx not found, skipping compression"
	fi
}

fetch_one arm "${BIN_DIR_32}"
fetch_one arm64 "${BIN_DIR_64}"

ls -lh "${BIN_DIR_32}/tailscale.combined" "${BIN_DIR_64}/tailscale.combined"