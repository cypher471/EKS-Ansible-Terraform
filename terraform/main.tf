provider "aws" {
  region = var.region
}

#VPC for EKS
resource "aws_vpc" "main" {
  cidr_block           = var.cidr_block
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = var.name
  }
}

#Subnets for EKS
resource "aws_subnet" "Node-1" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.node_subnets[0]
  availability_zone = var.azs[0]

  tags = {
    Name            = var.node_subnets_name[0]
  }
}

resource "aws_subnet" "Node-2" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.node_subnets[1]
  availability_zone = var.azs[1]

  tags = {
    Name            = var.node_subnets_name[1]
  }
}

resource "aws_subnet" "Pod-1" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.pod_subnets[0]
  availability_zone = var.azs[0]

  tags = {
    Name            = var.pod_subnets_name[0]
  }
}

resource "aws_subnet" "Pod-2" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.pod_subnets[1]
  availability_zone = var.azs[1]

  tags = {
    Name            = var.pod_subnets_name[1]
  }
}

#Master Node Sec Group
resource "aws_security_group" "eks" {
  name        = var.security_group_name
  description = "Security group for EKS cluster"
  vpc_id      = aws_vpc.main.id

  dynamic "ingress" {
    for_each = concat(var.node_subnets, var.pod_subnets)
    content {
      description = "Allow TCP 443 from subnet"
      from_port   = 443
      to_port     = 443
      protocol    = "tcp"
      cidr_blocks = [ingress.value]
    }
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = var.security_group_name
  }
}

#Master Node IAM Role for EKS
resource "aws_iam_role" "eks_role" {
  name               = var.eks_role_name
  assume_role_policy = data.aws_iam_policy_document.eks_assume_role_policy.json
}

data "aws_iam_policy_document" "eks_assume_role_policy" {
  statement {
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["eks.amazonaws.com"]
    }
    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role_policy_attachment" "eks_block_storage" {
  role       = aws_iam_role.eks_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSBlockStoragePolicy"
}

resource "aws_iam_role_policy_attachment" "eks_cluster" {
  role       = aws_iam_role.eks_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

resource "aws_iam_role_policy_attachment" "eks_compute" {
  role       = aws_iam_role.eks_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSComputePolicy"
}

resource "aws_iam_role_policy_attachment" "eks_load_balancing" {
  role       = aws_iam_role.eks_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSLoadBalancingPolicy"
}

resource "aws_iam_role_policy_attachment" "eks_networking" {
  role       = aws_iam_role.eks_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSNetworkingPolicy"
}

#Worker Node IAM Role for EKS
resource "aws_iam_role" "eks_worker_role" {
  name               = var.eks_node_role_name
  assume_role_policy = data.aws_iam_policy_document.ec2_assume_role_policy.json
}

data "aws_iam_policy_document" "ec2_assume_role_policy" {
  statement {
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role_policy_attachment" "ECR_ReadOnly" {
  role       = aws_iam_role.eks_worker_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

resource "aws_iam_role_policy_attachment" "eks_cni_policy" {
  role       = aws_iam_role.eks_worker_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

resource "aws_iam_role_policy_attachment" "eks_worker_node_policy" {
  role       = aws_iam_role.eks_worker_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

#EKS Cluster
resource "aws_eks_cluster" "eks" {
  name     = var.cluster_name
  role_arn = aws_iam_role.eks_role.arn
  version = var.eks_version
  access_config {
    authentication_mode = "API_AND_CONFIG_MAP"
  }
  vpc_config {
    subnet_ids         = [aws_subnet.Node-1.id, aws_subnet.Node-2.id]
    security_group_ids = [aws_security_group.eks.id]
    endpoint_public_access  = true
    endpoint_private_access = true
  }
}

#VPC Endpoints
resource "aws_vpc_endpoint" "ec2" {
  private_dns_enabled = true
  service_name = var.ec2_endpoint
  subnet_ids   = [aws_subnet.Node-1.id, aws_subnet.Node-2.id]
  security_group_ids = [aws_security_group.eks.id]
  vpc_endpoint_type = "Interface"
  vpc_id       = aws_vpc.main.id
}

resource "aws_vpc_endpoint" "ecr-api" {
  private_dns_enabled = true
  service_name = var.ecr_api_endpoint
  subnet_ids   = [aws_subnet.Node-1.id, aws_subnet.Node-2.id]
  security_group_ids = [aws_security_group.eks.id]
  vpc_endpoint_type = "Interface"
  vpc_id       = aws_vpc.main.id
}

resource "aws_vpc_endpoint" "ecr-dkr" {
  private_dns_enabled = true
  service_name = var.ecr_dkr_endpoint
  subnet_ids   = [aws_subnet.Node-1.id, aws_subnet.Node-2.id]
  security_group_ids = [aws_security_group.eks.id]
  vpc_endpoint_type = "Interface"
  vpc_id       = aws_vpc.main.id
}

resource "aws_vpc_endpoint" "eks" {
  private_dns_enabled = true
  service_name = var.eks_endpoint
  subnet_ids   = [aws_subnet.Node-1.id, aws_subnet.Node-2.id]
  security_group_ids = [aws_security_group.eks.id]
  vpc_endpoint_type = "Interface"
  vpc_id       = aws_vpc.main.id
}

resource "aws_vpc_endpoint" "eks_auth" {
  private_dns_enabled = true
  service_name = var.eks_auth_endpoint
  subnet_ids   = [aws_subnet.Node-1.id, aws_subnet.Node-2.id]
  security_group_ids = [aws_security_group.eks.id]
  vpc_endpoint_type = "Interface"
  vpc_id       = aws_vpc.main.id
}

resource "aws_vpc_endpoint" "s3_gateway" {
  vpc_id            = aws_vpc.main.id
  service_name      = var.s3_gateway_endpoint
  vpc_endpoint_type = "Gateway"
  route_table_ids   = [aws_vpc.main.default_route_table_id]
}

resource "aws_vpc_endpoint" "sts" {
  private_dns_enabled = true
  service_name = var.sts_endpoint
  subnet_ids   = [aws_subnet.Node-1.id, aws_subnet.Node-2.id]
  security_group_ids = [aws_security_group.eks.id]
  vpc_endpoint_type = "Interface"
  vpc_id       = aws_vpc.main.id
}