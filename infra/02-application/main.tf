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
  role          = data.aws_iam_role.lambda_exec_role.arn
  
  image_uri     = "${data.aws_ecr_repository.app_repo.repository_url}:latest"
  
  timeout       = 30
  memory_size   = 1024
  architectures = ["x86_64"]

  environment {
    variables = {
      REFRESH_ON_APPLY = timestamp()
    }
  }
}

resource "aws_lambda_function_url" "app_lambda_url" {
  function_name    = aws_lambda_function.app_lambda.function_name
  authorization_type = "NONE"
}

resource "aws_cloudfront_distribution" "app_cdn" {
  origin {
    domain_name = replace(aws_lambda_function_url.app_lambda_url.function_url, "https://", "")
    origin_id   = "lambda-origin"

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "https-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  enabled             = true
  is_ipv6_enabled     = true
  default_root_object = "index.html"

  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "lambda-origin"
    
    viewer_protocol_policy = "redirect-to-https"

    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }
}

output "website_url" {
  description = "Die URL unserer Webseite (via CloudFront)"
  value       = "https://${aws_cloudfront_distribution.app_cdn.domain_name}"
}