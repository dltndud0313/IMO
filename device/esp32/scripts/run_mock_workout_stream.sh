#!/usr/bin/env bash
# Raspberry Pi/Ubuntu에서 ESP32 없이 mock 운동 스트림을 생성한다.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="$(mktemp -d)"
trap 'rm -rf "${BUILD_DIR}"' EXIT

g++ -std=c++17 \
  -I"${ROOT_DIR}/firmware/include" \
  "${ROOT_DIR}/firmware/src/packet.cpp" \
  "${ROOT_DIR}/firmware/src/emg_filter.cpp" \
  "${ROOT_DIR}/firmware/src/imu_processor.cpp" \
  "${ROOT_DIR}/firmware/src/state_machine.cpp" \
  "${ROOT_DIR}/firmware/src/sensor_mock.cpp" \
  "${ROOT_DIR}/firmware/src/transport_serial.cpp" \
  "${ROOT_DIR}/firmware/src/runtime_pipeline.cpp" \
  "${ROOT_DIR}/firmware/tools/mock_stream_main.cpp" \
  -o "${BUILD_DIR}/mock_stream_main"

"${BUILD_DIR}/mock_stream_main" "$@"
