# infra/deployment/terraform/provider.tf
# AWS에 Web, Rec 서버를 provisioning한다.

# 2026.05.18 14:37 CI/CD 테스트용 주석 수정

terraform {
  required_version = ">= 1.14.0, < 2.0.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }

    # --- tailscale provider 추가
    tailscale = {
      source  = "tailscale/tailscale"
      version = "0.17.2"
    }

    # --- cloudflare provider 추가
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 4.0"
    }

  }
  # terraform 상태관리 (CI/CD)
  backend "s3" {
    bucket         = "ccmall-tfstate-bucket-f16ce1d4"
    key            = "deployment/terraform.tfstate"
    region         = "ap-northeast-2"
    dynamodb_table = "ccmall-terraform-lock" # 미리 준비된 dynamodb 테이블
    encrypt        = true
  }
}

# --- tailscale api 키는 일단 tfvars에 보관.
provider "tailscale" {
  api_key = var.tailscale_api_key
  tailnet = var.tailnet_name
}

# 1. provider 설정
provider "aws" {
  region = "ap-northeast-2" # 서울 리전
}

# --- cloudflare api 키는 일단 tfvars에 보관.
provider "cloudflare" {
  api_token = var.cloudflare_api_token
}