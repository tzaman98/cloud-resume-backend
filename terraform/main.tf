terraform {
  required_providers {
    aws = {
        source = "hashicorp/aws"
        version = "~> 4.0"
    }
  }
}

# Configure AWS Provider
provider "aws" {
    region = "us-east-1"
}

## DYNAMODB

# Create the DynamoDB table

resource "aws_dynamodb_table" "tf_cloudvisitorcounttable" {
    name = "tf_cloudvisitorcounttable"
    hash_key = "view-count"
    billing_mode = "PAY_PER_REQUEST"
    attribute {
      name = "view-count"
      type = "S"
    }
}

# Create table item for table tf_cloudvisitorcounttable

resource "aws_dynamodb_table_item" "tf_cloudvisitorcounttable_items" {
    table_name = aws_dynamodb_table.tf_cloudvisitorcounttable.name
    hash_key = aws_dynamodb_table.tf_cloudvisitorcounttable.hash_key
    item = <<EOF
        {
            "view-count":{"S": "view-count"},
            "Quantity":{"N": "20"}
        }
    EOF
}