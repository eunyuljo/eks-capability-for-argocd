# AWS Knowledge: AWS EKS Capability를 통한 ArgoCD 자동 설치 (AWS Organizations 필요)
# ArgoCD Capability (AWS 공식 ArgoCD 서비스)
# AWS EKS Capabilities를 통한 ArgoCD 자동 설치

# ArgoCD Capability 리소스
resource "aws_eks_capability" "argocd" {
  # 필수 파라미터
  name                      = module.eks.cluster_name
  capability_name          = "argocd-capability"
  type                     = "ARGOCD"
  role_arn                = aws_iam_role.argocd_service_role.arn
  delete_propagation_policy = "DELETE_ALL"

  # Capability 구성
  configuration = jsonencode({
    # ArgoCD 서버 설정
    server = {
      service = {
        type = "LoadBalancer"
      }
      # 리소스 제한
      resources = {
        requests = {
          cpu    = "100m"
          memory = "128Mi"
        }
        limits = {
          cpu    = "500m"
          memory = "512Mi"
        }
      }
    }

    # 컨트롤러 설정
    controller = {
      resources = {
        requests = {
          cpu    = "100m"
          memory = "128Mi"
        }
        limits = {
          cpu    = "500m"
          memory = "512Mi"
        }
      }
    }

    # DEX 비활성화 (테스트 목적)
    dex = {
      enabled = false
    }
  })

  tags = merge(var.common_tags, {
    Name = "${var.cluster_name}-argocd-capability"
    Type = "ArgoCD-Capability"
  })

  depends_on = [
    module.eks,
    aws_iam_role.argocd_service_role
  ]
}

# Identity Center 데이터 소스
data "aws_ssoadmin_instances" "this" {}

# ArgoCD 관리자 그룹 (Identity Center)
data "aws_identitystore_group" "argocd_admin" {
  count             = length(data.aws_ssoadmin_instances.this.identity_store_ids) > 0 ? 1 : 0
  identity_store_id = data.aws_ssoadmin_instances.this.identity_store_ids[0]

  alternate_identifier {
    unique_attribute {
      attribute_path  = "DisplayName"
      attribute_value = "ArgoCD-Administrators"
    }
  }
}

# EKS Access Entry for ArgoCD (별도 리소스)
resource "aws_eks_access_entry" "argocd_admin" {
  count         = length(data.aws_ssoadmin_instances.this.identity_store_ids) > 0 ? 1 : 0
  cluster_name  = module.eks.cluster_name
  principal_arn = "arn:aws:identitystore::${data.aws_caller_identity.current.account_id}:group/${data.aws_identitystore_group.argocd_admin[0].group_id}"
  type          = "STANDARD"

  tags = var.common_tags
}

# Access Policy Association for ArgoCD Admin
resource "aws_eks_access_policy_association" "argocd_admin" {
  count         = length(data.aws_ssoadmin_instances.this.identity_store_ids) > 0 ? 1 : 0
  cluster_name  = module.eks.cluster_name
  principal_arn = aws_eks_access_entry.argocd_admin[0].principal_arn
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"

  access_scope {
    type = "cluster"
  }

  depends_on = [aws_eks_access_entry.argocd_admin]
}

# ArgoCD Capability 정보 출력용 로컬값
locals {
  argocd_capability_info = {
    capability_name         = aws_eks_capability.argocd.capability_name
    capability_id          = aws_eks_capability.argocd.id
    status                 = aws_eks_capability.argocd.status
    cluster_name           = module.eks.cluster_name
    identity_center_enabled = length(data.aws_ssoadmin_instances.this.identity_store_ids) > 0
    identity_store_id       = length(data.aws_ssoadmin_instances.this.identity_store_ids) > 0 ? data.aws_ssoadmin_instances.this.identity_store_ids[0] : null
  }
}