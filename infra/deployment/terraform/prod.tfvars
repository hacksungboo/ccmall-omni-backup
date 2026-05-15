# infra/deployment/terraform/prod.tfvars
# prod 환경
# 실행 예:
# terraform plan -var-file=prod.tfvars
# terraform apply -var-file=prod.tfvars

nat_instance_type = "t3.small"
web_instance_type = "t3.small"
rec_instance_type = "t3.small"

web_root_volume_size = 12
rec_root_volume_size = 16
