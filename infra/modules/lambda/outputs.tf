output "level_1_arn" {
  value = aws_lambda_function.level_1.arn
}

output "level_2_arn" {
  value = aws_lambda_function.level_2.arn
}

output "level_3_arn" {
  value = aws_lambda_function.level_3.arn
}

output "level_evaluator_function_arn" {
  value = aws_lambda_function.level_evaluator.arn
}

output "level_evaluator_function_name" {
  value = aws_lambda_function.level_evaluator.function_name
}
