## PROVIDER DECLARATION 
provider "aws" {
  profile = var.aws_profile
  region  = var.aws_region# Setting my region to London. Use your own region here
}

## ------------------------------------------------------------------------------------------------------------------------------------------------- ##

## ECR
resource "aws_ecr_repository" "api_ecr_repo" {
  name = var.repo_name # Naming my repository
  image_tag_mutability = "IMMUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }
}

resource "aws_ecr_lifecycle_policy" "repositoryPolicy" {
  repository = aws_ecr_repository.api_ecr_repo.name

  policy = <<EOF
{
    "rules": [
        {
            "rulePriority": 1,
            "description": "Delete older images",
            "selection": {
                "tagStatus": "any",
                "countType": "imageCountMoreThan",
                "countNumber": 2
            },
            "action": {
                "type": "expire"
            }
        }
    ]
}
EOF
}

## ------------------------------------------------------------------------------------------------------------------------------------------------- ##

## VARIABLE DECLARATION

variable aws_profile {}
variable aws_region {}
variable repo_name {}
