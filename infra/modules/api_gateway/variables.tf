variable "state_machine_arn" {
  description = "ARN of the Step Functions state machine to invoke synchronously"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
  type        = string
}
