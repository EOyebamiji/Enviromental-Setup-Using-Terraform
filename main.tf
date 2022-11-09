#Creating a VPC with CIDR Block and enable DNS Hostnames to assign DNS names to instances.
resource "aws_vpc" "MyVpc" {
  cidr_block = var.Main_MyVpc_CIDR
  instance_tenancy = "default"
  enable_dns_hostnames = true
  tags = {
	Name = "MyVpc"
  }

}

#Public subnet
resource "aws_subnet" "PublicSubnet" {
  vpc_id     = "${aws_vpc.MyVpc.id}"
  cidr_block = "${var.public_subnets}"
  availability_zone = "us-west-2a"
  map_public_ip_on_launch = true
  depends_on = [
    aws_vpc.MyVpc,
  ]
  tags = {
    Name = "Public Subnet"
  }

}

#Private Subnet
resource "aws_subnet" "PrivateSubnet" {
  vpc_id     = "${aws_vpc.MyVpc.id}"
  cidr_block = "${var.private_subnets}"
  availability_zone = "us-west-2a"
  map_public_ip_on_launch = "false"
  depends_on = [
    aws_vpc.MyVpc,
  ]
  tags = {
    Name = "Private Subnet"
  }
}

#Create a public facing internet gateway for connecting VPC/Network with the internet world and also attach gateway to VPC.
resource "aws_internet_gateway" "IGW" {
  vpc_id = "${aws_vpc.MyVpc.id}"
  depends_on = [
    aws_vpc.MyVpc,
  ]


  tags = {
    Name = "IGW"
  }

}

#Terraform code to Create a routing table for Internet gateway so that instance can connect to outside world, update and associate it with public subnet.
resource "aws_route_table" "RouteTable1" {
  vpc_id = aws_vpc.MyVpc.id
 
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.IGW.id
  }
  depends_on = [
    aws_vpc.MyVpc,
  ]


  tags = {
    Name = "Route Table1"
  }

}

#Association with subnet
resource "aws_route_table_association" "associate_1" {
  subnet_id      = aws_subnet.PublicSubnet.id
  route_table_id = aws_route_table.RouteTable1.id
  depends_on = [
    aws_subnet.PublicSubnet
  ]
}

#Creating a Elastic IP for the AWS VPC.
resource "aws_eip" "VPC_EIP" {
 vpc = true 
  tags = {
    Name = "Elastic IP"
  }
}


#Creating a NAT gateway and allocate the elastic IP to it and put it in public subnet.

resource "aws_nat_gateway" "IGW2" {
    allocation_id = aws_eip.VPC_EIP.id
    subnet_id = aws_subnet.PublicSubnet.id
    
    tags = {
        Name = "IGW2"
    }
  
}

#Route Table with CIDR block 0.0.0.0/0 to connect any IP and attaching it to NAT Gateway.
resource "aws_route_table" "RouteTable2"{
  vpc_id = aws_vpc.MyVpc.id

route {

    cidr_block = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.IGW2.id
  }

depends_on = [
    aws_vpc.MyVpc
  ]

tags = {
    Name = "Route Table2"
  }
}

#Associate route table in PRIVATE SUBNET
resource "aws_route_table_association" "associate_2" {
    subnet_id = aws_subnet.PrivateSubnet.id
    route_table_id = aws_route_table.RouteTable2.id
    depends_on = [
      aws_subnet.PrivateSubnet
    ]
  
}

#Security Group which allows port 80 for http and 22 for SSH in inbound rule and allows all port in outbound rule.
resource "aws_security_group" "SG_ACCESS" {
  name        = "Dev-SG"
  description = "Allow inbound traffic"
  vpc_id      = aws_vpc.MyVpc.id
ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
ingress {
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
depends_on = [
    aws_vpc.MyVpc,
  ]

tags = {
    Name = "SG_ACCESS"
  }
}

#Terraform code to Launch an ec2 instance with Ubuntu Image for Our Application.
resource "aws_instance" "UbuntuOS" {
  ami           = "ami-017fecd1353bcc96e"
  instance_type = "t2.micro" 
associate_public_ip_address = true
key_name = "EC2-Ubuntu-App-Dev" #You can iclude the existing keypair you have in your account or create a new one and add the name in here
  subnet_id =  aws_subnet.PublicSubnet.id
  vpc_security_group_ids = [ aws_security_group.SG_ACCESS.id ]

  root_block_device {
    volume_size = 30 # in GB <<----- I increased this TO 30GB! - it's a paid service (10GB is free)
    volume_type = "gp3"
    encrypted   = true
  }
  tags = {
    Name = "UbuntuOS"
  }

}