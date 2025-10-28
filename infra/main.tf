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

  lifecycle {
    ignore_changes = [
      image_uri,
    ]
  }
}

resource "aws_lambda_function_url" "app_lambda_url" {
  function_name    = aws_lambda_function.app_lambda.function_name
  authorization_type = "NONE"
  invoke_mode      = "RESPONSE_STREAM" 
}

resource "aws_wafv2_web_acl" "lambda_waf" {
  name  = "${var.project_name}-waf"
  
  scope = "REGIONAL"

  default_action {
    allow {}
  }

  rule {
    name     = "AWS-Managed-Common-Rules"
    priority = 1

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        vendor_name = "AWS"
        name        = "AWSManagedRulesCommonRuleSet"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.project_name}-waf-common"
      sampled_requests_enabled   = true
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "${var.project_name}-waf"
    sampled_requests_enabled   = true
  }
}

resource "aws_wafv2_web_acl_association" "lambda_waf_assoc" {
  web_acl_arn = aws_wafv2_web_acl.lambda_waf.arn
  resource_arn = aws_lambda_function.app_lambda.arn
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

output "website_url" {
  description = "Die URL der Webseite"
  value       = "https://${aws_cloudfront_distribution.app_cdn.domain_name}"
}

output "lambda_function_url" {
  description = "Die temp. direkte URL zur Lambda-Funktion"
  value       = aws_lambda_function_url.app_lambda_url.function_url
}

output "ecr_repository_url" {
  description = "Die URL des ECR-Repositorys"
  value       = aws_ecr_repository.app_repo.repository_url
}