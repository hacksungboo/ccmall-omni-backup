
# 모니터링 시스템 (Prometheus + Grafana + Alertmanager)

## 개요
CCmall 인프라의 상태를 실시간으로 감시하고 이상 발생 시 알림을 보내는 시스템입니다.
Terraform으로 인프라 생성 후 Ansible Playbook이 자동으로 설치 및 설정합니다.

---

## 구성 요소

| 컴포넌트 | 버전 | 설치 위치 | 역할 |
|----------|------|-----------|------|
| Prometheus | v2.51.0 | mgmt 서버 | 메트릭 수집 및 저장 |
| Grafana | 최신 | mgmt 서버 | 대시보드 시각화 |
| Alertmanager | v0.27.0 | mgmt 서버 | 알림 발송 |
| Node Exporter | v1.7.0 | EC2-Web, EC2-Rec | 서버 메트릭 수집 |

---

## 디렉터리 구조

infra/monitoring/
├── playbook.yml                        # 모니터링 Playbook 진입점
├── sample.txt
└── ansible/
    └── roles/
        └── monitoring/                 # Ansible Role
            ├── tasks/
            │   └── main.yml            # 설치 작업 정의
            ├── files/
            │   ├── prometheus.yml      # Prometheus 설정
            │   └── alert_rules.yml     # 알림 규칙
            └── handlers/
                └── main.yml            # 서비스 재시작 핸들러

---

## 자동화 흐름

terraform apply
    ↓ EC2-Web, EC2-Rec 생성
    ↓ inventory.yml 자동 생성
    ↓ ansible.cfg 자동 생성
    ↓ (depends_on으로 순서 보장)
    ↓ 60초 대기 (EC2 SSH 준비)
    ↓
ansible-playbook monitoring/playbook.yml 자동 실행
    ↓
mgmt   : Prometheus + Grafana + Alertmanager 설치
EC2-Web: Node Exporter 설치
EC2-Rec: Node Exporter 설치

---

## 설치 방법

### 자동 실행 (권장)
terraform apply -auto-approve

### 수동 실행
ANSIBLE_CONFIG=~/ccmall-omni-backup/infra/ansible.cfg \
ansible-playbook monitoring/playbook.yml \
  --private-key infra/deployment/terraform/ccmall-key.pem \
  -v

---

## 서비스 포트

| 서비스 | 포트 | 접속 주소 |
|--------|------|-----------|
| Prometheus | 9090 | http://mgmt-ip:9090 |
| Grafana | 3000 | http://mgmt-ip:3000 |
| Alertmanager | 9093 | http://mgmt-ip:9093 |
| Node Exporter | 9100 | http://서버-ip:9100 |

---

## 서비스 상태 확인

systemctl status prometheus
systemctl status grafana-server
systemctl status alertmanager

---

## 설정 파일 위치

| 파일 | 위치 |
|------|------|
| Prometheus 설정 | /etc/prometheus/prometheus.yml |
| 알림 규칙 | /etc/prometheus/alert_rules.yml |
| Alertmanager 설정 | /etc/alertmanager/alertmanager.yml |
| Grafana 설정 | /etc/grafana/grafana.ini |

---

## 감시 항목

| 항목 | 임계값 | 알림 |
|------|--------|------|
| CPU 사용률 | 90% 이상 | Alertmanager |
| 메모리 사용률 | 90% 이상 | Alertmanager |
| 디스크 사용률 | 85% 이상 | Alertmanager |
| 서비스 다운 | 감지 즉시 | Alertmanager |
| DB 접속 불가 | 감지 즉시 | Alertmanager |
| 백업 실패 | 감지 즉시 | Alertmanager |

---

## 트러블슈팅

### Alertmanager failed 상태일 때
sudo mkdir -p /var/lib/alertmanager
sudo chown prometheus:prometheus /var/lib/al
---

## 실행 경로

### Terraform (인프라 배포)
cd ~/ccmall-omni-backup/infra/deployment/terraform
terraform apply -auto-approve

### Ansible (수동 실행 시)
cd ~/ccmall-omni-backup/infra
ANSIBLE_CONFIG=~/ccmall-omni-backup/infra/ansible.cfg \
ansible-playbook monitoring/playbook.yml \
  --private-key ~/ccmall-omni-backup/infra/deployment/terraform/ccmall-key.pem \
  -v

---

## 실행 옵션 설명

| 옵션 | 설명 |
|------|------|
| -auto-approve | terraform 확인 없이 바로 실행 |
| --private-key | EC2 접속용 pem 파일 경로 지정 |
| -v | Ansible 상세 로그 출력 (verbose) |
| ANSIBLE_CONFIG | 사용할 ansible.cfg 파일 명시적 지정 |

---

## 주요 변수 위치

| 변수 | 파일 위치 |
|------|-----------|
| Prometheus 스크랩 대상 (IP, 포트) | /etc/prometheus/prometheus.yml |
| 알림 규칙 (임계값) | /etc/prometheus/alert_rules.yml |
| Alertmanager 수신자 설정 (Telegram 등) | /etc/alertmanager/alertmanager.yml |
| Ansible inventory (서버 IP) | ~/ccmall-omni-backup/infra/inventory/inventory.yml |
| SSH 접속 키 | ~/ccmall-omni-backup/infra/deployment/terraform/ccmall-key.pem |
