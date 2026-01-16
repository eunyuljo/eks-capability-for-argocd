# 🎯 EKS + ArgoCD Capability 핵심 출력값들

# EKS 클러스터 정보
output "cluster_name" {
  description = "EKS cluster name"
  value       = module.eks.cluster_name
}

output "cluster_endpoint" {
  description = "Endpoint for EKS control plane"
  value       = module.eks.cluster_endpoint
}

output "cluster_version" {
  description = "EKS cluster version"
  value       = module.eks.cluster_version
}

# kubectl 설정 명령어
output "kubectl_config_command" {
  description = "kubectl config command to connect to the cluster"
  value       = "aws eks --region ${var.region} update-kubeconfig --name ${module.eks.cluster_name}"
}

# 🚀 ArgoCD Capability 설치 완료!
output "argocd_capability_guide" {
  description = "ArgoCD Capability installation status and access guide"
  value = {
    "🎯 Step 1" = "Configure kubectl: ${local.kubectl_command}"
    "🎯 Step 2" = "Wait for nodes: kubectl get nodes"
    "🎯 Step 3" = "Check Capability: kubectl get capabilities -A"
    "🎯 Step 4" = "Access Console: ${local.eks_console_url}"
    "🎯 Step 5" = "Navigate to: Capabilities > ArgoCD"

    "📋 ArgoCD Capability Info" = {
      capability_name = aws_eks_capability.argocd.name
      version         = aws_eks_capability.argocd.version
      status          = aws_eks_capability.argocd.status
      cluster_name    = module.eks.cluster_name
    }

    "🎉 What's Done" = {
      "✅ EKS Cluster"       = "Created with Kubernetes 1.32"
      "✅ ArgoCD Capability" = "Installed via AWS EKS Capability!"
      "✅ Identity Center"   = local.argocd_capability_info.identity_center_enabled ? "Configured" : "Not Available"
      "✅ Ready to Use"      = "Access via EKS Console!"
    }

    "🔧 Install Method" = "AWS EKS Capability (Requires AWS Organizations)"
  }
}

# ArgoCD Capability 상세 정보
output "argocd_capability_details" {
  description = "Complete ArgoCD Capability installation information"
  value = {
    # Capability 정보
    capability_name = aws_eks_capability.argocd.name
    capability_id   = aws_eks_capability.argocd.id
    version         = aws_eks_capability.argocd.version
    status          = aws_eks_capability.argocd.status

    # 접근 정보
    console_url          = local.eks_console_url
    argocd_console_path  = "${local.eks_console_url}/capabilities"
    access_method        = "EKS Console > Capabilities > ArgoCD"

    # Identity Center 정보
    identity_center_enabled = local.argocd_capability_info.identity_center_enabled
    identity_store_id       = local.argocd_capability_info.identity_store_id

    # IAM Role 정보 (AWS 서비스 연동용)
    iam_role_name = aws_iam_role.argocd_service_role.name
    iam_role_arn  = aws_iam_role.argocd_service_role.arn

    # 권한 정보
    attached_policies = [
      "ECR Access for container images",
      "Secrets Manager for Git credentials"
    ]

    # 설치 방법
    installation_method = "✅ AWS EKS Capability (Native AWS service integration)"
  }
}

# Identity Center 상태 확인
output "identity_center_status" {
  description = "AWS Identity Center configuration status"
  value = {
    enabled           = local.argocd_capability_info.identity_center_enabled
    identity_store_id = local.argocd_capability_info.identity_store_id
    requirements = {
      aws_organizations = "Required for Identity Center"
      sso_enabled      = "Required for ArgoCD Capability access"
    }
    setup_guide = local.argocd_capability_info.identity_center_enabled ? "Identity Center detected - ArgoCD Capability ready!" : "⚠️  Identity Center not found - Please enable AWS SSO/Identity Center"
  }
}

# 첫 번째 애플리케이션 배포 예제
output "deploy_first_app" {
  description = "Command to deploy your first ArgoCD application via Capability"
  value       = <<-EOT
    # ArgoCD 예제 애플리케이션 배포 (Capability 방식)
    kubectl apply -f - <<EOF
    apiVersion: argoproj.io/v1alpha1
    kind: Application
    metadata:
      name: guestbook
      namespace: argocd
    spec:
      project: default
      source:
        repoURL: https://github.com/argoproj/argocd-example-apps.git
        path: guestbook
        targetRevision: HEAD
      destination:
        server: https://kubernetes.default.svc
        namespace: default
      syncPolicy:
        automated:
          prune: true
          selfHeal: true
    EOF

    # 또는 EKS Console에서 직접 ArgoCD UI 사용 가능
  EOT
}

# Local values for cleaner outputs
locals {
  kubectl_command = "aws eks --region ${var.region} update-kubeconfig --name ${module.eks.cluster_name}"
  eks_console_url = "https://${var.region}.console.aws.amazon.com/eks/home?region=${var.region}#/clusters/${module.eks.cluster_name}"
}