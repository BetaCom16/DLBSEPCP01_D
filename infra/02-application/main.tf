terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

variable "image_tag" {
  type        = string
  description = "Der bereitgestellte Docker Image Tag"
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
  image_uri     = "${data.aws_ecr_repository.app_repo.repository_url}:${var.image_tag}"
  timeout       = 30

  memory_size   = 1024 
}

data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

resource "aws_security_group" "alb_sg" {
  name        = "alb-security-group"
  description = "Erlaubt HTTP-Traffic zum ALB"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_lb" "app_alb" {
  name               = "meine-app-alb"
  internal           = false
  load_balancer_type = "application"
  
  security_groups = [aws_security_group.alb_sg.id]
  
  subnets = data.aws_subnets.default.ids
}

resource "aws_lb_target_group" "lambda_tg" {
  name        = "lambda-target-group"
  target_type = "lambda"
}

resource "aws_lambda_permission" "alb_permission" {
  statement_id  = "AllowExecutionFromALB"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.app_lambda.arn
  principal     = "elasticloadbalancing.amazonaws.com"
  source_arn    = aws_lb_target_group.lambda_tg.arn
}

resource "aws_lb_target_group_attachment" "lambda_attachment" {
  target_group_arn = aws_lb_target_group.lambda_tg.arn
  target_id        = aws_lambda_function.app_lambda.arn
  
  depends_on = [aws_lambda_permission.alb_permission]
}

resource "aws_lb_listener" "http_listener" {
  load_balancer_arn = aws_lb.app_alb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.lambda_tg.arn
  }
}

output "website_url" {
  description = "Die URL der Webseite"
  value       = "http://${aws_lb.app_alb.dns_name}"
}