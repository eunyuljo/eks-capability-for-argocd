# AWS Knowledge: VPC 베스트 프랙티스 - 다중 AZ, Public/Private 서브넷 분리, 보안 강화
# Terraform Registry: terraform-aws-modules/vpc/aws 6.6.0 (verified with terraform MCP)
# Module: terraform-aws-modules/vpc/aws

data "aws_availability_zones" "available" {
  state = "available"
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 6.6" # Latest VPC module version from terraform MCP

  name = "${var.cluster_name}-vpc"
  cidr = var.vpc_cidr

  # AWS 베스트 프랙티스: 다중 AZ 사용으로 고가용성 보장
  azs             = var.azs
  private_subnets = var.private_subnets
  public_subnets  = var.public_subnets

  # NAT Gateway for outbound internet access from private subnets
  enable_nat_gateway = true
  single_nat_gateway = false # 각 AZ별 NAT Gateway로 고가용성 보장
  enable_vpn_gateway = false

  # DNS 설정
  enable_dns_hostnames = true
  enable_dns_support   = true

  # VPC Flow Logs for monitoring (AWS 보안 베스트 프랙티스)
  enable_flow_log                      = true
  create_flow_log_cloudwatch_log_group = true
  create_flow_log_cloudwatch_iam_role  = true

  # EKS 클러스터를 위한 서브넷 태깅 (Kubernetes Load Balancer 배치용)
  public_subnet_tags = {
    "kubernetes.io/role/elb"                    = "1"
    "kubernetes.io/cluster/${var.cluster_name}" = "owned"
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb"           = "1"
    "kubernetes.io/cluster/${var.cluster_name}" = "owned"
  }

  tags = merge(var.common_tags, {
    Name = "${var.cluster_name}-vpc"
  })
}

# Additional Security Group for EKS Control Plane
resource "aws_security_group" "eks_additional" {
  name        = "${var.cluster_name}-eks-additional"
  description = "Additional security group for EKS cluster"
  vpc_id      = module.vpc.vpc_id

  # Restrict ingress to VPC CIDR only (AWS 보안 베스트 프랙티스)
  ingress {
    description = "HTTPS from VPC"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.common_tags, {
    Name = "${var.cluster_name}-eks-additional-sg"
  })
}

# KMS Key for EKS encryption (AWS 보안 베스트 프랙티스: 데이터 암호화)
resource "aws_kms_key" "eks" {
  description             = "EKS Secret Encryption Key"
  deletion_window_in_days = 7
  enable_key_rotation     = true

  tags = merge(var.common_tags, {
    Name = "${var.cluster_name}-eks-kms-key"
  })
}

resource "aws_kms_alias" "eks" {
  name          = "alias/${var.cluster_name}-eks"
  target_key_id = aws_kms_key.eks.key_id
}