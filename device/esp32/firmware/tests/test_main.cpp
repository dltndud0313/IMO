// Ubuntu에서 한 번에 실행할 수 있도록 host-side 테스트를 단일 바이너리로 묶는 파일.
#include <iostream>

void run_test_packet();
void run_test_emg_filter();
void run_test_calibration();
void run_test_state_machine();
void run_test_sensor_mock();

int main() {
    run_test_packet();
    run_test_emg_filter();
    run_test_calibration();
    run_test_state_machine();
    run_test_sensor_mock();
    std::cout << "[PASS] firmware host-side tests completed\n";
    return 0;
}
