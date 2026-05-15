# infra/deployment/terraform/rec.tf
# rec ec2 만들기
resource "aws_instance" "ccmall_rec" {
  ami                         = data.aws_ami.latest_al2023.id
  instance_type               = var.rec_instance_type
  subnet_id                   = aws_subnet.ccmall_private_subnet.id
  private_ip                  = "10.0.2.30"
  associate_public_ip_address = false
  vpc_security_group_ids      = [aws_security_group.sg_rec.id]
  key_name                    = aws_key_pair.ccmall_key.key_name
  iam_instance_profile        = aws_iam_instance_profile.ec2_profile.name
  depends_on                  = [aws_instance.ccmall_nat, aws_route_table_association.private_a]
  # ---
  source_dest_check = false

  root_block_device {
    volume_size           = var.rec_root_volume_size
    volume_type           = "gp3"
    delete_on_termination = true
  }

  # 서버 생성 시 hostname을 Rec으로 변경한다.
  # --- tailscale 설정 스크립트
  user_data = <<-EOF
    #!/bin/bash
    set -eux

    hostnamectl set-hostname Rec
    grep -q "127.0.0.1 Rec" /etc/hosts || echo "127.0.0.1 Rec" >> /etc/hosts

    until curl -s https://login.tailscale.com >/dev/null; do
      sleep 5
    done

    curl -fsSL https://tailscale.com/install.sh | sh
    systemctl enable --now tailscaled

    cat > /etc/sysctl.d/99-tailscale.conf <<'SYSCTL'
    net.ipv4.ip_forward = 1
    net.ipv6.conf.all.forwarding = 1
    SYSCTL

    sysctl -p /etc/sysctl.d/99-tailscale.conf

    tailscale up \
      --authkey=${tailscale_tailnet_key.ccmall_join_key.key} \
      --hostname=ccmall-rec \
      --advertise-routes=${aws_vpc.ccmall_vpc.cidr_block} \
      --accept-routes
    EOF

  tags = {
    Name = "ccmall-Rec-CICD-test" # cicd test용 이름 변경
  }
}
