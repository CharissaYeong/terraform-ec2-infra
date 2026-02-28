# Get latest Amazon Linux 2023 x86_64 AMI from SSM
data "aws_ssm_parameter" "al2023_ami" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

# Get default VPC
data "aws_vpc" "default" {
  default = true
}

# Get subnets inside default VPC
data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

# Create EC2 key pair
resource "tls_private_key" "example" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "aws_key_pair" "terraform_key" {
  key_name   = "charissa-terraform-key"
  public_key = tls_private_key.example.public_key_openssh
}

resource "local_file" "private_key_pem" {
  content         = tls_private_key.example.private_key_pem
  filename        = "${path.module}/charissa-terraform-key.pem" # <-- use full path
  file_permission = "0400"
}



resource "aws_instance" "public" {
  ami                         = data.aws_ssm_parameter.al2023_ami.value # find the AMI ID of Amazon Linux 2023  
  instance_type               = "t2.micro"
  subnet_id                   = data.aws_subnets.default.ids[0]  #Public Subnet ID, e.g. subnet-xxxxxxxxxxx
  associate_public_ip_address = true
  key_name                     = aws_key_pair.terraform_key.key_name #Change to your keyname, e.g. jazeel-key-pair
  vpc_security_group_ids = [aws_security_group.allow_ssh.id]
 
  tags = {
    Name = "charissa-ec2"    #Prefix your own name, e.g. jazeel-ec2
  }
}

resource "aws_security_group" "allow_ssh" {
  name        = "charissa-terraform-security-group" #Security group name, e.g. jazeel-terraform-security-group
  description = "Allow SSH inbound"
  vpc_id      = data.aws_vpc.default.id  #VPC ID (Same VPC as your EC2 subnet above), E.g. vpc-xxxxxxx
}

resource "aws_vpc_security_group_ingress_rule" "allow_tls_ipv4" {
  security_group_id = aws_security_group.allow_ssh.id
  cidr_ipv4         = "0.0.0.0/0"  
  from_port         = 22
  ip_protocol       = "tcp"
  to_port           = 22
}