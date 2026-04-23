import serial
import time
import struct

SERIAL_PORT = '/dev/ttyUSB0' 
BAUD_RATE = 115200

def analyze_posture(ax, ay):
    """
    해독된 위치의 AX, AY 값을 바탕으로 상태 판별
    """
    status = []
    # AY (고개 앞뒤): 평소 900~1000 근처. 숙이면 숫자가 확 변함
    if ay > 1200:
        status.append("고개 숙임 ⚠️")
    elif ay < 700:
        status.append("하늘 주시 👀")

    # AX (좌우 기울기): 평소 0 근처. 기울이면 +- 수백 단위 변화
    if ax > 500:
        status.append("오른쪽 기울어짐 ❌")
    elif ax < -500:
        status.append("왼쪽 기울어짐 ❌")

    return " / ".join(status) if status else "정면 주시 중 ✅"

def run_final_system():
    try:
        py_serial = serial.Serial(port=SERIAL_PORT, baudrate=BAUD_RATE, timeout=0.1)
        print("=" * 60)
        print("스마트 안경 실시간 자세 분석 시스템 (최종 해독본)")
        print("=" * 60)

        buffer = bytearray()

        while True:
            if py_serial.in_waiting > 0:
                buffer.extend(py_serial.read(py_serial.in_waiting))

                # 'ME' 헤더를 기준으로 동기화
                while b'ME' in buffer:
                    header_idx = buffer.find(b'ME')
                    
                    # 패킷 전체 길이(39바이트)가 채워질 때까지 대기
                    if len(buffer) < header_idx + 39:
                        break
                    
                    try:
                        # [핵심] 해독된 진짜 오프셋 적용
                        # AX는 헤더+22바이트, AY는 헤더+24바이트 지점에 위치함
                        ax_raw = struct.unpack('<h', buffer[header_idx+22 : header_idx+24])[0]
                        ay_raw = struct.unpack('<h', buffer[header_idx+24 : header_idx+26])[0]
                        
                        # 상태 분석
                        current_status = analyze_posture(ax_raw, ay_raw)
                        
                        # 실시간 출력
                        print(f"\r[상태] {current_status:30s} | AX:{ax_raw:5d} AY:{ay_raw:5d}", end="")

                    except Exception:
                        pass
                    
                    # 처리한 패킷 삭제 및 다음 헤더 추적
                    del buffer[:header_idx + 1]

            time.sleep(0.01)

    except Exception as e:
        print(f"\n시스템 오류: {e}")
    except KeyboardInterrupt:
        print("\n\n사용자에 의해 종료되었습니다.")

if __name__ == "__main__":
    run_final_system()