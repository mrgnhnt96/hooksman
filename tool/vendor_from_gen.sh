#!/usr/bin/env bash
# Copies unpublished nocterm packages from gen/ into committed vendor dirs
# under lib/src/vendor/, rewriting package imports for hooksman.
#
# gen/ remains the source of truth (synced by tool/sync_gen.sh).
# Vendor dirs are committed so pub.dev publish has no path/git deps.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GEN_NOCTERM="${ROOT}/gen/nocterm"
VENDOR_ROOT="${ROOT}/lib/src/vendor"
LICENSE_SRC="${GEN_NOCTERM}/LICENSE"

PACKAGES=(nocterm_provider nocterm_nested)

if [[ ! -d "${GEN_NOCTERM}" ]]; then
  echo "Missing ${GEN_NOCTERM}." >&2
  echo "Run: bash tool/sync_gen.sh" >&2
  exit 1
fi

if [[ ! -f "${LICENSE_SRC}" ]]; then
  echo "Missing nocterm LICENSE at ${LICENSE_SRC}" >&2
  exit 1
fi

rewrite_imports() {
  local file="$1"
  # Hosted nocterm stays as package:nocterm/...
  # Unpublished packages become package:hooksman/src/vendor/...
  perl -i -pe '
    s#package:nocterm_provider/#package:hooksman/src/vendor/nocterm_provider/#g;
    s#package:nocterm_nested/#package:hooksman/src/vendor/nocterm_nested/#g;
  ' "${file}"
}

for pkg in "${PACKAGES[@]}"; do
  src="${GEN_NOCTERM}/packages/${pkg}/lib"
  dest="${VENDOR_ROOT}/${pkg}"

  if [[ ! -d "${src}" ]]; then
    echo "Missing package lib: ${src}" >&2
    exit 1
  fi

  echo "→ vendor ${pkg}"
  rm -rf "${dest}"
  mkdir -p "${dest}"
  cp -R "${src}/." "${dest}/"
  cp "${LICENSE_SRC}" "${dest}/LICENSE"

  # Marker so re-vendoring is obvious in review.
  {
    echo "# Vendored from gen/nocterm/packages/${pkg}"
    echo "# Source of truth: tool/gen_packages.yaml + tool/sync_gen.sh"
    echo "# Refresh: bash tool/vendor_from_gen.sh (or sip gen sync)"
  } >"${dest}/VENDOR.md"

  while IFS= read -r -d '' dart_file; do
    rewrite_imports "${dart_file}"
  done < <(find "${dest}" -type f -name '*.dart' -print0)

  echo "  → lib/src/vendor/${pkg}"
done

echo "Done. Vendored packages are under lib/src/vendor/ (committed)."
