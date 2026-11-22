provider "aws" {
  region = "ap-southeast-1"
}

# Create the First Custom VPC App-VPC
resource "aws_vpc" "app_vpc" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "App-VPC"
  }
}

# Create a Public Subnet for App-VPC
resource "aws_subnet" "app_public_subnet" {
  vpc_id            = aws_vpc.app_vpc.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "ap-southeast-1a"
  tags = {
    Name = "App_Public_Subnet"
  }
}

# Internet Gateway for App-VPC
resource "aws_internet_gateway" "app_igw" {
  vpc_id = aws_vpc.app_vpc.id
  tags = {
    Name = "App-VPC_IGW"
  }
}

# Route Table for App-VPC
resource "aws_route_table" "app_route_table" {
  vpc_id = aws_vpc.app_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.app_igw.id
  }

  tags = {
    Name = "App-VPC_RouteTable"
  }
}

# Route Table Association for App-VPC
resource "aws_route_table_association" "app_route_table_assoc" {
  subnet_id      = aws_subnet.app_public_subnet.id
  route_table_id = aws_route_table.app_route_table.id
}


# Create the Second Custom VPC DB-VPC
resource "aws_vpc" "db_vpc" {
  cidr_block = "10.1.0.0/16"
  tags = {
    Name = "DB-VPC"
  }
}

# Create a Private Subnet for DB-VPC
resource "aws_subnet" "db_private_subnet" {
  vpc_id            = aws_vpc.db_vpc.id
  cidr_block        = "10.1.1.0/24"
  availability_zone = "ap-southeast-1a"
  tags = {
    Name = "DB_Private_Subnet"
  }
}

# Route Table for DB-VPC
resource "aws_route_table" "db_route_table" {
  vpc_id = aws_vpc.db_vpc.id

  tags = {
    Name = "DB-VPC_RouteTable"
  }
}

# Route Table Association for DB-VPC
resource "aws_route_table_association" "db_route_table_assoc" {
  subnet_id      = aws_subnet.db_private_subnet.id
  route_table_id = aws_route_table.db_route_table.id
}


# Security Group for allowing all traffic in App-VPC
resource "aws_security_group" "allow_all_app_vpc" {
  vpc_id      = aws_vpc.app_vpc.id
  name        = "allow_all_app_vpc"
  description = "Allow all traffic for App-VPC"

  # Allow all inbound traffic
  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1" # Allows all protocols
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow all outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1" # Allows all protocols
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow inbound SSH traffic
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Security Group for allowing all traffic in DB-VPC
resource "aws_security_group" "allow_all_db_vpc" {
  vpc_id      = aws_vpc.db_vpc.id
  name        = "allow_all_db_vpc"
  description = "Allow all traffic for DB-VPC"

  # Allow all inbound traffic
  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1" # Allows all protocols
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow all outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1" # Allows all protocols
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow inbound SSH traffic
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}


# Key Pair for EC2 Instances
resource "aws_key_pair" "my-key-pair" {
  key_name   = "my-key-pair"
  public_key = var.ssh_public_key
}

# Launch an EC2 Instance in APP-VPC
resource "aws_instance" "instance_app_vpc" {
  ami                         = "ami-060e277c0d4cce553" # Example AMI ID, update to a valid one
  instance_type               = "t2.micro"
  subnet_id                   = aws_subnet.app_public_subnet.id
  vpc_security_group_ids      = [aws_security_group.allow_all_app_vpc.id] # Use App-VPC security group
  associate_public_ip_address = true

  key_name = aws_key_pair.my-key-pair.key_name # Use the created key

  tags = {
    Name = "Instance_App_VPC"
  }
}

# Launch an EC2 Instance in DB-VPC
resource "aws_instance" "instance_db_vpc" {
  ami                         = "ami-060e277c0d4cce553" # Example AMI ID, update to a valid one
  instance_type               = "t2.micro"
  subnet_id                   = aws_subnet.db_private_subnet.id
  vpc_security_group_ids      = [aws_security_group.allow_all_db_vpc.id] # Use DB-VPC security group
  associate_public_ip_address = false                                    # No public IP for private subnet

  key_name = aws_key_pair.my-key-pair.key_name # Use the created key

  tags = {
    Name = "Instance_DB_VPC"
  }
}

resource "aws_vpc_peering_connection" "vpc_peering" {
  vpc_id      = aws_vpc.app_vpc.id
  peer_vpc_id = aws_vpc.db_vpc.id
  auto_accept = true

  tags = {
    Name = "AppVPC-DBVPC-Peering"
  }
}

resource "aws_route" "app_vpc_peering_route" {
  route_table_id            = aws_route_table.app_route_table.id
  destination_cidr_block    = aws_vpc.db_vpc.cidr_block
  vpc_peering_connection_id = aws_vpc_peering_connection.vpc_peering.id

}
resource "aws_route" "db_vpc_peering_route" {
  route_table_id            = aws_route_table.db_route_table.id
  destination_cidr_block    = aws_vpc.app_vpc.cidr_block
  vpc_peering_connection_id = aws_vpc_peering_connection.vpc_peering.id

}


output "app_instance_public_ip" {
  value = aws_instance.instance_app_vpc.public_ip
}

output "db_instance_private_ip" {
  value = aws_instance.instance_db_vpc.private_ip
}
