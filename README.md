# EKS + ArgoCD Capability Practice Environment

AWS EKS 클러스터와 **ArgoCD Capability**를 활용한 엔터프라이즈급 GitOps 실습 환경을 구성하는 Terraform 프로젝트입니다.

> **⚠️ 중요**: 이 프로젝트는 **AWS EKS Capability**를 사용합니다. AWS Organizations 환경에서만 작동하며, 개인 계정의 경우 [eks-capability-for-argocd](../eks-capability-for-argocd) 폴더의 표준 Helm 방식을 사용하세요.

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

### ✅ 환경 검증 체크리스트

**시작하기 전에 다음 사항을 확인하세요:**

#### 1. AWS 계정 유형 확인
```bash
# AWS Organizations 상태 확인
aws organizations describe-organization 2>/dev/null || echo "⚠️ AWS Organizations 없음 - 표준 Helm 방식 사용 권장"
```

#### 2. 필수 도구 설치 확인
```bash
# Terraform 설치 (>= 1.0)
terraform --version

# AWS CLI 설치 및 구성 (>= 2.0)
aws --version
aws sts get-caller-identity

# kubectl 설치 (>= 1.30)
kubectl version --client
```

### 🏢 AWS Organizations 요구사항

**⚠️ 필수**: AWS EKS Capability는 다음 환경에서만 작동합니다:

| 요구사항 | 필수 여부 | 설명 |
|---------|-----------|------|
| **AWS Organizations** | ✅ 필수 | 조직 계정 또는 조직 구성원 계정 |
| **AWS SSO/Identity Center** | 🔶 권장 | ArgoCD UI 접근용 |
| **조직 관리자 권한** | 🔶 권장 | Capability 설치 권한 |

#### 개인 계정 사용자
```bash
# 개인 계정의 경우 표준 Helm 방식 사용
cd ../eks-capability-for-argocd
```

### 🔐 AWS 권한 요구사항

다음 AWS 서비스에 대한 **관리자 수준** 권한이 필요합니다:

#### 필수 권한
- **EKS**: 클러스터 생성, 관리, Capability 설치
- **EC2**: VPC, 서브넷, 보안그룹, NAT Gateway
- **IAM**: 서비스 역할, 정책, IRSA 설정
- **KMS**: 암호화 키 생성 및 관리

#### 추가 권한
- **CloudWatch**: 로그 그룹, 스트림 생성
- **Organizations**: Capability 권한 (조직 계정)
- **SSO**: Identity Center 그룹 조회 (선택사항)

## 🚀 배포 가이드

### 1단계: 사전 검증 ✅
```bash
# AWS Organizations 확인
aws organizations describe-organization || {
    echo "❌ AWS Organizations 필요 - 표준 Helm 방식으로 전환하세요"
    echo "👉 cd ../eks-capability-for-argocd"
    exit 1
}

# 권한 확인
aws sts get-caller-identity
aws eks list-clusters --region ap-northeast-2

# 도구 버전 확인
terraform --version  # >= 1.0 필요
aws --version        # >= 2.0 필요
kubectl version --client # >= 1.30 필요
```

### 2단계: 작업 디렉토리 설정 📁
```bash
cd eks-argocd

# 기존 상태 확인 (있다면)
ls -la *.tf*

# Terraform 초기화
terraform init
```

### 3단계: 환경 변수 설정 ⚙️
```bash
# 현재 설정값 확인
grep -A 10 'variable.*default' variables.tf

# 사용자 정의 값 설정 (선택사항)
cat > terraform.tfvars <<EOF
# 기본값을 사용하거나 필요에 따라 수정
region       = "ap-northeast-2"
cluster_name = "eks-argocd-practice"  # 변수 파일과 일치
environment  = "practice"
owner        = "practice-team"

# VPC 설정 (선택사항)
vpc_cidr        = "10.0.0.0/16"
private_subnets = ["10.0.1.0/24", "10.0.2.0/24"]
public_subnets  = ["10.0.101.0/24", "10.0.102.0/24"]
EOF
```

### 4단계: 배포 계획 검토 📋
```bash
# 배포 계획 상세 확인
terraform plan -out=tfplan

# 주요 확인 사항:
# ✅ EKS 클러스터 생성
# ✅ VPC 및 서브넷 구성
# ✅ ArgoCD Capability 설치
# ✅ IAM 역할 및 정책
# ✅ KMS 키 생성
```

### 5단계: 리소스 배포 🚀
```bash
# 배포 실행 (15-25분 소요)
terraform apply tfplan

# 또는 대화형으로
terraform apply
# 'yes' 입력하여 확인
```

### 6단계: 배포 완료 확인 ✅
```bash
# kubeconfig 업데이트 (실제 클러스터 이름 사용)
aws eks --region ap-northeast-2 update-kubeconfig --name eks-argocd-practice

# 클러스터 상태 확인
kubectl get nodes
kubectl get namespaces

# ArgoCD Capability 상태 확인
kubectl get capabilities -A
kubectl describe capability argocd-capability -n argocd
```

### 7단계: ArgoCD 접근 설정 🎯
```bash
# EKS Console에서 ArgoCD 접근
echo "🌐 EKS Console: https://ap-northeast-2.console.aws.amazon.com/eks/home"
echo "📍 경로: 클러스터 선택 → Capabilities → ArgoCD"

# Identity Center 그룹 확인 (있는 경우)
aws identitystore list-groups --identity-store-id $(aws sso-admin list-instances --query 'Instances[0].IdentityStoreId' --output text) --query 'Groups[?DisplayName==`ArgoCD-Administrators`]'
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

### 🔍 진단 도구

#### 전체 상태 진단 스크립트
```bash
#!/bin/bash
echo "🔍 EKS + ArgoCD Capability 진단 시작..."

# 1. AWS 계정 및 권한 확인
echo "1️⃣ AWS 계정 정보:"
aws sts get-caller-identity

echo "2️⃣ AWS Organizations 상태:"
aws organizations describe-organization 2>/dev/null || echo "❌ Organizations 없음"

# 2. 클러스터 상태 확인
echo "3️⃣ EKS 클러스터 목록:"
aws eks list-clusters --region ap-northeast-2

echo "4️⃣ 클러스터 상세 정보:"
kubectl cluster-info

# 3. ArgoCD Capability 확인
echo "5️⃣ Capability 상태:"
kubectl get capabilities -A

echo "6️⃣ ArgoCD 리소스:"
kubectl get all -n argocd

echo "🏁 진단 완료"
```

### ❗ 주요 문제 해결

#### 1. AWS Organizations 관련 문제

**문제**: `InvalidParameterException: EKS Capabilities requires AWS Organizations`
```bash
# 해결책 1: Organizations 상태 확인
aws organizations describe-organization

# 해결책 2: 개인 계정이라면 표준 Helm 방식 사용
cd ../eks-capability-for-argocd
```

**문제**: `AccessDeniedException: User is not authorized`
```bash
# 해결책: 조직 관리자 권한 또는 EKS Capability 권한 필요
aws iam get-role --role-name OrganizationAccountAccessRole
```

#### 2. Terraform 배포 실패

**문제**: `Error creating EKS Capability`
```bash
# 진단: Capability 사전 요구사항 확인
terraform state list | grep eks_capability
terraform show terraform.tfstate | grep capability

# 해결책: 단계별 배포
terraform apply -target=module.eks
terraform apply -target=aws_iam_role.argocd_service_role
terraform apply
```

**문제**: `timeout while waiting for state to become 'READY'`
```bash
# 진단: EKS 클러스터 상태 확인
aws eks describe-cluster --name eks-argocd-practice --region ap-northeast-2

# 해결책: 수동 대기 및 재시도
aws eks wait cluster-active --name eks-argocd-practice --region ap-northeast-2
terraform apply -refresh=true
```

#### 3. kubectl 연결 문제

**문제**: `couldn't get current server API group list`
```bash
# 진단: kubeconfig 확인
kubectl config current-context
kubectl config view

# 해결책: kubeconfig 재설정
aws eks --region ap-northeast-2 update-kubeconfig --name eks-argocd-practice --force
```

**문제**: `error: You must be logged in to the server`
```bash
# 진단: AWS 자격증명 확인
aws sts get-caller-identity
aws eks get-token --cluster-name eks-argocd-practice --region ap-northeast-2

# 해결책: AWS CLI 재구성
aws configure
aws sso login  # SSO 사용시
```

#### 4. ArgoCD Capability 문제

**문제**: ArgoCD Capability가 `PENDING` 상태에 머무름
```bash
# 진단: 상세 로그 확인
kubectl describe capability argocd-capability -n argocd
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-server

# 해결책: IAM 권한 확인
aws iam get-role --role-name eks-argocd-practice-argocd-service-role
kubectl describe serviceaccount argocd-server -n argocd
```

**문제**: ArgoCD UI 접근 불가
```bash
# 진단: 서비스 상태 확인
kubectl get svc -n argocd
kubectl get ingress -n argocd 2>/dev/null || echo "Ingress 없음"

# 해결책: EKS Console에서 접근
echo "ArgoCD UI: AWS Console → EKS → Clusters → Capabilities → ArgoCD"
```

### 🆘 응급 복구 절차

#### Capability 재설치
```bash
# 1. ArgoCD Capability 삭제
terraform destroy -target=aws_eks_capability.argocd
kubectl delete namespace argocd --force --grace-period=0

# 2. 클러스터 상태 대기
aws eks wait cluster-active --name eks-argocd-practice --region ap-northeast-2

# 3. 재설치
terraform apply -target=aws_eks_capability.argocd
```

#### 완전 재설치
```bash
# 경고: 모든 데이터 손실됨
terraform destroy
rm -rf .terraform*
terraform init
terraform apply
```

## 💡 AWS EKS Capability vs Standard Helm

| 특징 | EKS Capability | Standard Helm |
|------|----------------|---------------|
| 요구사항 | AWS Organizations | 개별 AWS 계정 |
| 관리 방식 | AWS 네이티브 | 수동 관리 |
| 업그레이드 | AWS 자동 | 수동 업그레이드 |
| 접근 방식 | EKS Console | kubectl/UI |
| 적합한 환경 | 엔터프라이즈 | 개발/실습 |

## 💰 비용 분석 및 최적화

### 📊 예상 비용 (ap-northeast-2 기준)

#### 기본 구성 월 비용
| 리소스 | 수량 | 단가 | 월 비용 (USD) |
|--------|------|------|---------------|
| **EKS 클러스터** | 1개 | $73.00 | $73.00 |
| **EC2 인스턴스** (t3.medium) | 3대 | $30.37 | $91.11 |
| **EBS 볼륨** (gp3, 50GB) | 3개 | $4.80 | $14.40 |
| **NAT Gateway** | 2개 | $32.85 | $65.70 |
| **Application Load Balancer** | 1개 | $16.43 | $16.43 |
| **CloudWatch 로그** | ~10GB | $0.50/GB | $5.00 |
| **KMS 키 사용** | 1개 | $1.00 | $1.00 |
| **총 예상 비용** | | | **~$266/월** |

#### 💡 비용 최적화 방안

**개발/테스트 환경용**
```hcl
# eks.tf에서 수정
eks_managed_node_groups = {
  main = {
    instance_types = ["t3.small"]     # $15.18 → $45.54/월 (3대)
    min_size       = 1
    max_size       = 3
    desired_size   = 1               # 1대로 축소
  }
}

# vpc.tf에서 수정
single_nat_gateway = true           # $32.85/월 절약
```
**절약 효과**: ~$148/월 → **$118/월** (약 30% 절약)

**운영 환경용 (고가용성)**
```hcl
eks_managed_node_groups = {
  main = {
    instance_types = ["m5.large"]     # 안정성 향상
    min_size       = 3
    max_size       = 10
    desired_size   = 5               # 5대 운영
  }
}
```
**예상 비용**: ~$400-500/월

### 🎛️ 비용 모니터링 설정

```bash
# AWS Cost Explorer로 일일 비용 확인
aws ce get-cost-and-usage \
  --time-period Start=2024-01-01,End=2024-01-31 \
  --granularity DAILY \
  --metrics BlendedCost \
  --group-by Type=DIMENSION,Key=SERVICE

# 리소스별 태그 확인 (비용 추적용)
aws resourcegroupstaggingapi get-resources \
  --tag-filters Key=Project,Values=eks-practice
```

### ⚠️ 비용 주의사항

1. **데이터 전송 비용**: 인터넷 아웃바운드 트래픽 (GB당 $0.09)
2. **로드밸런서 트래픽**: ArgoCD UI 접근량에 따른 추가 비용
3. **CloudWatch 세부 모니터링**: 활성화시 추가 비용
4. **EBS 스냅샷**: 자동 백업 활성화시 스토리지 비용

### 💸 즉시 비용 절약 팁

```bash
# 1. 사용하지 않는 리소스 정리
terraform destroy

# 2. 스팟 인스턴스 활용 (개발용)
# eks.tf에 추가
capacity_type = "SPOT"  # 최대 70% 절약 가능

# 3. 일정한 시간에만 운영
# 매일 18:00에 클러스터 정지, 09:00에 시작
```

## 🔗 참고 자료

- [AWS EKS Capability 문서](https://docs.aws.amazon.com/eks/latest/userguide/eks-capabilities.html)
- [AWS EKS 사용자 가이드](https://docs.aws.amazon.com/eks/latest/userguide/)
- [ArgoCD 공식 문서](https://argo-cd.readthedocs.io/)
- [terraform-aws-modules/eks](https://github.com/terraform-aws-modules/terraform-aws-eks)

## ❓ 자주 묻는 질문 (FAQ)

### Q: AWS Organizations 없이 사용할 수 있나요?
**A**: 아니요. EKS Capability는 AWS Organizations 필수입니다. 개인 계정의 경우:
```bash
cd ../eks-capability-for-argocd  # 표준 Helm 방식 사용
```

### Q: 배포에 얼마나 걸리나요?
**A**: 보통 15-25분 소요됩니다:
- EKS 클러스터: 10-15분
- ArgoCD Capability: 5-10분
- DNS 전파 및 안정화: 5분

### Q: 비용이 얼마나 드나요?
**A**: 기본 구성으로 월 $266 정도이며, 개발용으로 최적화하면 $118까지 절약 가능합니다.

### Q: 기존 EKS 클러스터에 Capability 추가 가능한가요?
**A**: 가능하지만, 이 프로젝트는 새 클러스터 생성용입니다. 기존 클러스터에는 수동 설정이 필요합니다.

### Q: ArgoCD UI에 접근할 수 없어요.
**A**: EKS Console을 통해 접근하세요:
```
AWS Console → EKS → 클러스터 선택 → Capabilities → ArgoCD
```

### Q: 다른 리전에서 사용할 수 있나요?
**A**: 네, `terraform.tfvars`에서 리전을 변경하세요:
```hcl
region = "us-east-1"  # 원하는 리전으로 변경
```

### Q: 프로덕션 환경에 적합한가요?
**A**: 네, 하지만 추가 고려사항:
- 백업 전략 수립
- 모니터링 강화
- 보안 정책 검토
- 재해 복구 계획

## 📞 지원 및 문의

### 🔧 문제 해결 순서
1. **환경 검증**: AWS Organizations, 권한, 도구 버전
2. **로그 확인**: `kubectl logs`, `terraform show`
3. **진단 스크립트**: 위의 트러블슈팅 섹션 참조
4. **단계별 재시도**: `terraform apply -target=...`

### 📋 이슈 리포팅시 포함할 정보
```bash
# 환경 정보
terraform --version
aws --version
kubectl version --client

# AWS 정보
aws sts get-caller-identity
aws organizations describe-organization 2>/dev/null || echo "No Orgs"

# 오류 로그
terraform show terraform.tfstate
kubectl describe capability argocd-capability -n argocd
```

---

## 🏁 결론

### ✅ 완성된 환경
이 프로젝트를 통해 다음이 구축됩니다:
- **엔터프라이즈급 EKS 클러스터** (v1.32, 최신 보안 설정)
- **AWS 네이티브 ArgoCD** (Capability 통합)
- **완전한 GitOps 인프라** (CI/CD 파이프라인 지원)
- **프로덕션 준비** (모니터링, 로깅, 암호화)

### 🚀 다음 단계
1. **첫 번째 앱 배포**: ArgoCD로 샘플 애플리케이션 배포
2. **CI/CD 파이프라인**: GitHub Actions 또는 GitLab CI 연동
3. **모니터링 구축**: Prometheus, Grafana 추가
4. **보안 강화**: Policy-as-Code, 취약점 스캔

### 🎯 학습 목표 달성
- ✅ **AWS EKS Capability** 마스터
- ✅ **GitOps 워크플로우** 이해
- ✅ **엔터프라이즈 인프라** 구축 경험
- ✅ **AWS 보안 베스트 프랙티스** 적용

---

**⚡ Quick Start**: `terraform init && terraform plan && terraform apply`

**💡 핵심**: AWS Organizations + EKS Capability = 엔터프라이즈급 GitOps 플랫폼