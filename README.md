# EKS + ArgoCD Practice Environment

AWS EKS 클러스터와 ArgoCD Capability를 활용한 GitOps 실습 환경을 구성하는 Terraform 프로젝트입니다.

## 🏗️ 아키텍처

```
┌─────────────────────────────────────────────────────────────┐
│                     AWS Account                             │
│                                                             │
│  ┌─────────────────────────────────────────────────────────┐ │
│  │                    VPC (10.0.0.0/16)                   │ │
│  │                                                         │ │
│  │  ┌─────────────────┐    ┌─────────────────┐             │ │
│  │  │ Public Subnets  │    │ Private Subnets │             │ │
│  │  │ (NAT Gateway)   │    │ (EKS Nodes)     │             │ │
│  │  └─────────────────┘    └─────────────────┘             │ │
│  │                                                         │ │
│  │  ┌─────────────────────────────────────────────────────┐ │ │
│  │  │              EKS Cluster v1.32                      │ │ │
│  │  │                                                     │ │ │
│  │  │  ┌─────────────────┐  ┌─────────────────┐           │ │ │
│  │  │  │   Core Addons   │  │     ArgoCD      │           │ │ │
│  │  │  │                 │  │  (Capability)   │           │ │ │
│  │  │  │ • CoreDNS       │  │                 │           │ │ │
│  │  │  │ • kube-proxy    │  │ • AWS Native    │           │ │ │
│  │  │  │ • VPC CNI       │  │ • IRSA Role     │           │ │ │
│  │  │  │ • EBS CSI       │  │ • ECR Access    │           │ │ │
│  │  │  └─────────────────┘  └─────────────────┘           │ │ │
│  │  └─────────────────────────────────────────────────────┘ │ │
│  └─────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
```

## ✨ 주요 특징

- **✅ AWS EKS Capability**: AWS 네이티브 ArgoCD 설치 (AWS Organizations 필요)
- **🔐 보안 강화**: VPC 암호화, EBS 암호화, KMS 키 로테이션
- **🚀 최신 기술**: EKS 1.32, AWS Provider 6.28, terraform-aws-modules 최신 버전
- **🎯 베스트 프랙티스**: 프라이빗 서브넷, IRSA, 다중 AZ 구성
- **📊 모니터링**: CloudWatch 로그, VPC Flow Logs

## 📋 사전 요구사항

### 필수 도구
```bash
# Terraform 설치 (>= 1.0)
terraform --version

# AWS CLI 설치 및 구성
aws --version
aws configure

# kubectl 설치
kubectl version --client
```

### AWS 권한 및 요구사항
**⚠️ 중요**: AWS EKS Capability를 사용하려면 **AWS Organizations**가 필요합니다.

다음 AWS 서비스에 대한 권한이 필요합니다:
- EKS (클러스터 생성/관리)
- EC2 (VPC, 서브넷, 보안그룹)
- IAM (역할, 정책)
- KMS (암호화 키)
- CloudWatch (로깅)
- **AWS Organizations** (EKS Capability용)
- **AWS SSO/Identity Center** (권장)

## 🚀 배포 가이드

### 1단계: 코드 복제 및 초기화
```bash
cd eks-argocd

# Terraform 초기화
terraform init
```

### 2단계: 변수 확인 및 수정
```bash
# variables.tf에서 기본값 확인
# 필요시 terraform.tfvars 파일 생성
cat > terraform.tfvars <<EOF
region       = "ap-northeast-2"
cluster_name = "my-eks-cluster"
environment  = "dev"
owner        = "my-team"
EOF
```

### 3단계: 계획 검토
```bash
# 배포 계획 확인
terraform plan
```

### 4단계: 리소스 배포
```bash
# 리소스 생성 (약 15-20분 소요)
terraform apply

# 확인 메시지에서 'yes' 입력
```

### 5단계: kubectl 구성
```bash
# kubeconfig 업데이트
aws eks --region ap-northeast-2 update-kubeconfig --name eks-argocd-practice

# 클러스터 연결 확인
kubectl get nodes
kubectl get capabilities -A
```

## 🎯 ArgoCD Capability 사용법

### ArgoCD 접속 (EKS Console)
```bash
# EKS Console 접속
https://ap-northeast-2.console.aws.amazon.com/eks/home

# 클러스터 선택 → Capabilities → ArgoCD
```

### 첫 번째 애플리케이션 배포
```bash
# 예제 애플리케이션 배포
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

# 애플리케이션 상태 확인
kubectl get applications -n argocd
```

## 📁 파일 구조

```
eks-argocd/
├── main.tf                 # Provider 설정 (AWS 6.28)
├── variables.tf            # 변수 정의
├── vpc.tf                  # VPC 및 네트워킹 (v6.6)
├── eks.tf                  # EKS 클러스터 구성 (v21.14)
├── argocd-capability.tf    # ArgoCD Capability 설치
├── argocd-iam.tf          # ArgoCD IAM 역할 (IRSA)
├── outputs.tf             # 출력값
├── README.md              # 이 파일
└── terraform.tfvars       # 변수값 (생성 필요)
```

## 🔧 커스터마이징

### EKS 노드 그룹 조정
```hcl
# eks.tf에서 노드 그룹 설정 변경
eks_managed_node_groups = {
  main = {
    instance_types = ["t3.large"]  # 인스턴스 타입 변경
    min_size       = 1             # 최소 노드 수
    max_size       = 5             # 최대 노드 수
    desired_size   = 2             # 원하는 노드 수
  }
}
```

## 🧹 리소스 정리

```bash
# ArgoCD 애플리케이션 먼저 삭제
kubectl delete applications --all -n argocd

# Terraform으로 생성한 리소스 삭제
terraform destroy

# 확인 메시지에서 'yes' 입력
```

## 🚨 트러블슈팅

### 공통 문제

**1. AWS Organizations 요구사항**
```bash
# EKS Capability는 AWS Organizations 환경에서만 작동
# 개인 계정의 경우 표준 Helm 방식 사용 권장
```

**2. kubectl 연결 실패**
```bash
# kubeconfig 재설정
aws eks --region <region> update-kubeconfig --name <cluster-name>
```

**3. Capability 상태 확인**
```bash
# Capability 리소스 상태 확인
kubectl get capabilities -A
kubectl describe capability argocd-capability -n argocd
```

## 💡 AWS EKS Capability vs Standard Helm

| 특징 | EKS Capability | Standard Helm |
|------|----------------|---------------|
| 요구사항 | AWS Organizations | 개별 AWS 계정 |
| 관리 방식 | AWS 네이티브 | 수동 관리 |
| 업그레이드 | AWS 자동 | 수동 업그레이드 |
| 접근 방식 | EKS Console | kubectl/UI |
| 적합한 환경 | 엔터프라이즈 | 개발/실습 |

## 💰 비용 최적화

- **인스턴스 타입**: t3.medium (개발용) → m5.large (운영용)
- **NAT Gateway**: 단일 NAT (개발용) → 다중 AZ NAT (운영용)
- **EBS 볼륨**: gp3 사용으로 비용 절약
- **CloudWatch**: 필요한 로그만 활성화

## 🔗 참고 자료

- [AWS EKS Capability 문서](https://docs.aws.amazon.com/eks/latest/userguide/eks-capabilities.html)
- [AWS EKS 사용자 가이드](https://docs.aws.amazon.com/eks/latest/userguide/)
- [ArgoCD 공식 문서](https://argo-cd.readthedocs.io/)
- [terraform-aws-modules/eks](https://github.com/terraform-aws-modules/terraform-aws-eks)

## 📞 지원

문제가 발생하면 다음을 확인하세요:
1. **AWS Organizations** 활성화 여부
2. AWS 권한 설정
3. Terraform 버전 호환성
4. kubectl 구성
5. VPC 및 서브넷 설정

---

**⚡ Quick Start**: `terraform init && terraform apply -auto-approve`

**🎯 목표**: AWS EKS + ArgoCD Capability로 엔터프라이즈급 GitOps 워크플로우 학습