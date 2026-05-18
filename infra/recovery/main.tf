terraform {
  required_version = "~> 1.14.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.5"
    }
  }
}

## 1. 변수 선언 (줄바꿈 및 표준 문법 적용)
variable "tailscale_api_key" {
  type      = string
  sensitive = true
}

variable "tailnet_name" {
  type = string
}

provider "aws" {
  region = "ap-northeast-2"
}

## 2. 데이터 소스 (기존 인프라 참조)
data "aws_vpc" "ccmall_vpc" {
  filter {
    name   = "tag:Name"
    values = ["ccmall-vpc"]
  }
}

data "aws_subnet" "private_subnet" {
  filter {
    name   = "tag:Name"
    values = ["ccmall-private-subnet"]
  }
}

data "aws_security_group" "sg_rec" {
  filter {
    name   = "group-name"
    values = ["SG-Rec"]
  }
  vpc_id = data.aws_vpc.ccmall_vpc.id
}

data "aws_key_pair" "ccmall_key" {
  key_name = "ccmall-key"
}

data "aws_iam_instance_profile" "ec2_profile" {
  name = "EC2-S3-Instance-Profile"
}

data "aws_instance" "ccmall_web" {
  filter {
    name   = "tag:Name"
    values = ["ccmall-Web"]
  }
  filter {
    name   = "instance-state-name"
    values = ["running"]
  }
}

data "aws_ami" "latest_al2023" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }
}

## 3. 리커버리 EC2 생성
resource "aws_instance" "ccmall-Recovery-ec2" {
  ami                         = data.aws_ami.latest_al2023.id
  instance_type               = "t3.micro"
  subnet_id                   = data.aws_subnet.private_subnet.id
  private_ip                  = "10.0.2.40"
  associate_public_ip_address = false

  vpc_security_group_ids = [
    data.aws_security_group.sg_rec.id
  ]

  key_name             = data.aws_key_pair.ccmall_key.key_name
  iam_instance_profile = data.aws_iam_instance_profile.ec2_profile.name

  root_block_device {
    volume_size           = 20
    volume_type           = "gp3"
    delete_on_termination = true
  }

  user_data = <<EOF
#!/bin/bash
hostnamectl set-hostname ccmall-Recovery-ec2
grep -q "127.0.0.1 ccmall-Recovery-ec2" /etc/hosts || echo "127.0.0.1 ccmall-Recovery-ec2" >> /etc/hosts
EOF

  tags = {
    Name = "ccmall-Recovery-ec2"
  }
}

## 4. 앤서블 인벤토리 생성
resource "local_file" "inventory" {
  filename = "${path.module}/inventory.yml"
  content = yamlencode({
    all = {
      hosts = {
        "ccmall-Recovery-ec2" = {
          ansible_host                 = aws_instance.ccmall-Recovery-ec2.private_ip
          ansible_user                 = "ec2-user"
          ansible_ssh_private_key_file = "../deployment/terraform/ccmall-key.pem"
          ansible_ssh_common_args      = "-o ProxyCommand=\"ssh -i ../deployment/terraform/ccmall-key.pem -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -W %h:%p ec2-user@${data.aws_instance.ccmall_web.public_ip}\""
        }
      }
    }
  })
}

## 5. 앤서블 설정 파일 생성
resource "local_file" "ansible_cfg" {
  filename = "${path.module}/ansible.cfg"
  content = join("\n", [
    "[defaults]",
    "inventory = ./inventory.yml",
    "host_key_checking = False",
    "remote_user = ec2-user",
    "private_key_file = ../deployment/terraform/ccmall-key.pem",
    "interpreter_python = auto_silent",
    ""
  ])
}

## 6. 부팅 대기
resource "terraform_data" "wait_for_ec2" {
  depends_on = [
    aws_instance.ccmall-Recovery-ec2,
    local_file.inventory,
    local_file.ansible_cfg
  ]
  provisioner "local-exec" {
    command = "sleep 40"
  }
}

## 7. 플레이북 실행
resource "terraform_data" "run_ansible" {
  depends_on = [
    terraform_data.wait_for_ec2,
    local_file.inventory
  ]
  provisioner "local-exec" {
    command = <<-EOT
      export ANSIBLE_CONFIG=./ansible.cfg
      ANSIBLE_SSH_PIPELINING=1 ansible-playbook site.yml \
      -e "s3_bucket_name=$BACKUP_S3_BUCKET" \
      -e "tailscale_auth_key=$TAILSCALE_AUTH_KEY"
    EOT
  }
}

output "ccmall-Recovery-ec2_private_ip" {
  description = "Recovery DB private ip"
  value       = aws_instance.ccmall-Recovery-ec2.private_ip
}