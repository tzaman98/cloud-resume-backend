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

# Lambda

# Create role for Lambda usage

resource "aws_iam_role" "tf_CloudLambdaDynamoDBRole"{
    name = "tf_CloudLambdaDynamoDBRole"
    assume_role_policy = <<EOF
        {
            "Version": "2012-10-17",
            "Statement": [
                {
                    "Effect": "Allow",
                    "Principal": {
                        "Service": "lambda.amazonaws.com"
                    },
                    "Action": "sts:AssumeRole"
                }   
            ]
        }
    EOF
}

# Create policy for role tf_CloudLambdaDynamoDBRole

resource "aws_iam_policy" "tf_CloudLambdaDynamoDBPolicy" {
    name = "tf_CloudLambdaDynamoDBPolicy"
    policy = jsonencode(
        {
            "Version": "2012-10-17",
            "Statement": [
                {
                    "Effect": "Allow",
                    "Action": [
                        "dynamodb:BatchGetItem",
                        "dynamodb:GetItem",
                        "dynamodb:Query",
                        "dynamodb:Scan",
                        "dynamodb:BatchWriteItem",
                        "dynamodb:PutItem",
                        "dynamodb:UpdateItem"
                    ],
                    "Resource": "arn:aws:dynamodb:us-east-1:179830444787:table/tf_cloudvisitorcounttable"
                }
                
            ]
        }
    )
}

# Attach role and policy

resource  "aws_iam_role_policy_attachment" "tf_CloudLambdaDynamoDBPolicy_Attachment" {
    role = aws_iam_role.tf_CloudLambdaDynamoDBRole.name
    policy_arn = aws_iam_policy.tf_CloudLambdaDynamoDBPolicy.arn
}

#Create Lambda function:

resource "aws_lambda_function" "tf_CloudLambdaFunction" {
    filename = "lambda_function.zip"
    function_name = "tf_CloudLambdaFunction"
    role = aws_iam_role.tf_CloudLambdaDynamoDBRole.arn
    handler = "lambda_function.lambda_handler"
    runtime = "python3.9"
    source_code_hash = filebase64sha256("lambda_function.zip")
}