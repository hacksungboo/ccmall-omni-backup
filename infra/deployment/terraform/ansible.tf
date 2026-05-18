# infra/deployment/terraform/ansible.tf
resource "terraform_data" "prepare_ansible_dirs" {
  triggers_replace = {
    inventory_dir = local.inventory_dir
  }

  provisioner "local-exec" {
    # 기존 폴더 생성 로직 + S3 버킷 이름 환경변수 등록 로직 통합
    command = <<-EOT
      mkdir -p ${local.inventory_dir}
      echo "export BACKUP_S3_BUCKET='${aws_s3_bucket.ccmall_bucket.bucket}'" >> ~/.bashrc
      # 현재 실행 중인 쉘 세션에도 즉시 반영
      export BACKUP_S3_BUCKET='${aws_s3_bucket.ccmall_bucket.bucket}'
    EOT
  }
}

# public ip와 private ip를 이용해서 infra/inventory/inventory.yml 파일 만들기
# inventory는 ccmall-Web, ccmall-Rec만 단순하게 정의한다.
# 접속 사용자와 key는 ansible.cfg 또는 실행 명령어에서 결정한다.
resource "local_file" "ansible_inventory" {
  filename = local.inventory_file

  depends_on = [
    terraform_data.prepare_ansible_dirs
  ]

  content = yamlencode({
    all = {
      hosts = {
        # ccmall-Web은 public subnet에 있으므로 public ip로 직접 접속한다.
        "ccmall-Web" = {
          ansible_host = aws_instance.ccmall_web.public_ip
        }

        # ccmall-Rec은 private subnet에 있으므로 ccmall-Web을 통해 점프 접속한다.
        "ccmall-Rec" = {
          ansible_host = aws_instance.ccmall_rec.private_ip

          # %r은 현재 Ansible 접속 사용자로 치환된다.
          # 부트스트랩 때는 ec2-user, 운영 때는 user1로 동작한다.
          # 두 경우 모두 ccmall-key.pem으로 점프 인증한다.
          ansible_ssh_common_args = "-o ProxyCommand=\"ssh -i ${local.ccmall_ssh_key_file} -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o GSSAPIAuthentication=no -W %h:%p -q %r@${aws_instance.ccmall_web.public_ip}\" -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o GSSAPIAuthentication=no"
        }
      }
    }
  })
}

resource "local_file" "ansible_cfg" {
  filename = local.ansible_cfg

  content = <<-EOF
    [defaults]
    inventory = ${local.inventory_file}
    remote_user = user1
    private_key_file = ${local.ccmall_ssh_key_file}
    host_key_checking = False
    remote_tmp = ~/.ansible/tmp
    roles_path = ${local.deployment_roles_dir}:${local.monitoring_roles_dir}:${local.backup_roles_dir}:${local.recovery_roles_dir}
    interpreter_python = auto_silent

    [ssh_connection]
    ssh_args = -o IdentitiesOnly=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null
  EOF
}

# =============================================
# Terraform → Ansible user1 부트스트랩 자동실행
# EC2 생성 + SSH Key + inventory + ansible.cfg 준비 후 실행
# ec2_bootstrap.yml 실행으로 user1 생성 및 SSH 접속 준비
# =============================================
resource "terraform_data" "bootstrap_user1" {

  depends_on = [
    aws_instance.ccmall_web,      # Web 서버 생성 완료 후
    aws_instance.ccmall_rec,      # Rec 서버 생성 완료 후
    local_file.ccmall_ssh_key,    # SSH Private Key 생성 완료 후
    local_file.ansible_inventory, # inventory.yml 생성 완료 후
    local_file.ansible_cfg,       # ansible.cfg 생성 완료 후
    local_file.ccmall_ssh_key_pub # public key 생성 완료 후
  ]

  triggers_replace = {
    web_instance_id  = aws_instance.ccmall_web.id
    rec_instance_id  = aws_instance.ccmall_rec.id
    ccmall_public_key = tls_private_key.ccmall_private_key.public_key_openssh
  }

  provisioner "local-exec" {
    working_dir = local.infra_dir

    command = <<-EOT
      echo "======================================"
      echo " EC2 SSH 준비 대기 중... (40초)"
      echo "======================================"
      sleep 40

      # ccmall-key.pem의 공개키를 ccmall-key.pem.pub으로 저장
      # 이후 user1의 authorized_keys에 ccmall-key.pem.pub이 등록된다.
      ssh-keygen -y -f ${local.ccmall_ssh_key_file} > ${local.ccmall_ssh_key_file}.pub

      echo "======================================"
      echo " Ansible Bootstrap Playbook 시작!"
      echo "======================================"
      ANSIBLE_CONFIG=${local.ansible_cfg} \
      ANSIBLE_SSH_PIPELINING=1 \
      ansible-playbook \
        -u ec2-user \
        --private-key ${local.ccmall_ssh_key_file} \
        -e "bootstrap_public_key_file=${local.ccmall_ssh_key_file}.pub" \
        ${local.bootstrap_playbook}

      echo "======================================"
      echo " Bootstrap Playbook 완료!"
      echo "======================================"
    EOT
  }
}

# =============================================
# Terraform → Ansible 모니터링 자동실행
# bootstrap_user1 완료 후 monitoring/playbook.yml 실행
# ansible.cfg의 remote_user = user1, private_key = ccmall-key.pem 사용
# =============================================
resource "terraform_data" "run_monitoring_playbook" {

  depends_on = [
    aws_instance.ccmall_web,       # Web 서버 생성 완료 후
    aws_instance.ccmall_rec,       # Rec 서버 생성 완료 후
    local_file.ansible_inventory,  # inventory.yml 생성 완료 후
    local_file.ansible_cfg,        # ansible.cfg 생성 완료 후
    terraform_data.bootstrap_user1 # bootstrap 완료 후
  ]

  triggers_replace = {
    web_instance_id = aws_instance.ccmall_web.id
    rec_instance_id = aws_instance.ccmall_rec.id
    bootstrap_id    = terraform_data.bootstrap_user1.id
  }

  provisioner "local-exec" {
    working_dir = local.infra_dir

    command = <<-EOT
      echo "======================================"
      echo " EC2 SSH 준비 대기 중... (10초)"
      echo "======================================"
      sleep 10

      echo "======================================"
      echo " Ansible Monitoring Playbook 시작!"
      echo "======================================"
      ANSIBLE_CONFIG=${local.ansible_cfg} \
      ANSIBLE_SSH_PIPELINING=1 \
      ansible-playbook \
        --private-key ${local.ccmall_ssh_key_file} \
        monitoring/playbook.yml

      echo "======================================"
      echo " Monitoring Playbook 완료!"
      echo "======================================"
    EOT
  }
}

###ccmall- Rec생성시 tailscale및 db설치후 테이블 생성
resource "terraform_data" "run_db_setup_playbook" {
  depends_on = [
    aws_instance.ccmall_web,
    aws_instance.ccmall_rec,
    local_file.ansible_inventory,
    local_file.ansible_cfg,
    terraform_data.bootstrap_user1,
    terraform_data.run_monitoring_playbook
  ]

  triggers_replace = {
    web_instance_id = aws_instance.ccmall_web.id
    rec_instance_id = aws_instance.ccmall_rec.id
    monitoring_id   = terraform_data.run_monitoring_playbook.id
  }

  provisioner "local-exec" {
    working_dir = local.infra_dir

    command = <<-EOT
      echo "======================================"
      echo " DB Setup 준비 중... (10초)"
      echo "======================================"
      sleep 10

      echo "======================================"
      echo " Ansible DB Setup Playbook 시작!"
      echo "======================================"
      ANSIBLE_CONFIG=${local.ansible_cfg} \
      ANSIBLE_SSH_PIPELINING=1 \
      ansible-playbook \
        --private-key ${local.ccmall_ssh_key_file} \
        deployment/ansible/db_setup.yml -vvv

      echo "======================================"
      echo " DB Setup Playbook 완료!"
      echo "======================================"
    EOT
  }
}

# =============================================
# Terraform → Ansible 웹 애플리케이션 자동배포
# bootstrap_user1 완료 후 deployment/ansible/deploy_web.yml 실행
# ansible.cfg의 remote_user = user1, private_key = ccmall-key.pem 사용
# =============================================
resource "terraform_data" "run_deploy_web_playbook" {

  depends_on = [
    aws_instance.ccmall_web,        # Web 서버 생성 완료 후
    aws_instance.ccmall_rec,        # Rec 서버 생성 완료 후
    local_file.ansible_inventory,   # inventory.yml 생성 완료 후
    local_file.ansible_cfg,         # ansible.cfg 생성 완료 후
    terraform_data.bootstrap_user1, # bootstrap 완료 후
    cloudflare_record.ccmall_root,  # cloudflare dns 생성 후
    time_sleep.wait_for_dns         # dns 전파시간 대기 후
  ]

  triggers_replace = {
    web_instance_id = aws_instance.ccmall_web.id
    rec_instance_id = aws_instance.ccmall_rec.id
    bootstrap_id    = terraform_data.bootstrap_user1.id
  }

  provisioner "local-exec" {
    working_dir = local.infra_dir

    command = <<-EOT
      echo "======================================"
      echo " EC2 SSH 준비 대기 중... (10초)"
      echo "======================================"
      sleep 10

      echo "======================================"
      echo " Ansible Web Deploy Playbook 시작!"
      echo "======================================"
      ANSIBLE_CONFIG=${local.ansible_cfg} \
      ANSIBLE_SSH_PIPELINING=1 \
      ansible-playbook \
        --private-key ${local.ccmall_ssh_key_file} \
        deployment/ansible/deploy_web.yml

      echo "======================================"
      echo " Web Deploy Playbook 완료!"
      echo "======================================"
    EOT
  }
}
