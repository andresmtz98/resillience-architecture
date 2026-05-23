resource "aws_cloudwatch_event_rule" "level_evaluator_schedule" {
  name                = "ultraseguros-level-evaluator-schedule"
  description         = "Triggers the Level Evaluator Lambda at the start of every minute (UTC)"
  schedule_expression = "cron(* * * * ? *)"
}

resource "aws_cloudwatch_event_target" "level_evaluator_target" {
  rule = aws_cloudwatch_event_rule.level_evaluator_schedule.name
  arn  = var.level_evaluator_function_arn
}

resource "aws_lambda_permission" "allow_eventbridge" {
  statement_id  = "AllowEventBridgeInvoke"
  action        = "lambda:InvokeFunction"
  function_name = var.level_evaluator_function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.level_evaluator_schedule.arn
}
