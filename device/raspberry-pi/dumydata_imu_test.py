import time

def analyze_gym_posture(cycle, timestamp, ay, emg_value):
    """
    안경 IMU 데이터를 활용한 한국어 실시간 자세 분석
    """
    # 상태 판별 기준
    is_exercising = emg_value > 0.35
    is_head_down = ay > 0.15
    
    # 한국어 상태 메시지 설정
    if is_exercising:
        if is_head_down:
            status = "경고: 고개 숙임! 정면을 보세요"
        else:
            status = "정석: 아주 좋은 자세입니다"
    else:
        if is_head_down:
            status = "주의: 휴식 중 거북목 감지"
        else:
            status = "대기: 다음 세트 준비 중"

    # 출력 형식 정리
    print(f"[세트 {cycle}] {timestamp:4}ms | 근력: {emg_value:.2f} | 기울기: {ay:.2f} | 상태: {status}")

def run_simulation():
    print("-" * 80)
    print("EMG-GLASS 운동 자세 실시간 모니터링 (3회 반복)")
    print("-" * 80)

    # 3번의 사이클(세트) 반복
    for cycle in range(1, 4):
        print(f"\n>>> {cycle}번째 운동 세트 시작")
        print("-" * 80)
        
        # 0ms부터 4000ms까지 200ms 간격으로 한 주기 실행
        for ms in range(0, 4001, 200):
            phase = (ms % 4000) / 4000.0
            
            # 근전도(EMG) 더미 데이터 생성
            if phase < 0.2: envelope = 0.08
            elif phase < 0.4: envelope = 0.08 + ((phase - 0.2) / 0.2) * 0.72
            elif phase < 0.7: envelope = 0.80
            elif phase < 0.9: envelope = 0.80 - ((phase - 0.7) / 0.2) * 0.60
            else: envelope = 0.12
            
            # 안경 기울기(ay) 데이터 생성
            ay = 0.20 * envelope
            
            analyze_gym_posture(cycle, ms, ay, envelope)
            time.sleep(0.1) # 실시간 느낌을 위해 0.1초 대기

    print("\n" + "-" * 80)
    print("목표한 3세트 운동 모니터링이 완료되었습니다. 수고하셨습니다!")
    print("-" * 80)

if __name__ == "__main__":
    run_simulation()