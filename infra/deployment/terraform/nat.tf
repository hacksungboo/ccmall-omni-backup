# infra/deployment/terraform/nat.tf
# Amazon Linux 2023 최신 AMI 검색
# NAT Instance는 최신 Amazon Linux 2023 AMI를 사용한다.
# --- NAT Instance 생성
resource "aws_instance" "ccmall_nat" {
  ami                         = data.aws_ami.latest_al2023.id
  instance_type               = var.nat_instance_type
  subnet_id                   = aws_subnet.ccmall_public_subnet.id
  associate_public_ip_address = true
  vpc_security_group_ids      = [aws_security_group.sg_nat.id]
  key_name                    = aws_key_pair.ccmall_key.key_name

  source_dest_check = false

  # --- 설정 스크립트
  user_data = <<-EOF
    #!/bin/bash
    set -eux

    hostnamectl set-hostname NAT
    echo "127.0.0.1 NAT" >> /etc/hosts

    echo "net.ipv4.ip_forward = 1" > /etc/sysctl.d/99-nat.conf
    sysctl -p /etc/sysctl.d/99-nat.conf

    dnf install -y iptables-services
    systemctl enable --now iptables

    iptables -P FORWARD ACCEPT
    iptables -I FORWARD -j ACCEPT
    iptables -t nat -A POSTROUTING -s ${aws_vpc.ccmall_vpc.cidr_block} -j MASQUERADE

    service iptables save
  EOF

  tags = { Name = "ccmall-NAT" }
}
