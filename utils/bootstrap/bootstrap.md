# Bootstrap Guide

이 디렉토리는 Terraform 프로젝트 실행 전에 **remote state 저장소(S3)** 와 **state lock(DynamoDB)** 을 생성하기 위한 초기 설정입니다.

## 목적

Terraform을 GitHub Actions에서 사용할 때 다음 리소스가 필요합니다:

- S3: tfstate 파일 저장
- DynamoDB: state lock 관리 (동시 실행 방지)

이 리소스들은 Terraform으로 관리되기 전에 **먼저 생성되어야 합니다.**

## 실행 방법

```bash
cd utils/bootstrap
terraform init
terraform apply
```

## 생성되는 리소스

- S3 Bucket  
  - 이름: `ccmall-tfstate-bucket-<random_suffix>`
- DynamoDB Table  
  - 이름: `ccmall-terraform-lock`

S3 버킷은 고유한 이름을 위해 random suffix가 붙습니다.

## ⚠️ 중요: S3 이름 반영 필요

Bootstrap 실행 후 생성된 **S3 버킷 이름을 반드시 확인**해야 합니다.

이 값을 아래 파일에 반영해야 합니다:

infra/deployment/terraform/provider.tf

예시:

```hcl
backend "s3" {
  bucket         = "ccmall-tfstate-bucket-xxxxxx"
  key            = "terraform.tfstate"
  region         = "ap-northeast-2"
  dynamodb_table = "ccmall-terraform-lock"
}
```

S3 이름이 다르면 Terraform backend 초기화가 실패합니다.

## 정리

1. bootstrap 실행으로 S3 + DynamoDB 생성
2. 생성된 S3 이름 확인
3. provider.tf에 반영
4. 이후 main Terraform 프로젝트 실행