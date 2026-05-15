# utils/bootstrap/main.tf

# version 명시하기
terraform {
  required_version = "~>1.14.0"
  required_providers {
    aws = {
        source  = "hashicorp/aws"
        version = "~> 6.0"
    }
  }
}


# 1. provider 설정
provider "aws" {
    region = "ap-northeast-2" # 서울 리전
}


# s3 버킷 설정
resource "random_id" "bucket_suffix" {
    byte_length = 4
}


# s3 버킷 정의하기
resource "aws_s3_bucket" "tfstate_bucket" {
    bucket = "ccmall-tfstate-bucket-${random_id.bucket_suffix.hex}"
}

# dynamo db 정의하기
resource "aws_dynamodb_table" "terraform_lock" {
    name = "ccmall-terraform-lock"
    billing_mode = "PAY_PER_REQUEST"
    hash_key = "LockID"

    # 속성을 이용해서  
    attribute{
        name = "LockID"
        type = "S"
    }
    tags = {
        Name = "Terraform State Lock Table"
    }
}
