terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

provider "aws" {
  region = "eu-central-1"
}

data "aws_ecr_repository" "app_repo" {
  name = "cpmodule2025"
}

data "aws_iam_role" "lambda_exec_role" {
  name = "lambda-exec-role-cpmodule2025"
}

resource "aws_lambda_function" "app_lambda" {
  function_name = "cpmodule2025-website"
  package_type  = "Image"

  role = data.aws_iam_role.lambda_exec_role.arn

  image_uri = "${data.aws_ecr_repository.app_repo.repository_url}:latest"
  
  timeout = 30
}