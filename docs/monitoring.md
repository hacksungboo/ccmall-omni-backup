# 모니터링 시스템

## 개요
CCmall 인프라의 상태를 실시간으로 감시하고 이상 발생 시 Telegram으로 알림을 보내는 시스템입니다.
Prometheus가 각 서버의 메트릭을 수집하고, Alertmanager가 Telegram으로 알림을 발송합니다.

---

## 구성 요소

| 컴포넌트 | 버전 | 설치 위치 | 역할 |
|----------|------|-----------|------|
| Prometheus | v2.51.0 | mgmt 서버 | 메트릭 수집 및 알림 규칙 평가 |
| Grafana | 최신 | mgmt 서버 | 대시보드 시각화 |
| Alertmanager | v0.27.0 | mgmt 서버 | Telegram 알림 발송 |
| Node Exporter | v1.7.0 | 전체 서버 | 서버 메트릭 노출 |

---

## 모니터링 대상 서버

| Job명 | 대상 서버 | IP | 비고 |
|-------|-----------|-----|------|
| mgmt | mgmt 서버 (VMware) | localhost:9100 | 상시 운영 |
| web | EC2-Web | 10.0.1.10:9100 | 상시 운영 |
| onprem-db | rocky01 메인 DB (VMware) | 10.0.2.20:9100 | 상시 운영 |
| ec2-db-1 | 예비 DB 서버 (AWS) | IP 미정:9100 | 상시 운영 |
| ec2-db-2 | 장애 복구 DB 서버 (AWS) | IP 미정:9100 | 장애시만 운영 |

---

## 알림 규칙

| 항목 | 임계값 | 심각도 | 알림 대상 |
|------|--------|--------|-----------|
| CPU 사용률 | 90% 이상 1분 지속 | warning | Telegram |
| 메모리 사용률 | 90% 이상 1분 지속 | warning | Telegram |
| 디스크 사용률 | 85% 이상 1분 지속 | warning | Telegram |
| 서비스 다운 | 감지 즉시 | critical | Telegram |
| DB 접속 불가 | 감지 즉시 | critical | Telegram |
| 백업 실패 | 24시간 이상 | critical | Telegram |
| 온프레미스 DB 다운 | 감지 즉시 | critical | Telegram |
| 예비 DB 다운 | 감지 즉시 | critical | Telegram |

---

## 접속 주소

| 서비스 | 접속 주소 |
|--------|-----------|
| Prometheus | http://172.16.8.200:9090 |
| Grafana | http://172.16.8.200:3000 |
| Alertmanager | http://172.16.8.200:9093 |

---

## 실행 방법

### Terraform으로 자동 실행 (권장)
terraform apply 실행 시 EC2 생성 완료 후 Ansible이 자동으로 모니터링을 설치합니다.

cd ~/ccmall-omni-backup/infra/deployment/terraform
terraform apply

### Ansible 수동 실행
설정 변경 후 모니터링만 재배포할 때 사용합니다.

cd ~/ccmall-omni-backup
ANSIBLE_ROLES_PATH=infra/monitoring/ansible/roles \
ansible-playbook infra/monitoring/playbook.yml

---

## 서비스 상태 확인

systemctl status prometheus
systemctl status grafana-server
systemctl status alertmanager