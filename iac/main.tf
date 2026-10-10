terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws     = { source = "hashicorp/aws", version = "~> 5.0" }
    archive = { source = "hashicorp/archive", version = "~> 2.4" }
    random  = { source = "hashicorp/random", version = "~> 3.6" }
  }
}

provider "aws" {
  region  = var.aws_region
  profile = var.aws_profile
}

variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "aws_profile" {
  type    = string
  default = "JosepPF"
}

variable "environment" {
  type = string
  validation {
    condition     = contains(["dev", "qa", "prod"], var.environment)
    error_message = "environment debe ser dev, qa o prod."
  }
}

variable "vpc_cidr" {
  type    = string
  default = "10.0.0.0/16"
}