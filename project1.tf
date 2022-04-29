#PROJECT
provider "aws" {
  region = "us-east-1"
}
#1-Create a VPC
resource "aws_vpc" "dev-vpc" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name  = "dev-team"
    Owner = "dev-team"
  }
}
#2-Create an igw
resource "aws_internet_gateway" "dev-gw" {
  vpc_id = aws_vpc.dev-vpc.id

  tags = {
    Name = "dev-igw"
  }
}
#3-Create a custom route table
resource "aws_route_table" "dev-rt" {
  vpc_id = aws_vpc.dev-vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.dev-gw.id
  }

  route {
    ipv6_cidr_block = "::/0"
    gateway_id      = aws_internet_gateway.dev-gw.id
  }

  tags = {
    Name = "dev"
  }
}
#4-Create a subnet
resource "aws_subnet" "devSN1" {
  vpc_id            = aws_vpc.dev-vpc.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "us-east-1a"
  tags = {
    Name  = "devTestServer"
    Owner = "dev-team"
  }
}
# 5-Associate subnet with RT
resource "aws_route_table_association" "devSN1" {
  subnet_id      = aws_subnet.devSN1.id
  route_table_id = aws_route_table.dev-rt.id
}

# #6-Create SG to allow Port 22,80,443. TLS[Transport Layer Security]
resource "aws_security_group" "allow-web-traffic" {
  name        = "allow_webTraffic"
  description = "Allow TLS inbound traffic"
  vpc_id      = aws_vpc.dev-vpc.id

  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]

  }
  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]

  }
  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]

  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]

  }

  tags = {
    Name = "allow_web"
  }
}
# 7-Create a network interface with an ip in the subnet that was created in step 
resource "aws_network_interface" "web-server-dev" {
  subnet_id       = aws_subnet.devSN1.id
  private_ips     = ["10.0.1.50"]
  security_groups = [aws_security_group.allow-web-traffic.id]

}
# #8-Assign an elastic IP to the network interface created in step 7
resource "aws_eip" "one" {
  vpc                       = true
  network_interface         = aws_network_interface.web-server-dev.id
  associate_with_private_ip = "10.0.1.50"
  depends_on                = [aws_internet_gateway.dev-gw]
}
# #9-Create an ubuntu server and install/enable apache 2
resource "aws_instance" "ubuntu-server" {
  instance_type     = "t2.micro"
  ami               = "ami-04505e74c0741db8d"
  availability_zone = "us-east-1a"
  key_name          = "devkey"

  network_interface {
    device_index         = 0
    network_interface_id = aws_network_interface.web-server-dev.id

  }

  user_data = <<-EOF
    #!/bin/bash
    sudo apt update -y
    sudo apt install apache2 -y
    sudo systemctl start apache2
    sudo systemctl enable apache2
    sudo bash -c 'echo GREAT JOB! You made it > /var/www/html/index.html'
    EOF

  tags = {
    Name = "web-server"
  }
}
