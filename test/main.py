from fastapi import FastAPI
from pydantic import BaseModel
import firebase_admin
from firebase_admin import credentials, messaging

app = FastAPI()

alerts = []

# Firebase Admin 초기화
cred = credentials.Certificate("hivemind-9a13f-firebase-adminsdk-fbsvc-a1a60d1013.json")
firebase_admin.initialize_app(cred)

class Alert(BaseModel):
    hive_id: int
    status: str
    hz: float
    timestamp: str

@app.get("/alerts")
def get_alerts():
    return alerts

@app.post("/alerts")
def post_alert(alert: Alert):
    alerts.append(alert.dict())

    # FCM 알림 전송
    message = messaging.Message(
        notification=messaging.Notification(
            title=f"🐝 벌통 {alert.hive_id}번 이상 감지!",
            body=f"말벌 감지 - {alert.hz}Hz ({alert.timestamp})",
        ),
        data={
            'hive_id': str(alert.hive_id),
        },
        token="cCvMVg8HRIOfTHGWnH9urg:APA91bGZH_BtWDS6u0nBYIT3f5yItL6BkkMUnN0npUk-RQSPMedF19f8p5_3i4w3qE7xdz42TjdPaTu9DYSz4eixt0wvZKQp4lwS_OedLIg7xSb6Gjp4v-w",
    )
    messaging.send(message)

    return {"message": "저장 및 알림 전송 완료"}