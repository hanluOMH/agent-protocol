#!/usr/bin/env bash

# Simple unified build entry for a2a_cpp.

set -euo pipefail

# Default options
BUILD_TYPE="Release"
BUILD_DIR="build"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

print_help() {
  cat <<EOF
Usage: $0 [options]

Options:
  -t, --type <Debug|Release>   CMake build type (default: Release)
  -b, --build-dir <dir>        Build directory (default: build)
  -h, --help                   Show this help message

Examples:
  $0
  $0 -t Debug
  $0 --type Release
EOF
}

# Parse arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    -t|--type)
      BUILD_TYPE="$2";
      shift 2;
      ;;
    -b|--build-dir)
      BUILD_DIR="$2";
      shift 2;
      ;;
    -h|--help)
      print_help;
      exit 0;
      ;;
    *)
      echo "Unknown option: $1" >&2;
      print_help;
      exit 1;
      ;;
  esac
done

# Normalize build type
case "${BUILD_TYPE}" in
  Debug|Release)
    ;;
  *)
    echo "Invalid build type: ${BUILD_TYPE}. Use Debug or Release." >&2
    exit 1
    ;;
esac

source "${SCRIPT_DIR}/scripts/install_deps.sh"

install_dependencies
check_dependencies

# Determine optimal job count for the current platform.
if command -v nproc >/dev/null 2>&1; then
  CPU_CORES=$(nproc)
elif command -v sysctl >/dev/null 2>&1; then
  CPU_CORES=$(sysctl -n hw.ncpu 2>/dev/null || true)
elif command -v getconf >/dev/null 2>&1; then
  CPU_CORES=$(getconf _NPROCESSORS_ONLN 2>/dev/null || true)
else
  CPU_CORES=4
fi

if [[ -z "${CPU_CORES:-}" ]] || ! [[ "${CPU_CORES}" =~ ^[0-9]+$ ]]; then
  CPU_CORES=4
fi

OPTIMAL_JOBS=$((CPU_CORES + 1))
if [[ ${OPTIMAL_JOBS} -gt 8 ]]; then
  OPTIMAL_JOBS=8
fi

SOURCE_DIR="${SCRIPT_DIR}"
BUILD_DIR_ABS="${SOURCE_DIR}/${BUILD_DIR}"

mkdir -p "${BUILD_DIR_ABS}"
cd "${BUILD_DIR_ABS}"

CMAKE_ARGS=("${SOURCE_DIR}" "-DCMAKE_BUILD_TYPE=${BUILD_TYPE}")

cmake "${CMAKE_ARGS[@]}"

echo "[INFO] Building with ${OPTIMAL_JOBS} parallel jobs (detected ${CPU_CORES} CPU cores)"
cmake --build . -j${OPTIMAL_JOBS}

echo "[INFO] Build finished. Configuration: ${BUILD_TYPE}. Build dir: ${BUILD_DIR_ABS}"
echo "[INFO] Libraries: ${SOURCE_DIR}/output/lib"
echo "[INFO] Binaries:  ${SOURCE_DIR}/output/bin"
