output "guardduty_detector" {
  description = "GuardDuty detector"
  value       = one(aws_guardduty_detector.guardduty[*])
}

output "sns_topic" {
  description = "SNS topic"
  value       = module.sns_topic.sns_topic
}

output "sns_topic_subscriptions" {
  description = "SNS topic subscriptions"
  value       = module.sns_topic.aws_sns_topic_subscriptions
}
