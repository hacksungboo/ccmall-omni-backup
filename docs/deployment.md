# ccmall 배포 매뉴얼

## 사전 준비 (최초 1회)

### GitHub Secrets 등록

```
레포지토리 → Settings → Secrets and variables → Actions → New repository secret
```

| Secret | 설명 |
|--------|------|
| `AWS_ACCESS_KEY_ID` | AWS IAM 액세스 키 |
| `AWS_SECRET_ACCESS_KEY` | AWS IAM 시크릿 키 |
| `SSH_PRIVATE_KEY` | EC2 접속용 SSH 개인키 |
| `TAILSCALE_AUTHKEY` | Tailscale VPN 인증 키 |

### Python 패키지 설치

```bash
# 경로: ccmall-omni-backup/
pip install -r requirements.txt
```

---

## 인프라 배포 순서

### 1단계: S3 + DynamoDB 생성 (최초 1회)

```bash
cd ccmall-omni-backup/infra/deployment/terraform/init
terraform init
terraform apply --auto-approve
```

생성되는 리소스:
- S3: `ccmall-tfstate` (Terraform 상태파일)
- S3: `ccmall-backup` (콜드 데이터 / 백업)
- DynamoDB: `ccmall-terraform-lock` (동시 실행 방지)

### 2단계: 메인 인프라 배포

```bash
cd ccmall-omni-backup/infra/deployment/terraform
terraform init
terraform plan
terraform apply --auto-approve
```

생성되는 리소스:
- EC2-Web (Public 서브넷)
- EC2-Rec (Private 서브넷)
- VPC, 서브넷, 보안그룹

배포 후 자동 생성 파일:
```
ccmall-omni-backup/infra/
├── inventory/inventory.yml   ← EC2 IP 자동 입력
└── ansible.cfg               ← Ansible 설정
```

### 3단계: Ansible Playbook 실행

```bash
cd ccmall-omni-backup/infra/deployment/ansible

# EC2 초기 세팅 (user1 생성, SSH 키 등록)
ansible-playbook ec2_bootstrap.yml

# 서버 패키지 설치 (nginx, FastAPI 등)
ansible-playbook setting/main.yml

# 모니터링 설치 (Prometheus, Grafana)
ansible-playbook monitoring/playbook.yml
```

### 4단계: Tailscale VPN 설정

**EC2에 설치 (Ansible):**
```bash
cd ccmall-omni-backup/infra/deployment/ansible
ansible-playbook setting/tasks/tailscale_setup.yml
```

**온프렘 서버에 설치:**
```bash
curl -fsSL https://tailscale.com/install.sh | sh
sudo tailscale up --authkey=<TAILSCALE_AUTHKEY>
```

**연결 확인:**
```bash
tailscale status
# 100.64.0.1  EC2-Web   online
# 100.64.0.2  EC2-Rec   online
# 100.64.0.3  onprem    online
```

> Tailscale 연결 완료 후 `inventory.yml`의 `onprem_db` 주석을 해제하세요.

---

## 설정 파일 위치

### Terraform 주요 변수

| 항목 | 파일 경로 | 값 |
|------|----------|----|
| tfstate S3 버킷 | `terraform/main.tf` → `backend "s3"` | `ccmall-tfstate` |
| DynamoDB 잠금 | `terraform/main.tf` → `dynamodb_table` | `ccmall-terraform-lock` |
| AWS 리전 | `terraform/main.tf` → `provider "aws"` | `ap-northeast-2` |
| EC2 타입 | `terraform/main.tf` → `instance_type` | `t3.micro` |

### 환경변수

```
파일 경로: ccmall-omni-backup/.env
```

```
DB_HOST=<온프렘 DB IP>
DB_PORT=5432
DB_NAME=ccmall_db
DB_USER=postgres
AWS_S3_BUCKET=ccmall-backup
AWS_REGION=ap-northeast-2
```

---

## CI/CD 자동 배포 (GitHub Actions)

```bash
git push origin master
```

워크플로우 파일 경로: `ccmall-omni-backup/cicd/workflow.yml`

### workflow.yml 구조

  → ① AWS 인증
  → ② 코드 체크아웃
  → ③ Terraform (EC2 생성)
  → ④ SSH 키 설정
  → ⑤ Ansible Bootstrap
  → ⑥ Ansible 서버 설치
  → ⑦ Ansible 모니터링
  → ⑧ Tailscale 설치