terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}


resource "aws_ecr_repository" "app_repo" {
  name = var.project_name

  image_tag_mutability = "MUTABLE"
  force_delete         = true

  image_scanning_configuration {
    scan_on_push = true
  }
}

data "aws_iam_policy_document" "lambda_assume_role_policy" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "lambda_exec_role" {
  name               = "${var.project_name}-lambda-exec-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role_policy.json
}

resource "aws_iam_role_policy_attachment" "lambda_basic_execution" {
  role       = aws_iam_role.lambda_exec_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy_attachment" "lambda_ecr_readonly" {
  role       = aws_iam_role.lambda_exec_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}


resource "aws_lambda_function" "app_lambda" {
  function_name = "${var.project_name}-website"
  package_type  = "Image"
  role          = aws_iam_role.lambda_exec_role.arn
  
  image_uri     = "${aws_ecr_repository.app_repo.repository_url}:latest"
  
  timeout       = 10
  memory_size   = 128
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

#resource "aws_cloudfront_distribution" "app_cdn" {
#  origin {
#    domain_name = replace(aws_lambda_function_url.app_lambda_url.function_url, "https://", "")
#    origin_id   = "lambda-origin"
#
#    custom_origin_config {
#      http_port              = 80
#      https_port             = 443
#      origin_protocol_policy = "https-only"
#      origin_ssl_protocols   = ["TLSv1.2"]
#    }
#  }
#
#  enabled             = true
#  is_ipv6_enabled     = true
#  
#  default_cache_behavior {
#    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
#    cached_methods   = ["GET", "HEAD"]
#    target_origin_id = "lambda-origin"
#    
#    viewer_protocol_policy = "redirect-to-https"
#
#    forwarded_values {
#      query_string = false
#      headers      = ["*"]
#      cookies {
#        forward = "none"
#      }
#    }
#
#    min_ttl                = 0
#    default_ttl            = 60
#    max_ttl                = 86400
#  }
#
#  restrictions {
#    geo_restriction {
#      restriction_type = "none"
#    }
#  }
#
#  viewer_certificate {
#    cloudfront_default_certificate = true
#  }
#}

#output "website_url" {
#  description = "Die URL der Webseite"
#  value       = "https://${aws_cloudfront_distribution.app_cdn.domain_name}"
#}

output "lambda_function_url" {
  description = "Die temp. direkte URL zur Lambda-Funktion"
  value       = aws_lambda_function_url.app_lambda_url.function_url
}

output "ecr_repository_url" {
  description = "Die URL des ECR-Repositorys"
  value       = aws_ecr_repository.app_repo.repository_url
}