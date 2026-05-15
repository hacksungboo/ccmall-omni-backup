# dev 환경
# 실행 예:
# terraform plan -var-file=dev.tfvars
# terraform apply -var-file=dev.tfvars

nat_instance_type = "t3.micro"
web_instance_type = "t3.micro"
rec_instance_type = "t3.micro"

web_root_volume_size = 8
rec_root_volume_size = 10
