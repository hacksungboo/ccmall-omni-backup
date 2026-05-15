# infra/deployment/terraform/network.tf
# vpc 및 네트워크 생성
resource "aws_vpc" "ccmall_vpc" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  tags                 = { Name = "ccmall-vpc" }
}

# igw
resource "aws_internet_gateway" "ccmall_igw" {
  vpc_id = aws_vpc.ccmall_vpc.id
  tags   = { Name = "ccmall-igw" }
}

# 현재 리전에서 사용 가능한 가용 영역 데이터를 가져온다.
data "aws_availability_zones" "available" {
  state = "available"
}

# public subnet
resource "aws_subnet" "ccmall_public_subnet" {
  vpc_id                  = aws_vpc.ccmall_vpc.id
  cidr_block              = var.public_subnet_cidr
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = true
  tags                    = { Name = "ccmall-public-subnet" }
}

# private subnet
resource "aws_subnet" "ccmall_private_subnet" {
  vpc_id                  = aws_vpc.ccmall_vpc.id
  cidr_block              = var.private_subnet_cidr
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = false
  tags                    = { Name = "ccmall-private-subnet" }
}

# public subnet 라우팅 테이블
resource "aws_route_table" "ccmall_public_rt" {
  vpc_id = aws_vpc.ccmall_vpc.id

  # public subnet에서 인터넷으로 나가는 트래픽은 IGW로 보낸다.
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.ccmall_igw.id
  }

  tags = {
    Name = "ccmall-public-rt"
  }
}

# public subnet과 public route table 연결
resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.ccmall_public_subnet.id
  route_table_id = aws_route_table.ccmall_public_rt.id
}

# private subnet 라우팅 테이블
resource "aws_route_table" "ccmall_private_rt" {
  vpc_id = aws_vpc.ccmall_vpc.id

  # private subnet에서 외부 인터넷으로 나가는 트래픽은 NAT Gateway로 보낸다.
  route {
    cidr_block = "0.0.0.0/0"
    # --- nat gateway를 ccmall_nat 인스턴스로 경로 변경
    network_interface_id = aws_instance.ccmall_nat.primary_network_interface_id
  }

  tags = { Name = "ccmall-private-nat" }
}

# private subnet과 private route table 연결
resource "aws_route_table_association" "private_a" {
  subnet_id      = aws_subnet.ccmall_private_subnet.id
  route_table_id = aws_route_table.ccmall_private_rt.id
}

# --- onprem 대역으로 가는 트래픽은 Rec으로 전부 보내는 경로 추가
resource "aws_route" "to_onprem_from_public" {
  route_table_id         = aws_route_table.ccmall_public_rt.id
  destination_cidr_block = var.onprem_cidr
  network_interface_id   = aws_instance.ccmall_rec.primary_network_interface_id
}

resource "aws_route" "to_onprem_from_private" {
  route_table_id         = aws_route_table.ccmall_private_rt.id
  destination_cidr_block = var.onprem_cidr
  network_interface_id   = aws_instance.ccmall_rec.primary_network_interface_id
}
