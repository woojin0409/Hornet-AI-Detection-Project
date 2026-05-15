import sounddevice as sd
import numpy as np
import requests
import base64
import wave
import io
import time
import json
import os
from datetime import datetime
from config import API_KEY

# --- [1. 설정 및 경로] ---
SAMPLE_RATE = 22050
DURATION = 2.0
DEVICE_ID = 1
SERVER_URL = "http://34.81.221.132:8000/v1/predict"
BASE_URL = "http://34.81.221.132:8000"
CONFIG_FILE = "edge_config.json"

# --- [2. 벌통 ID 자동 등록/로드 함수] ---
def get_registered_id():
    if os.path.exists(CONFIG_FILE):
        with open(CONFIG_FILE, 'r') as f:
            config = json.load(f)
            print(f"[*] 기존 등록된 벌통: {config.get('hive_id')}")
            return config.get("hive_id")

    # 서버에서 벌통 목록 조회
    try:
        response = requests.get(
            f"{BASE_URL}/v1/devices",
            params={"user_id": "khivemind"},
            headers={"x-api-key": API_KEY},
            timeout=5
        )
        devices = response.json().get("devices", [])
    except Exception as e:
        print(f"서버 연결 실패: {e}")
        devices = []

    if not devices:
        print("등록된 벌통이 없습니다. 앱에서 먼저 벌통을 추가해주세요.")
        exit()

    print("\n등록된 벌통 목록:")
    for i, d in enumerate(devices):
        print(f"  {i+1}. {d['device_name']} (ID: {d['device_id']})")

    choice = input("\n연결할 벌통 번호 선택: ").strip()
    try:
        selected = devices[int(choice) - 1]
    except:
        print("잘못된 입력입니다.")
        exit()

    with open(CONFIG_FILE, 'w') as f:
        json.dump({
            "hive_id": selected['device_id'],
            "hive_name": selected['device_name'],
            "registered_at": datetime.now().isoformat()
        }, f)

    print(f"✅ {selected['device_name']} 등록 완료!\n")
    return selected['device_id']

# --- [3. 오디오 처리 관련 함수들] ---
def record_audio():
    audio = sd.rec(
        int(DURATION * SAMPLE_RATE),
        samplerate=SAMPLE_RATE,
        channels=1,
        dtype='int16',
        device=DEVICE_ID
    )
    sd.wait()
    return audio

def audio_to_base64(audio):
    buffer = io.BytesIO()
    with wave.open(buffer, 'wb') as wf:
        wf.setnchannels(1)
        wf.setsampwidth(2)
        wf.setframerate(SAMPLE_RATE)
        wf.writeframes(audio.tobytes())
    buffer.seek(0)
    return base64.b64encode(buffer.read()).decode('utf-8')

def is_suspicious_sound(audio_data):
    audio_data = audio_data.flatten()
    fft_vals = np.abs(np.fft.rfft(audio_data))
    freqs = np.fft.rfftfreq(len(audio_data), 1/SAMPLE_RATE)

    wasp_energy = np.mean(fft_vals[(freqs >= 100) & (freqs <= 160)])
    hiss_energy = np.mean(fft_vals[(freqs >= 4000) & (freqs <= 10000)])

    print(f"   [실시간 분석] 말벌: {wasp_energy:.2f} | 꿀벌비명: {hiss_energy:.2f}")

    if wasp_energy > 250000 or hiss_energy > 100000:
        return True
    return False

# --- [4. 메인 실행 루프] ---
HIVE_ID = get_registered_id()
LAST_CHECK_TIME = 0
IS_ENABLED = True

print(f"\n🚀 {HIVE_ID} 벌통 감지 시스템 가동 시작!")
print("-" * 40)

while True:
    current_time = time.time()

    # 30초마다 서버에서 활성화 상태 확인
    if current_time - LAST_CHECK_TIME > 30:
        try:
            response = requests.get(
                f"{BASE_URL}/v1/devices",
                params={"user_id": "khivemind"},
                headers={"x-api-key": API_KEY},
                timeout=3
            )
            if response.status_code == 200:
                devices = response.json().get("devices", [])
                for d in devices:
                    if d['device_id'] == HIVE_ID:
                        IS_ENABLED = d.get('is_enabled', True)
                        break
            LAST_CHECK_TIME = current_time
        except:
            pass

    if not IS_ENABLED:
        print(f"[{datetime.now().strftime('%H:%M:%S')}] ⏸️ 서버 설정: 감지 중지(OFF)")
        time.sleep(5)
        continue

    audio = record_audio()

    if not is_suspicious_sound(audio):
        print(f"[{datetime.now().strftime('%H:%M:%S')}] 🍃 평온함 (전송 생략)")
        continue

    print(f"[{datetime.now().strftime('%H:%M:%S')}] 🚨 의심 신호! 서버 분석 요청...")
    wav_base64 = audio_to_base64(audio)

    try:
        response = requests.post(
            SERVER_URL,
            headers={"x-api-key": API_KEY},
            json={
                "device_id": HIVE_ID,
                "event_time": datetime.now().isoformat(),
                "wav_base64": wav_base64
            },
            timeout=10
        )
        if response.status_code == 200:
            print("   ㄴ ✅ 분석 성공")
        else:
            print(f"   ㄴ ❌ 서버 오류 ({response.status_code})")
    except Exception as e:
        print(f"   ㄴ ❌ 연결 실패: {e}")