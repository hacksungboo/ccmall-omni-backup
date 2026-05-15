# Amazon Linux 2023 최신 AMI 검색
data "aws_ami" "latest_al2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }
}

# pem 파일 관련 작업
resource "tls_private_key" "ccmall_private_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

# AWS Key Pair 등록
resource "aws_key_pair" "ccmall_key" {
  key_name   = "ccmall-key"
  public_key = tls_private_key.ccmall_private_key.public_key_openssh

  tags = {
    Name = "ccmall-key"
  }
}

# Terraform이 생성하는 초기 접속용 개인키
resource "local_file" "ccmall_ssh_key" {
  filename        = local.ccmall_ssh_key_file
  content         = tls_private_key.ccmall_private_key.private_key_pem
  file_permission = "0600"
}

# 생성된 ccmall-Web의 public ip를 출력
output "web_public_ip" {
  description = "ccmall-Web의 public ipv4 주소"
  value       = aws_instance.ccmall_web.public_ip
}

# 생성된 ccmall-Web의 private ip를 출력
output "web_private_ip" {
  description = "ccmall-Web의 private ipv4 주소"
  value       = aws_instance.ccmall_web.private_ip
}

# 생성된 ccmall-Rec의 private ip를 출력
output "rec_private_ip" {
  description = "ccmall-Rec의 private ipv4 주소"
  value       = aws_instance.ccmall_rec.private_ip
}

# 생성된 s3의 버킷 이름 출력
output "s3_bucket_name" {
  description = "S3 bucket 이름"
  value       = aws_s3_bucket.ccmall_bucket.bucket
}