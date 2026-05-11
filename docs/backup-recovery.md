# ccmall 백업 및 복구 매뉴얼

## 개요

최소 비용으로 최대 가용성을 확보하기 위해 데이터를 계층화하여 관리합니다.
자주 쓰는 데이터는 예비 DB(EC2-2)에, 오래된 데이터는 S3에 보관합니다.

---

## 데이터 계층 전략

```
온프렘 메인 DB
    │
    ├─ 핫 데이터 ──→ EC2-2 백업 (APScheduler)
    │   - 회원 정보, 상품/재고
    │   - 3개월 이내 주문내역
    │   - 진행중 결제
    │
    └─ 콜드 데이터 ──→ S3 이관 후 DB 영구 삭제
        - 3개월↑ 주문내역
        - 로그 (nginx / FastAPI / DB)
```

### 사진 리뷰
```
업로드 즉시 → S3 저장
DB에는 S3 URL만 저장 (별도 이관 불필요)
```

---

## S3 버킷 구조 (ccmall-backup)

```
ccmall-backup/
├── reviews/                    # 사진 리뷰 (업로드 즉시)
│   └── 2026/05/abc.jpg
│
└── cold-data/                  # 3개월↑ 콜드 데이터
    ├── orders/                 # 주문내역 (온프렘 + EC2-2 동시 삭제)
    │   └── 2026-02/
    │       └── orders_2026-02.json
    │
    └── logs/
        ├── ec2-1/              # EC2-1에서 이관
        │   ├── nginx/
        │   │   └── 2026-02/access_2026-02.log
        │   └── fastapi/
        │       └── 2026-02/app_2026-02.log
        └── onprem/             # 온프렘에서 이관
            └── db/
                └── 2026-02/db_2026-02.log
```

---

## APScheduler 자동화

| 작업 | 주기 | 설명 |
|------|------|------|
| 핫 데이터 백업 | 매일 새벽 1시 | 온프렘 DB → EC2-2 동기화 |
| 콜드 데이터 이관 | 매일 새벽 2시 | 3개월↑ 주문내역 → S3 이관 후 DB 삭제 |
| 로그 이관 | 매일 새벽 3시 | 3개월↑ 로그 → S3 이관 |

### S3 이관 흐름 (안전 삭제)

```
새벽 2시
  └─ 3개월↑ 주문내역 조회
       └─ S3 업로드
            ├─ 성공 → 온프렘 DB 삭제 → EC2-2 DB 삭제 ✅
            └─ 실패 → DB 삭제 중단 → 에러 로그 기록 🚨

새벽 3시
  └─ 3개월↑ 로그 파일 조회
       ├─ nginx 로그  → S3/cold-data/logs/ec2-1/nginx/
       ├─ FastAPI 로그 → S3/cold-data/logs/ec2-1/fastapi/
       └─ DB 로그    → S3/cold-data/logs/onprem/db/
```

코드 위치: `app/tasks/scheduler.py`

---

## 수동 백업

```bash
# 온프렘 DB 전체 백업
pg_dump -U postgres ccmall_db > backup_$(date +%Y%m%d).sql

# S3 업로드
aws s3 cp backup_$(date +%Y%m%d).sql s3://ccmall-backup/cold-data/manual/

# 업로드 성공 확인 후 삭제 진행
if aws s3 ls s3://ccmall-backup/cold-data/manual/backup_$(date +%Y%m%d).sql; then
    echo "업로드 성공"
else
    echo "업로드 실패 - 삭제 중단"
    exit 1
fi
```

---

## 장애 복구 절차

### 시나리오: 온프렘 DB 장애

```
1. Prometheus Alert 감지
2. EC2-2 DB → Primary 승격
3. EC2-1 DB 연결 전환 (온프렘 → EC2-2)
4. 서비스 정상화 ✅
5. 온프렘 복구 후 재동기화
```

### Step 1. EC2-2 Primary 승격

```bash
ansible-playbook infra/recovery/promote_db.yml
```

### Step 2. EC2-1 DB 연결 전환

```bash
# .env 수정
DB_HOST=<EC2-2 Private IP>

# FastAPI 재시작
sudo systemctl restart ccmall-api
```

### Step 3. 서비스 확인

```bash
sudo systemctl status nginx
sudo systemctl status ccmall-api
curl http://localhost/health
```

### Step 4. 복구 후 재동기화

```bash
ansible-playbook infra/recovery/resync_db.yml

# .env 원복
DB_HOST=<온프렘 DB IP>
sudo systemctl restart ccmall-api
```

---

## S3에서 오래된 데이터 조회

```bash
# 특정 월 주문내역 다운로드
aws s3 cp s3://ccmall-backup/cold-data/orders/2026-02/ ./ --recursive

# 필요 시 DB 재삽입
psql -U postgres ccmall_db < orders_2026-02.json
```

---

## 주의사항

> ⚠️ S3 이관 데이터는 DB에서 영구 삭제됩니다. 반드시 업로드 성공 확인 후 삭제하세요.

> ⚠️ EC2-2 승격 후 온프렘 DB 복구 시 반드시 재동기화를 수행하세요.