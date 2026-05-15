# infra/deployment/terraform/sg.tf
# --- NAT Instance 보안 그룹 설정
resource "aws_security_group" "sg_nat" {
  name   = "SG-NAT"
  vpc_id = aws_vpc.ccmall_vpc.id

  ingress { # 외부 SSH -> 나중에 지우기
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.ssh_allowed_cidr]
  }

  ingress { # NAT로 들어오는 트래픽 전면 허용
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [aws_vpc.ccmall_vpc.cidr_block]
  }

  egress { # private subnet에서 나가는 임의 트래픽
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = { Name = "SG-NAT" }
}

# web 서버 보안 그룹
resource "aws_security_group" "sg_web" {
  name   = "SG-Web"
  vpc_id = aws_vpc.ccmall_vpc.id

  # SSH
  # 실습 단계에서는 0.0.0.0/0으로 열고, 운영에서는 본인 공인 IP/32로 제한한다.
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.ssh_allowed_cidr]
  }

  # HTTP
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = [var.web_allowed_cidr]
  }

  # HTTPS
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.web_allowed_cidr]
  }

  # Node Exporter
  ingress {
    from_port   = 9100
    to_port     = 9100
    protocol    = "tcp"
    cidr_blocks = [var.web_node_exporter_allowed_cidr]
  }

  # outbound 전체 허용
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

# rec 서버 보안 그룹
resource "aws_security_group" "sg_rec" {
  name   = "SG-Rec"
  vpc_id = aws_vpc.ccmall_vpc.id

  # ccmall-Web에서 ccmall-Rec으로 SSH 허용
  ingress {
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.sg_web.id]
  }

  # ccmall-Web에서 ccmall-Rec PostgreSQL 접근 허용
  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.sg_web.id]
  }

  # mgmt 서버가 Tailscale 대역을 통해 ccmall-Rec PostgreSQL에 접근
  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = [var.mgmt_cidr]
  }

  # mgmt Prometheus -> ccmall-Rec Node Exporter
  ingress {
    from_port   = 9100
    to_port     = 9100
    protocol    = "tcp"
    cidr_blocks = [var.mgmt_cidr]
  }

  # mgmt Prometheus -> ccmall-Rec PostgreSQL Exporter
  ingress {
    from_port   = 9187
    to_port     = 9187
    protocol    = "tcp"
    cidr_blocks = [var.mgmt_cidr]
  }

  # Web에서 오는 onprem 행 포워딩 트래픽 허용
  ingress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    security_groups = [aws_security_group.sg_web.id]
  }

  # outbound 전체 허용
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
