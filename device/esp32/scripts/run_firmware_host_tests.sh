#!/usr/bin/env bash
# ESP-IDF 없이 펌웨어 핵심 로직 테스트를 컴파일/실행해 하드웨어 전 단계 검증을 수행한다.
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
  "${ROOT_DIR}/firmware/src/sensor_analog_emg.cpp" \
  "${ROOT_DIR}/firmware/src/transport_serial.cpp" \
  "${ROOT_DIR}/firmware/src/runtime_pipeline.cpp" \
  "${ROOT_DIR}/firmware/tests/test_main.cpp" \
  "${ROOT_DIR}/firmware/tests/test_packet.cpp" \
  "${ROOT_DIR}/firmware/tests/test_emg_filter.cpp" \
  "${ROOT_DIR}/firmware/tests/test_imu_processor.cpp" \
  "${ROOT_DIR}/firmware/tests/test_state_machine.cpp" \
  "${ROOT_DIR}/firmware/tests/test_sensor_mock.cpp" \
  "${ROOT_DIR}/firmware/tests/test_sensor_analog_emg.cpp" \
  -o "${BUILD_DIR}/firmware_host_tests"

"${BUILD_DIR}/firmware_host_tests"
