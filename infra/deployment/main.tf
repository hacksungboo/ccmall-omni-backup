# infra/deployment/main.tf 
# AWS에 Web, Rec 서버를 provisioning한다. 

terraform {
  required_version = "~> 1.14.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

# 1. provieder 설정
provider "aws" {
  region = "ap-northeast-2" # 서울리전  
}

# 2. vpc 및 네트워크 생성 (인프라의 기초 공사)
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  tags                 = { Name = "ccmall-vpc" }
}

# igw
resource "aws_internet_gateway" "igw" {
  # 위에서 만들어진 vpc의 아이디를 참조하도록한다.
  vpc_id = aws_vpc.main.id
  tags   = { Name = "ccmall-igw" }
}

# 현재 리전에서 사용가능한 가용영역 데이터를 가져온다
data "aws_availability_zones" "available" {
  state = "available"
}

# public subnet
resource "aws_subnet" "public_subnet" {
  vpc_id     = aws_vpc.main.id
  cidr_block = "10.0.1.0/24" # 256 개의 ip를 이 방에 할당

  # data.aws_availability_zones.available.names 는 배열인데 거기에는 여러개의 가용영역 데이터가 들어있음
  # 그 중에 인덱스0번방에 있는 데이터를 연결한다
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = true # 이 방에 생기는 서버는 무조건 공인 ip를 받음

  tags = {
    Name = "ccmall-public-subnet"
  }
}

# private subnet
resource "aws_subnet" "private_subnet" {
  vpc_id     = aws_vpc.main.id
  cidr_block = "10.0.2.0/24" # 256개의 IP를 이 방에 할당

  # data.aws_availability_zones.available.names 는 배열인데 거기에는 여러개의 가용영역 데이터가 들어있음
  # 그 중에 인덱스0번방에 있는 데이터를 연결한다
  availability_zone = data.aws_availability_zones.available.names[0]

  # private subnet의 서버는 공인 IP를 자동으로 받지 않는다.
  map_public_ip_on_launch = false

  tags = {
    Name = "ccmall-private-subnet"
  }
}

# 라우팅테이블 : public subnet의 트래픽 이정표
resource "aws_route_table" "public_rt" {
  # 어떤 vpc의 소속인지 설정
  vpc_id = aws_vpc.main.id

  # 라우팅 규칙
  # 0.0.0.0/0 으로 가는 트래픽은 인터넷게이트웨이igw로
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "ccmall-public-rt"
  }
}

# public subnet을 라우팅테이블과 연결
resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.public_subnet.id  # 본 페이지에서 만든 퍼블릭 서브넷
  route_table_id = aws_route_table.public_rt.id # 본 페이지에서 만든 라우팅 테이블에 연결
}

# NAT Gateway에 붙일 탄력적 IP 생성
resource "aws_eip" "nat_eip" {
  # NAT Gateway는 VPC 내부 리소스이므로 domain을 vpc로 설정한다.
  domain = "vpc"

  tags = {
    Name = "ccmall-nat-eip"
  }
}

# NAT Gateway 생성
resource "aws_nat_gateway" "nat_gw" {
  # NAT Gateway는 반드시 public subnet에 생성한다.
  # private subnet의 EC2-Con가 외부 인터넷으로 나갈 때 이 NAT Gateway를 사용한다.
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = aws_subnet.public_subnet.id

  # Internet Gateway가 먼저 생성된 뒤 NAT Gateway를 만들도록 순서를 보장한다.
  depends_on = [aws_internet_gateway.igw]

  tags = {
    Name = "ccmall-nat-gw"
  }
}

# private subnet 라우팅테이블 : private subnet의 트래픽 이정표
resource "aws_route_table" "private_rt" {
  # 어떤 vpc의 소속인지 설정
  vpc_id = aws_vpc.main.id

  # 라우팅 규칙
  # private subnet에서 0.0.0.0/0 으로 나가는 트래픽은 NAT Gateway로 보낸다.
  # 이렇게 하면 private EC2가 공인 IP 없이도 dnf install, pip install, GitHub 접근, S3 업로드 등을 할 수 있다.
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_gw.id
  }

  tags = {
    Name = "ccmall-private-rt"
  }
}

# private subnet을 라우팅테이블과 연결
resource "aws_route_table_association" "private_a" {
  subnet_id      = aws_subnet.private_subnet.id  # 본 페이지에서 만든 프라이빗 서브넷
  route_table_id = aws_route_table.private_rt.id # 본 페이지에서 만든 private 라우팅 테이블에 연결
}

# pem 파일 관련 작업
# 알고리즘 결정
resource "tls_private_key" "pk" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

# 키 등록
resource "aws_key_pair" "kp" {
  key_name   = "ccmall-key"
  public_key = tls_private_key.pk.public_key_openssh

  tags = {
    Name = "ccmall-key"
  }
}

# 개인 키를 가져오기
# local_file resource를 이용하면 파일을 생성할 수 있다.
resource "local_file" "ssh_key" {
  # ${path.module} 은 현재 실행 경로를 의미한다.
  filename        = "${path.module}/ccmall-key.pem"
  content         = tls_private_key.pk.private_key_pem
  file_permission = "0600" # 파일의 권한 설정
}


# web 서버 보안그룹 설정
resource "aws_security_group" "sg_web" {
  # web 서버는 public subnet에 위치한다.
  # 외부에서 SSH, HTTP, HTTPS 접속이 가능하다.
  name   = "SG-Web"
  vpc_id = aws_vpc.main.id

  # 관리자 PC에서 EC2-Web으로 SSH 접속 허용
  # 실습 단계에서는 0.0.0.0/0으로 열고, 운영에서는 본인 공인 IP/32로 제한한다.
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }


  # Nginx가 80번 포트로 외부 요청을 받는다.
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Certbot으로 인증서를 적용한 뒤 Nginx가 443번 포트로 HTTPS 요청을 받는다.
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # mgmt의 Prometheus가 EC2-Web의 Node Exporter를 수집할 때 사용한다.
  # Node Exporter 기본 포트는 9100이다.

  ingress {
    from_port   = 9100
    to_port     = 9100
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # 안에서 밖으로 나가는 규칙은 egress
  # 패키지 설치, GitHub 접근, pip 설치, Certbot 인증서 발급, 외부 API 호출 등에 사용한다.
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "SG-Web"
  }
}


# rec 서버 보안그룹 설정
resource "aws_security_group" "sg_rec" {
  # rec 서버는 private subnet에 위치한다.
  # 외부에서 직접 접속하지 않고 EC2-Web을 점프 서버로 사용한다.
  # PostgreSQL 복구 서버, 예비 DB 서버, 백업 복원 대상 서버 역할을 한다.
  name   = "SG-Rec"
  vpc_id = aws_vpc.main.id

  # EC2-Web에서 EC2-Rec으로 들어오는 SSH만 허용한다.
  # 로컬 PC에서 EC2-Web을 점프 서버로 사용해 EC2-Rec에 접속할 때 필요하다.
  ingress {
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.sg_web.id]
  }


  # EC2-Rec을 PostgreSQL 복구 서버로 사용할 경우 필요한 포트
  # EC2-Web 애플리케이션 서버에서 EC2-Rec DB로 접근할 때 사용한다.
  # FastAPI가 PostgreSQL에 연결할 때 5432 포트를 사용한다.
  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.sg_web.id]
  }

  # EC2-Con에서 DB 점검, 백업, 복구 자동화 작업을 할 때 사용한다.
  # psql, pg_dump, pg_restore, pg_basebackup, SELECT 1 점검 등에 필요하다.
  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.sg_web.id]
  }

  # EC2-Con의 Prometheus가 EC2-Rec의 Node Exporter를 수집할 때 사용한다.
  # Node Exporter 기본 포트는 9100이다.
  ingress {
    from_port       = 9100
    to_port         = 9100
    protocol        = "tcp"
    security_groups = [aws_security_group.sg_web.id]
  }

  # EC2-Con의 Prometheus가 EC2-Rec의 PostgreSQL Exporter를 수집할 때 사용한다.
  # PostgreSQL Exporter 기본 포트는 9187이다.
  ingress {
    from_port       = 9187
    to_port         = 9187
    protocol        = "tcp"
    security_groups = [aws_security_group.sg_web.id]
  }

  # 패키지 설치, GitHub 접근, S3 업로드, awscli 사용 등에 사용한다.
  # private subnet에서는 NAT Gateway를 통해 외부 인터넷에 접근한다.
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "SG-Rec"
  }
}

# s3 버킷 및 IAM 설정 (새로 추가할 로직)
resource "random_id" "bucket_suffix" {
    # 2byte 크기의 랜덤한 문자열을 얻어내기 위한 설정
    byte_length = 2
}

# s3 버킷 정의하기
resource "aws_s3_bucket" "my_bucket" {
    # s3 버킷의 이름은 전세계에서 유일해야한다.. 그래서 랜덤
    # 문자열을 너무 간단히 부여하면 에러가 나면서 만들어지지않는다. 
    # 4byte 크기의 random 한 16진수를 뒤에 붙여서 겹치지않는 이름이 나오게한다.
    bucket = "ccmall-bucket-${random_id.bucket_suffix.hex}"
}

# 1단계 . IAM role 정의하기 (신분증 만들기 )
resource "aws_iam_role" "ec2_s3_role" {
    # 이름은 마음대로 되는데
    name                = "EC2-S3-ACCESS-ROLE"
    # 정책은 정해진대로 작성
    assume_role_policy  = jsonencode({
        Version   = "2012-10-17"
        Statement = [{
            Action    = "sts:AssumeRole"
            Effect    = "Allow"
            Principal = { Service = "ec2.amazonaws.com" }
    }]
  })
}

# 2단계 신분증에 권한 적기
resource "aws_iam_role_policy_attachment" "s3_full_access" {
    role = aws_iam_role.ec2_s3_role.name
    policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
}

# 3단계 신분증을 aws 가 인식할 수 있도록 case 에 담기
resource "aws_iam_instance_profile" "ec2_profile" {
    name = "EC2-S3-Instance-Profile"
    role = aws_iam_role.ec2_s3_role.name
}

# ec2에 설치할 amazon linux 최신 이미지 검색
data "aws_ami" "latest_al2023" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"] # 이름이 이렇게 시작하는 것 들 중에서 최신 이미지 검색
  }
}


# web ec2 만들기
resource "aws_instance" "ec2_web" {
  ami                         = data.aws_ami.latest_al2023.id  # 검색된 최신의 os 이미지 id
  # 후에 terraform_example/test02_basic/operator를 참조해 t2.large를 선택. 
  instance_type               = "t3.micro"                     # 서버 사양 
  subnet_id                   = aws_subnet.public_subnet.id    # public subnet에 생성
  private_ip                  = "10.0.1.10"                    # web 서버의 private ip
  associate_public_ip_address = true                           # 공인 ip를 할당함
  vpc_security_group_ids      = [aws_security_group.sg_web.id] # 보안 그룹
  key_name                    = aws_key_pair.kp.key_name       # 위에서 준비한 key pair의 이름
  # 서버사양 바뀌면 볼륨 설정 조정 필요
  root_block_device {
  volume_size           = 8
  volume_type           = "gp3"
  delete_on_termination = true
}
  # 서버 생성 시 hostname을 Web으로 변경한다.
  user_data = <<-EOF
    #!/bin/bash
    hostnamectl set-hostname Web
  EOF

  tags = {
    Name = "ccmall-Web"
  }
}


# rec ec2 만들기
resource "aws_instance" "ec2_rec" {
  ami                         = data.aws_ami.latest_al2023.id  # 검색된 최신의 os 이미지 id
  # 후에 terraform_example/test02_basic/operator를 참조해 t2.large를 선택.
  instance_type               = "t3.micro"                     # 서버 사양
  subnet_id                   = aws_subnet.private_subnet.id   # private subnet에 생성
  private_ip                  = "10.0.2.30"                    # rec 서버의 private ip
  associate_public_ip_address = false                          # 공인 ip를 할당하지 않음
  vpc_security_group_ids      = [aws_security_group.sg_rec.id] # 보안 그룹
  key_name                    = aws_key_pair.kp.key_name       # 위에서 준비한 key pair의 이름
  # 서버사양 바뀌면 볼륨 설정 조정 필요
  root_block_device {
  volume_size           = 10
  volume_type           = "gp3"
  delete_on_termination = true
}
  # s3 접근을 위한 IAM 프로파일 연결 추가
  iam_instance_profile = aws_iam_instance_profile.ec2_profile.name

  # 서버 생성 시 hostname을 Rec으로 변경한다.
  user_data = <<-EOF
    #!/bin/bash
    hostnamectl set-hostname Rec
  EOF

  tags = {
    Name = "ccmall-Rec"
  }
}

# 생성된 EC2-Web의 public ip를 출력
output "web_public_ip" {
  description = "EC2-Web의 public ipv4 주소"

  # .public_ip 하면 참조가 가능하다
  value = aws_instance.ec2_web.public_ip
}

# 생성된 EC2-Web의 private ip를 출력
output "web_private_ip" {
  description = "EC2-Web의 private ipv4 주소"

  # .private_ip 하면 참조가 가능하다
  value = aws_instance.ec2_web.private_ip
}

# 생성된 EC2-Rec의 private ip를 출력
output "rec_private_ip" {
  description = "EC2-Rec의 private ipv4 주소"

  # .private_ip 하면 참조가 가능하다
  value = aws_instance.ec2_rec.private_ip
}

# 생성된 s3의 버킷 이름 출력
output "s3_bucket_name" {
    description = "생성된 s3 버킷의 이름"
    value       = aws_s3_bucket.my_bucket.id
}

locals {
  deployment_dir = abspath(path.module)

  ansible_dir    = "${local.deployment_dir}/ansible"
  inventory_dir  = "${local.ansible_dir}/inventory"
  inventory_file = "${local.inventory_dir}/inventory.yml"
  ansible_cfg    = "${local.ansible_dir}/ansible.cfg"

  ssh_key_file   = "${local.deployment_dir}/ccmall-key.pem"
  # rocky01_key_file = "${local.deployment_dir}/rocky01-key.pem"
}

# public ip와 private ip를 이용해서 ansible/inventory/inventory.yml 파일 만들기
resource "local_file" "ansible_inventory" {
  filename = local.inventory_file

  content = yamlencode({
    all = {
      hosts = {
        "EC2-Web" = {
          ansible_host                 = aws_instance.ec2_web.public_ip
          ansible_user                 = "ec2-user"
          ansible_ssh_private_key_file = local.ssh_key_file
        }

        "EC2-Rec" = {
          ansible_host                 = aws_instance.ec2_rec.private_ip
          ansible_user                 = "ec2-user"
          ansible_ssh_private_key_file = local.ssh_key_file

          # EC2-Rec은 private subnet에 있으므로 EC2-Web을 통해 점프 접속한다.
          ansible_ssh_common_args = "-o ProxyCommand=\"ssh -o StrictHostKeyChecking=no -i ${local.ssh_key_file} -W %h:%p -q ec2-user@${aws_instance.ec2_web.public_ip}\" -o StrictHostKeyChecking=no"
        }
        # rocky01은 VMware에 있는 Rocky Linux 기반 On-Prem DB 서버다.
        # VPN, 라우팅 설정이 완료된 이후 mgmt 서버에서 172.16.8.101로 SSH 접속할 수 있어야 한다.
        # 환경상 지금은 같은 컴퓨터의 vmware에서 돌아가고 있지만 다른 컴퓨터에서 돌아가고 있다고 가정한다.
        # rocky01-key.pem 파일은 infra/deployment/rocky01-key.pem 위치에 있다고 가정한다.
        # "rocky01" = {
        #  ansible_host                 = "172.16.8.101"
        #  ansible_user                 = "user1"
        #  ansible_ssh_private_key_file = local.rocky01_key_file
        #}
      }
    }
  })
}

# ansible/ansible.cfg 파일 생성
resource "local_file" "ansible_cfg" {
  filename = local.ansible_cfg

  content = <<-EOF
    [defaults]
    inventory = ${local.inventory_file}
    host_key_checking = False
    remote_tmp = /var/tmp/.ansible/tmp
    roles_path = ${local.ansible_dir}/roles
  EOF
}
