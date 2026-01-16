# ArgoCD를 위한 IAM 역할 및 권한 설정
# ArgoCD는 argocd-capability.tf에서 EKS Capability로 설치됩니다.

# ArgoCD ServiceAccount를 위한 IAM 역할 (IRSA - IAM Roles for Service Accounts)
resource "aws_iam_role" "argocd_service_role" {
  name = "${var.cluster_name}-argocd-service-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Federated = module.eks.oidc_provider_arn
        }
        Condition = {
          StringEquals = {
            "${replace(module.eks.cluster_oidc_issuer_url, "https://", "")}:sub" = "system:serviceaccount:argocd:argocd-server"
            "${replace(module.eks.cluster_oidc_issuer_url, "https://", "")}:aud" = "sts.amazonaws.com"
          }
        }
      }
    ]
  })

  tags = var.common_tags
}

# ArgoCD가 Secrets Manager의 Git 자격 증명에 접근하기 위한 권한
resource "aws_iam_role_policy" "argocd_secrets_manager" {
  name = "${var.cluster_name}-argocd-secrets-manager"
  role = aws_iam_role.argocd_service_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Resource = "arn:aws:secretsmanager:${data.aws_region.current.id}:${data.aws_caller_identity.current.account_id}:secret:argocd/*"
      }
    ]
  })
}

# ArgoCD가 ECR에 접근하기 위한 권한 (컨테이너 이미지 pull용)
resource "aws_iam_role_policy" "argocd_ecr_access" {
  name = "${var.cluster_name}-argocd-ecr-access"
  role = aws_iam_role.argocd_service_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken",
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage"
        ]
        Resource = "*"
      }
    ]
  })
}

# Git Repository 자격 증명용 Secrets Manager (선택사항)
resource "aws_secretsmanager_secret" "git_repo" {
  name                    = "argocd/git-credentials"
  description             = "Git repository credentials for ArgoCD"
  recovery_window_in_days = 0 # 테스트용: 즉시 삭제 가능

  tags = merge(var.common_tags, {
    Name = "argocd-git-credentials"
  })
}