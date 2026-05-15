# infra/deployment/terraform/locals.tf
locals {
  # 현재 Terraform 코드가 있는 위치
  # 예: /home/user/project/infra/deployment/terraform
  terraform_dir = abspath(path.module)

  # deployment 디렉터리
  # 예: /home/user/project/infra/deployment
  deployment_dir = dirname(local.terraform_dir)

  # infra 루트 디렉터리
  # 예: /home/user/project/infra
  infra_dir = dirname(local.deployment_dir)

  # 공용 ansible.cfg 위치
  ansible_cfg = "${local.infra_dir}/ansible.cfg"

  # 공용 inventory.yml 위치
  inventory_dir  = "${local.infra_dir}/inventory"
  inventory_file = "${local.inventory_dir}/inventory.yml"

  # roles 경로
  deployment_roles_dir = "${local.deployment_dir}/ansible/roles"
  monitoring_roles_dir = "${local.infra_dir}/monitoring/ansible/roles"
  backup_roles_dir     = "${local.infra_dir}/backup/ansible/roles"
  recovery_roles_dir   = "${local.infra_dir}/recovery/ansible/roles"

  # Terraform이 생성하는 초기 접속용 key
  ccmall_ssh_key_file = "${local.terraform_dir}/ccmall-key.pem"

  # 부트스트랩 이후 운영 접속용 key
  ansible_key_file = "/home/user1/.ssh/ansiblekey.pem"

  # 부트스트랩 playbook 위치
  bootstrap_playbook = "${local.deployment_dir}/ansible/ec2_bootstrap.yml"
}