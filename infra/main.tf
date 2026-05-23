terraform {
  required_version = ">= 1.14"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.94"
    }
  }
}

provider "aws" {
  region  = var.aws_region
  profile = var.aws_profile
}

module "dynamodb" {
  source = "./modules/dynamodb"
}

module "lambda" {
  source           = "./modules/lambda"
  state_table_name = module.dynamodb.table_name
  state_table_arn  = module.dynamodb.table_arn
}

module "step_functions" {
  source           = "./modules/step_functions"
  state_table_name = module.dynamodb.table_name
  state_table_arn  = module.dynamodb.table_arn
  level_1_arn      = module.lambda.level_1_arn
  level_2_arn      = module.lambda.level_2_arn
  level_3_arn      = module.lambda.level_3_arn
}

module "eventbridge" {
  source                        = "./modules/eventbridge"
  level_evaluator_function_arn  = module.lambda.level_evaluator_function_arn
  level_evaluator_function_name = module.lambda.level_evaluator_function_name
}

module "api_gateway" {
  source            = "./modules/api_gateway"
  state_machine_arn = module.step_functions.state_machine_arn
  aws_region        = var.aws_region
}
