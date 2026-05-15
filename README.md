# 🐝 Hornet AI Detection Project

벌통 주변 소리를 AI가 분석하여  
꿀벌 소리와 말벌 접근 소리를 구분하고,  
말벌 접근 상황을 조기에 감지하는 AI 사운드 분석 프로젝트입니다.

---

## 📌 프로젝트 소개

최근 말벌의 벌통 침입으로 인해 꿀벌 개체 수 감소와 양봉 산업 피해가 증가하고 있습니다.

기존 방식은 사람이 직접 벌통을 관찰하거나 수동 방제에 의존하기 때문에  
실시간 대응이 어렵다는 한계가 있습니다.

본 프로젝트는 벌통 주변의 소리를 수집하고,  
이를 Spectrogram, FFT, WaveForm 이미지로 변환한 뒤 CNN 모델을 통해  
말벌 접근 여부를 분류하는 것을 목표로 합니다.

---
## ✨ 주요 기능

### 🎧 AI 사운드 분석
- 꿀벌 및 말벌 소리 데이터 분석
- WAV 오디오 파일 기반 전처리
- FFT / Spectrogram / WaveForm기반 시각화

### 🧠 CNN 기반 오디오 분류
- 오디오 데이터를 FFT / Spectrogram / WaveForm 이미지로 변환
- CNN 모델을 활용한 Bee / Hornet 이진 분류
- Grad-CAM을 활용한 모델 판단 영역 시각화

### 📱 Flutter 앱 연동
- 벌통 상태 확인 UI 구현
- 말벌 감지 시 경고 화면 표시
- 탐지 신뢰도 및 감지 로그 확인

### ☁️ 서버 및 API 연동
- FastAPI 기반 예측 서버 구조
- 앱과 서버 간 데이터 통신
- 감지 결과 전달 및 상태 관리

---

## ⚒️ 기술 스택

| 분야 | 기술 |
| --- | --- |
| Language | Python, Dart |
| AI / ML | TensorFlow, Keras, CNN |
| Audio Processing | Librosa, FFT, Spectrogram, WaveForm |
| Backend | FastAPI |
| App | Flutter |
| Visualization | Matplotlib, Grad-CAM |
| Version Control | GitHub |

---

## 🏗️ 시스템 구조

```text
🎙️ 벌통 주변 소리 수집
        ↓
🎧 오디오 전처리
        ↓
📊 소리 이미지 변환
        ↓
🧠 CNN 모델 분류
        ↓
☁️ FastAPI 서버
        ↓
📱 Flutter 앱 경고 표시

---
📈 기대 효과
말벌 접근 조기 감지
벌통 피해 예방
양봉 관리 효율 향상
사람이 직접 관찰해야 하는 부담 감소
AI 기반 스마트 양봉 시스템 확장 가능
