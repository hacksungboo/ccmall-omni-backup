# CCmall: Omni-Backup

IaC 기반 데이터 자동 백업 및 복구 시스템 구축 프로젝트입니다.  
하이브리드 클라우드 환경에서 Terraform, Ansible, GitHub Actions, Prometheus/Grafana를 활용해 백업, 복구, 모니터링, 배포 자동화를 구현합니다.

## 프로젝트 소개
- 서비스명: CCmall (물류 기반 이커머스 서비스)
- 프로젝트 목표: 장애 상황에서도 서비스가 유지될 수 있는 자동 백업/복구 체계 구축
- 핵심 기술: AWS, VMware, Terraform, Ansible, FastAPI, PostgreSQL, Docker, Prometheus, Grafana, GitHub Actions

## 진행 방식
- 주차별 목표를 먼저 정리합니다.
- 매일 오늘의 할 일을 정하고 담당자를 배정합니다.
- 각자는 본인 로컬 환경 또는 개인 AWS/VM 환경에서 먼저 구현하고 검증합니다.
- 문제가 생기면 바로 공유하고, 마지막에는 결과를 문서화합니다.
- 매일 마지막 1시간은 공유, 문서화, 다음 날 할 일 정리에 사용합니다.

## 협업 규칙
- main 브랜치는 팀장만 직접 푸시합니다.
- 팀원은 feature 브랜치에서 작업 후 PR을 올립니다.
- PR에는 작업 내용, 테스트 방법, 관련 이슈를 꼭 작성합니다.
- 커밋 메시지는 통일된 형식을 사용합니다.

## 커밋 메시지 규칙
형식: `type: 설명`

예시:
- feat: 재고관리 API 구현
- fix: DB 연결 오류 수정
- docs: README 업데이트
- test: 백업 스크립트 테스트 추가
- chore: 환경설정 파일 정리

## 브랜치 규칙
- main: 최종 통합 브랜치
- feature/기능명: 기능 개발
- fix/버그명: 버그 수정
- docs/문서명: 문서 작업
- refactor/대상: 리팩토링

## 문서
- 계획서 및 회의록: Notion
- 코드 및 설정: GitHub
- 아키텍처 / 배포 / 모니터링 문서: docs 폴더 관리