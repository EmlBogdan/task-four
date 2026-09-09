resource "aws_instance" "node" {
  ami                         = "ami-025b6f0b1ac2ef9f7"
  instance_type               = "t3.medium"
  subnet_id                   = aws_subnet.public_subnet.id
  vpc_security_group_ids      = [aws_security_group.node_sg.id]
  key_name                    = aws_key_pair.bastion_key.key_name
  associate_public_ip_address = true
  tags = {
    Name = "node"
  }
}

resource "aws_security_group" "node_sg" {
  name        = "node_sg"
  description = "Security group for node instance"
  vpc_id      = aws_vpc.main_vpc.id
  tags = {
    Name = "node_sg"
  }
}

resource "aws_vpc_security_group_ingress_rule" "allow_node_bastion_connection" {
  security_group_id = aws_security_group.node_sg.id
  cidr_ipv4         = "10.0.0.0/16"
  from_port         = 22
  ip_protocol       = "tcp"
  to_port           = 22
}

resource "aws_vpc_security_group_egress_rule" "allow_all_node_traffic_ipv4" {
  security_group_id = aws_security_group.node_sg.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}
