#-----------------------------------------------------------------------------------------------------------------------
# Subscribe the Acccount to GuardDuty
#-----------------------------------------------------------------------------------------------------------------------
resource "aws_guardduty_detector" "guardduty" {
  #checkov:skip=CKV2_AWS_3:skipping 'Ensure GuardDuty is enabled to specific org/region'
  count                        = module.context.enabled ? 1 : 0
  enable                       = module.context.enabled
  finding_publishing_frequency = var.finding_publishing_frequency

  datasources {
    s3_logs {
      enable = var.s3_protection_enabled
    }
  }
}

#-----------------------------------------------------------------------------------------------------------------------
# Optionally configure Event Bridge Rules and SNS subscriptions
# https://docs.aws.amazon.com/securityhub/latest/userguide/securityhub-cwe-integration-types.html
# https://docs.aws.amazon.com/AmazonCloudWatch/latest/events/resource-based-policies-cwe.html#sns-permissions
#-----------------------------------------------------------------------------------------------------------------------
module "sns_topic" {
  source     = "SevenPicoForks/sns-topic/aws"
  version    = "2.0.0"
  context    = module.context.self
  enabled    = local.create_sns_topic
  attributes = concat(module.context.attributes, ["guardduty"])

  subscribers     = var.subscribers
  sqs_dlq_enabled = false
}

module "findings_label" {
  source     = "SevenPico/context/null"
  version    = "2.0.0"
  context    = module.context.self
  attributes = concat(module.context.attributes, ["guardduty", "findings"])
}

resource "aws_sns_topic_policy" "sns_topic_publish_policy" {
  count  = module.context.enabled && local.create_sns_topic ? 1 : 0
  arn    = local.findings_notification_arn
  policy = data.aws_iam_policy_document.sns_topic_policy[0].json
}

data "aws_iam_policy_document" "sns_topic_policy" {
  count     = module.context.enabled && local.create_sns_topic ? 1 : 0
  policy_id = "GuardDutyPublishToSNS"
  statement {
    sid = ""
    actions = [
      "sns:Publish"
    ]
    principals {
      type        = "Service"
      identifiers = ["cloudwatch.amazonaws.com"]
    }
    resources = [module.sns_topic[0].sns_topic.arn]
    effect    = "Allow"
  }
}

resource "aws_cloudwatch_event_rule" "findings" {
  count       = local.enable_cloudwatch == true ? 1 : 0
  name        = module.findings_label.id
  description = "GuardDuty Findings"
  tags        = module.context.tags

  event_pattern = jsonencode(
    {
      "source" : [
        "aws.guardduty"
      ],
      "detail-type" : [
        var.cloudwatch_event_rule_pattern_detail_type
      ]
    }
  )
}

resource "aws_cloudwatch_event_target" "imported_findings" {
  count = local.enable_notifications == true ? 1 : 0
  rule  = aws_cloudwatch_event_rule.findings[0].name
  arn   = local.findings_notification_arn
}

#-----------------------------------------------------------------------------------------------------------------------
# Locals and Data References
#-----------------------------------------------------------------------------------------------------------------------
locals {
  enable_cloudwatch         = module.context.enabled && (var.enable_cloudwatch || local.enable_notifications)
  enable_notifications      = module.context.enabled && (var.create_sns_topic || var.findings_notification_arn != null)
  create_sns_topic          = module.context.enabled && var.create_sns_topic
  findings_notification_arn = local.enable_notifications ? (var.findings_notification_arn != null ? var.findings_notification_arn : module.sns_topic[0].sns_topic.arn) : null
}
