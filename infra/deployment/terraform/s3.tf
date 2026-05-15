# infra/deployment/terraform/s3.tf
# S3 버킷명 충돌 방지를 위한 랜덤 suffix
resource "random_id" "ccmall_bucket_suffix" {
  byte_length = 4
}

# 최종 S3 버킷명
resource "aws_s3_bucket" "ccmall_bucket" {
  bucket = "${var.s3_bucket_prefix}-${random_id.ccmall_bucket_suffix.hex}"
}

# EC2가 S3에 접근할 IAM Role
resource "aws_iam_role" "ec2_s3_role" {
  name = "EC2-S3-ACCESS-ROLE"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "s3_full_access" {
  role       = aws_iam_role.ec2_s3_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
}

resource "aws_iam_instance_profile" "ec2_profile" {
  name = "EC2-S3-Instance-Profile"
  role = aws_iam_role.ec2_s3_role.name
}
