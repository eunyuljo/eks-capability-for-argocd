# AWS Knowledge: Terraform Provider 최신 버전 사용, 리전 설정
# Terraform Registry: hashicorp/aws 6.28.0 (verified with terraform MCP)
# Terraform Configuration

terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.28" # Latest AWS provider version from terraform MCP
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.8" # 최신 안정 버전
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.35" # EKS 호환 버전
    }
  }

  # 맛보기용: 로컬 상태 파일 사용 (프로덕션에서는 S3 백엔드 권장)
}

# AWS Provider 설정
provider "aws" {
  region = var.region

  # 기본 태그 적용 (AWS 베스트 프랙티스)
  default_tags {
    tags = var.common_tags
  }
}

# Kubernetes Provider (EKS 클러스터 연동)
provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name]
  }
}


# 현재 AWS 계정 및 리전 정보
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}