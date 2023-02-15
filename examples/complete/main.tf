provider "aws" {
  region = var.region
}

module "guardduty" {
  source = "../.."

  create_sns_topic = var.create_sns_topic

  context = module.context.self
}
