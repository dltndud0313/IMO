// 외부 테스트 프레임워크 없이도 검증할 수 있도록 만든 간단한 assert 헬퍼.
#pragma once

#include <cmath>
#include <cstdlib>
#include <iostream>
#include <string>

inline void expect_true(bool condition, const std::string& message) {
    if (!condition) {
        std::cerr << "[FAIL] " << message << '\n';
        std::exit(1);
    }
}

inline void expect_near(float actual, float expected, float tolerance, const std::string& message) {
    if (std::fabs(actual - expected) > tolerance) {
        std::cerr << "[FAIL] " << message << " expected=" << expected << " actual=" << actual << '\n';
        std::exit(1);
    }
}
