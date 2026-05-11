# ccmall 시스템 아키텍처

## 프로젝트 개요

온프렘 DB를 메인으로 운영하고 클라우드에 예비 DB를 두는 하이브리드 구조입니다.
온프렘 DB 장애 시 예비 DB를 자동 승격시켜 최단 시간 내 서비스를 복구하는 것이 목표입니다.

---

## 전체 구조도

```
                        [사용자]
                           │
                      [Cloudflare]
                      DNS / Failover
                           │
                      [EC2-1]  ← Public 서브넷 (공인 IP)
                       nginx
                       FastAPI + Jinja2
                           │
              ┌────────────┴────────────┐
           평상시                     장애시
              │                         │
        [온프렘 DB]               [EC2-2 DB]
         메인 PostgreSQL           예비 PostgreSQL
         (로컬 서버)               Private 서브넷
              │                         ▲
              ├──── 주기적 백업 ────────┘
              │     (APScheduler)
              │
              └──── 콜드 데이터 이관 ──→ [S3]
                    (3개월↑)               ├─ 주문내역
                                          ├─ 사진 리뷰
                                          └─ 로그 (nginx/FastAPI/DB)

📊 모니터링: Prometheus + Grafana
🔐 네트워크: Tailscale VPN (온프렘 ↔ EC2)
🔒 IaC 상태: S3 (tfstate) + DynamoDB (lock)
```

---

## 컴포넌트 설명

### EC2-1 (웹 서버) - Public 서브넷
- nginx: 리버스 프록시
- FastAPI + Jinja2: 백엔드 및 HTML 렌더링
- 평상시 온프렘 DB와 통신

### EC2-2 (예비 DB 서버) - Private 서브넷
- PostgreSQL: 예비 DB (온프렘 DB 백업 수신)
- 외부 직접 접근 불가, EC2-1 통해 점프 접속
- 온프렘 DB 장애 시 Primary로 승격

### 온프렘 (로컬 서버)
- PostgreSQL: 메인 DB (Primary)
- APScheduler: EC2-2 백업 + S3 콜드 데이터 이관
- Tailscale VPN으로 EC2와 통신
- Prometheus + Grafana: 모니터링

### S3
- `ccmall-tfstate`: Terraform 상태파일 저장
- `ccmall-backup`: 콜드 데이터 저장 (주문내역, 사진 리뷰, 로그)
- 사진 리뷰는 업로드 즉시 S3 저장, DB에는 URL만 보관

### DynamoDB
- `ccmall-terraform-lock`: Terraform 상태 잠금 (동시 실행 방지)

### Cloudflare
- DNS 관리 및 장애 감지 시 Failover

### Tailscale VPN
- 온프렘 ↔ EC2 프라이빗 네트워크 구성

---

## 네트워크 구조

```
[사용자] ──→ EC2-1 (Public, 공인 IP)

온프렘
  └── Tailscale VPN ──→ EC2-1 (Public)
                    └──→ EC2-2 (Private, EC2-1 통해 점프 접속)

EC2-1 ──→ EC2-2 (VPC 내부)
EC2-1 ──→ S3 ccmall-backup (이미지 URL 참조)
온프렘 ──→ S3 ccmall-backup (콜드 데이터 이관)
온프렘 ──→ S3 ccmall-tfstate (tfstate 저장)
EC2-2 ──→ S3 ccmall-backup (복구 시 다운로드)
```

---

## 데이터 계층 전략

| 데이터 | 저장 위치 | 이관 기준 |
|--------|---------|---------|
| 회원 정보 | 온프렘 DB + EC2-2 | - |
| 상품 / 재고 | 온프렘 DB + EC2-2 | - |
| 진행중 주문 | 온프렘 DB + EC2-2 | - |
| 3개월↑ 주문내역 | S3 ccmall-backup | 매일 새벽 자동 이관 |
| 사진 리뷰 | S3 ccmall-backup | 업로드 즉시 S3 저장 |
| 3개월↑ 로그 | S3 ccmall-backup | 매일 새벽 자동 이관 |

---

## CI/CD 흐름

```
개발자
git push origin master
        │
        ▼
GitHub Actions (ubuntu 임시 서버)
        │
        ├─ 1. AWS 인증 (Secrets)
        │
        ├─ 2. 코드 체크아웃
        │
        ├─ 3. Terraform apply
        │      └─ EC2-Web, EC2-Rec 생성
        │      └─ inventory.yml, ansible.cfg 자동 생성
        │      └─ 60초 대기 (EC2 부팅)
        │
        ├─ 4. SSH 키 설정
        │      └─ Secrets에서 꺼내서 ~/.ssh/ansiblekey.pem 저장
        │
        ├─ 5. Ansible 실행
        │      ├─ ec2_bootstrap.yml  (user1 생성)
        │      ├─ setting/main.yml   (nginx, FastAPI 설치)
        │      └─ monitoring/playbook.yml (Prometheus, Grafana)
        │
        ├─ 6. Tailscale 설치
        │      └─ EC2-Web, EC2-Rec Tailscale 네트워크 등록
        │
        └─ 완료 ✅ (ubuntu 임시 서버 사라짐)


```

---

## 장애 복구 시나리오

```
1. 온프렘 DB 장애 감지 (Prometheus Alert)
2. EC2-2 DB → Primary 승격 (Ansible)
3. EC2-1 DB 연결 정보 → EC2-2로 전환
4. 서비스 정상화 ✅
5. 온프렘 복구 후 재동기화
```

---

## 기술 스택

| 분류 | 기술 |
|------|------|
| 인프라 | Terraform, AWS (EC2, S3, VPC, DynamoDB) |
| 서버 설정 자동화 | Ansible |
| 웹 서버 | nginx |
| 백엔드 | FastAPI + Jinja2 (Python 3.11) |
| 데이터베이스 | PostgreSQL |
| 백업 / 이관 | APScheduler, boto3 |
| 모니터링 | Prometheus, Grafana |
| VPN | Tailscale |
| DNS / Failover | Cloudflare |
| CI/CD | GitHub Actions |

---

## 폴더 구조

```
ccmall-omni-backup/
├── app/
│   ├── api/
│   ├── core/
│   ├── crud/
│   ├── models/
│   ├── schemas/
│   ├── services/
│   └── tasks/
├── infra/
│   ├── deployment/
│   │   ├── ansible/
│   │   └── terraform/
│   ├── backup/
│   ├── monitoring/
│   └── recovery/
├── docs/
├── cicd/
├── static/
└── requirements.txt
```