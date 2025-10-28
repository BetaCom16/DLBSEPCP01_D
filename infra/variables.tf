variable "project_name" {
  description = "Der Basisname für alle Ressourcen"
  type        = string
  default     = "cpmodule2025"
}

variable "aws_region" {
  description = "Die AWS-Region für die Bereitstellung"
  type        = string
  default     = "eu-central-1"
}