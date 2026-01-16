# Variables for EKS Practice Environment

variable "region" {
  description = "AWS region"
  type        = string
  default     = "ap-northeast-2"
}

variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
  default     = "eks-argocd-practice"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "practice"
}

variable "owner" {
  description = "Owner of the resources"
  type        = string
  default     = "practice-team"
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "azs" {
  description = "Availability zones"
  type        = list(string)
  default     = ["ap-northeast-2a", "ap-northeast-2c"]
}

variable "private_subnets" {
  description = "Private subnet CIDR blocks"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "public_subnets" {
  description = "Public subnet CIDR blocks"
  type        = list(string)
  default     = ["10.0.101.0/24", "10.0.102.0/24"]
}

variable "common_tags" {
  description = "Common tags to be applied to all resources"
  type        = map(string)
  default = {
    Environment = "practice"
    ManagedBy   = "terraform"
    Owner       = "practice-team"
    Project     = "eks-practice"
  }
}