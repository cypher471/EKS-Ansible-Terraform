provider "aws" {
  region = var.region
}

resource "aws_vpc" "main" {
  cidr_block           = var.cidr_block
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = var.name
  }
}

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

resource "aws_security_group" "eks" {
  name        = var.security_group_name
  description = "Security group for EKS cluster"
  vpc_id      = aws_vpc.main.id

  # Ingress rules: allow TCP 443 from all node and pod subnets
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

  # Egress: allow all outbound traffic
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

resource "aws_iam_role" "eks_role" {
  name               = var.eks_role_name
  assume_role_policy = data.aws_iam_policy_document.eks_assume_role_policy.json
}

# Assume role policy for EKS
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

# Attach AWS managed policies to the role
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

resource "aws_eks_cluster" "eks" {
  name     = var.cluster_name
  role_arn = var.eks_role_arn
  version = var.eks_version

  vpc_config {
    subnet_ids         = [aws_subnet.Node-1.id, aws_subnet.Node-2.id]
    security_group_ids = [aws_security_group.eks.id]
    endpoint_public_access  = true
    endpoint_private_access = true
  }

  tags = {
    Name = var.cluster_name
  }
}