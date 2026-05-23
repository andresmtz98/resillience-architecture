variable "state_table_name" {
  description = "DynamoDB state table name"
  type        = string
}

variable "state_table_arn" {
  description = "DynamoDB state table ARN"
  type        = string
}

variable "level_1_arn" {
  description = "ARN of Lambda Level 1 (Full)"
  type        = string
}

variable "level_2_arn" {
  description = "ARN of Lambda Level 2 (Degraded)"
  type        = string
}

variable "level_3_arn" {
  description = "ARN of Lambda Level 3 (Maintenance)"
  type        = string
}
