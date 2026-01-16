# AWS Knowledge: EKS 클러스터 베스트 프랙티스 - IRSA, 암호화, 프라이빗 서브넷 사용
# Terraform Registry: terraform-aws-modules/eks/aws 21.14.0 (verified with terraform MCP)
# Module: terraform-aws-modules/eks/aws

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 21.14" # Latest EKS module version from terraform MCP

  name               = var.cluster_name
  kubernetes_version = "1.32"

  # VPC 설정
  vpc_id                   = module.vpc.vpc_id
  subnet_ids               = module.vpc.private_subnets
  control_plane_subnet_ids = module.vpc.private_subnets

  # API Server 접근 제어
  endpoint_private_access      = true
  endpoint_public_access       = true
  endpoint_public_access_cidrs = ["0.0.0.0/0"] # 필요시 특정 IP로 제한

  # 추가 보안 그룹
  additional_security_group_ids = [aws_security_group.eks_additional.id]

  # etcd 암호화
  encryption_config = {
    provider_key_arn = aws_kms_key.eks.arn
    resources        = ["secrets"]
  }

  # EKS Cluster Addons - 핵심 컴포넌트만 (ArgoCD가 추가 애드온 관리)
  addons = {
    coredns = {
      most_recent = true
      configuration_values = jsonencode({
        computeType = "Fargate"
      })
    }
    eks-pod-identity-agent = {
      before_compute = true
      most_recent    = true
    }
    kube-proxy = {
      most_recent = true
    }
    vpc-cni = {
      before_compute = true
      most_recent    = true
      configuration_values = jsonencode({
        env = {
          ENABLE_PREFIX_DELEGATION = "true"
          WARM_PREFIX_TARGET       = "1"
        }
      })
    }
    # EBS CSI Driver for persistent storage
    aws-ebs-csi-driver = {
      most_recent              = true
      service_account_role_arn = module.ebs_csi_irsa_role.iam_role_arn
    }
  }

  # 관리형 노드 그룹 (AWS 베스트 프랙티스: 프라이빗 서브넷 사용)
  eks_managed_node_groups = {
    main = {
      name = "main-nodegroup"

      # AL2023 AMI 사용 (최신 Amazon Linux 2023)
      ami_type       = "AL2023_x86_64_STANDARD"
      instance_types = ["t3.medium"]

      min_size     = 2
      max_size     = 10
      desired_size = 3

      # 프라이빗 서브넷에서만 실행 (보안 강화)
      subnet_ids = module.vpc.private_subnets

      # 보안 설정
      enable_bootstrap_user_data = true

      # 안전한 업그레이드 설정 (1.32 대응)
      update_config = {
        max_unavailable_percentage = 25 # 한 번에 25%씩만 업데이트 (점진적 롤아웃)
      }

      # 업그레이드 강제 실행 (1.31 EOL로 인한 1.32 업그레이드)
      force_update_version = true

      # EBS 볼륨 암호화 (AWS 보안 베스트 프랙티스)
      block_device_mappings = {
        xvda = {
          device_name = "/dev/xvda"
          ebs = {
            volume_size           = 50
            volume_type           = "gp3"
            encrypted             = true
            delete_on_termination = true
          }
        }
      }

      # 태그 설정
      tags = merge(var.common_tags, {
        Name = "${var.cluster_name}-main-nodegroup"
      })
    }
  }

  # AWS Identity Center 통합을 위한 접근 항목
  enable_cluster_creator_admin_permissions = true

  # CloudWatch 로깅 (AWS 베스트 프랙티스: 감시 및 로깅)
  enabled_log_types = ["api", "audit", "authenticator", "controllerManager", "scheduler"]

  tags = merge(var.common_tags, {
    Name = "${var.cluster_name}-cluster"
  })
}

# EBS CSI Driver를 위한 IAM Role (IRSA - IAM Roles for Service Accounts)
module "ebs_csi_irsa_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.0"

  role_name             = "${var.cluster_name}-ebs-csi"
  attach_ebs_csi_policy = true

  oidc_providers = {
    ex = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:ebs-csi-controller-sa"]
    }
  }

  tags = var.common_tags
}

# AWS Load Balancer Controller를 위한 IAM Role
module "aws_load_balancer_controller_irsa_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.0"

  role_name                              = "${var.cluster_name}-aws-load-balancer-controller"
  attach_load_balancer_controller_policy = true

  oidc_providers = {
    ex = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:aws-load-balancer-controller"]
    }
  }

  tags = var.common_tags
}