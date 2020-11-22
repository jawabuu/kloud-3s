resource "aws_vpc" "kube-hosts" {
  cidr_block = var.vpc_cidr

  tags = {
    Name = "kube-hosts"
  }
}

resource "aws_subnet" "kube-vpc" {
  vpc_id            = aws_vpc.kube-hosts.id
  cidr_block        = var.vpc_cidr
  availability_zone = var.region_zone

  map_public_ip_on_launch = true
  depends_on              = [aws_internet_gateway.gw]

  tags = {
    Name = "kube-vpc"
  }
}

resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.kube-hosts.id
}

resource "aws_route_table" "gw" {
  vpc_id = aws_vpc.kube-hosts.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }
}

resource "aws_route_table_association" "gw" {
  subnet_id      = aws_subnet.kube-vpc.id
  route_table_id = aws_route_table.gw.id
}
