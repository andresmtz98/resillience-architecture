locals {
  runtime       = "nodejs22.x"
  architectures = ["arm64"]
  handlers_path = "${path.module}/../../../handlers"

  # Custom metric namespace
  metric_namespace = "UltraSeguros/Resilience"
}
