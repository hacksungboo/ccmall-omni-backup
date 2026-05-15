# infra/deployment/terraform/tailscale.tf
# --- tailscale auth key 생성
resource "tailscale_tailnet_key" "ccmall_join_key" {
  reusable      = true
  ephemeral     = false
  preauthorized = true
  expiry        = 86400
}

# --- Terraform이 기기를 찾고 라우팅 승인
data "tailscale_device" "rec_device" {
  #OS hostname Rec을 가져다 디바이스 생성함.
  hostname   = "ccmall-rec"
  wait_for   = "300s"
  depends_on = [terraform_data.bootstrap_user1]
}

resource "tailscale_device_subnet_routes" "approve_vpc_routes" {
  device_id = data.tailscale_device.rec_device.id
  routes    = [aws_vpc.ccmall_vpc.cidr_block]
}

