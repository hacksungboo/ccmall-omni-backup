# infra/deployment/terraform/web.tf
# web ec2 만들기
resource "aws_instance" "ccmall_web" {
  ami                         = data.aws_ami.latest_al2023.id
  instance_type               = var.web_instance_type
  subnet_id                   = aws_subnet.ccmall_public_subnet.id
  private_ip                  = "10.0.1.10"
  associate_public_ip_address = true
  vpc_security_group_ids      = [aws_security_group.sg_web.id]
  key_name                    = aws_key_pair.ccmall_key.key_name

  root_block_device {
    volume_size           = var.web_root_volume_size
    volume_type           = "gp3"
    delete_on_termination = true
  }

  # 서버 생성 시 hostname을 Web으로 변경한다.
  user_data = <<-EOF
    #!/bin/bash
    hostnamectl set-hostname Web

    # /etc/hosts 에도 일관성 있게 반영
    grep -q "127.0.0.1 Web" /etc/hosts || echo "127.0.0.1 Web" >> /etc/hosts
  EOF

  tags = {
    Name = "ccmall-Web"
  }
}