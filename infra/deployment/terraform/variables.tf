# infra/deployment/terraform/variables.tf
# --- 변수 선언
# variables.tf에는 default 값을 넣지 않는다.
# 공통값은 terraform.tfvars에서 주입하고,
# 환경별 값은 dev.tfvars / prod.tfvars에서 주입한다.

variable "onprem_cidr" {
  description = "on-premise network CIDR"
  type        = string
}

variable "tailnet_name" {
  description = "tailscale tailnet name"
  type        = string
}

variable "tailscale_api_key" {
  description = "tailscale api key"
  type        = string
  sensitive   = true
}

# S3 버킷 prefix를 외부에서 주입받는다.
variable "s3_bucket_prefix" {
  description = "CCmall S3 bucket prefix"
  type        = string
}

# CIDR 변수
variable "vpc_cidr" {
  description = "CCmall VPC CIDR"
  type        = string
}

variable "public_subnet_cidr" {
  description = "CCmall public subnet CIDR"
  type        = string
}

variable "private_subnet_cidr" {
  description = "CCmall private subnet CIDR"
  type        = string
}

# 접근 허용 대역 변수
variable "ssh_allowed_cidr" {
  description = "CIDR allowed to access SSH on public resources"
  type        = string
}

variable "web_allowed_cidr" {
  description = "CIDR allowed to access HTTP/HTTPS on Web"
  type        = string
}

variable "web_node_exporter_allowed_cidr" {
  description = "CIDR allowed to access Web Node Exporter"
  type        = string
}

variable "mgmt_cidr" {
  description = "Management network CIDR for DB and monitoring access"
  type        = string
}

# 인스턴스 사양 변수
variable "nat_instance_type" {
  description = "NAT instance type"
  type        = string
}

variable "web_instance_type" {
  description = "Web EC2 instance type"
  type        = string
}

variable "rec_instance_type" {
  description = "Rec EC2 instance type"
  type        = string
}

# 볼륨 크기 변수
variable "web_root_volume_size" {
  description = "Web root volume size in GiB"
  type        = number
}

variable "rec_root_volume_size" {
  description = "Rec root volume size in GiB"
  type        = number
}

# cloudflare 변수 추가
variable "cloudflare_api_token" {
  description = "Cloudflare API Token for DNS management"
  type        = string
  sensitive   = true
}

variable "cloudflare_zone_name" {
  description = "Cloudflare zone name"
  type        = string
  default     = "ccmall.shop"
}
