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

## API Gateway

# Give Lambda permissions for API gateway
resource "aws_lambda_permission" "tf_APIGateway_LambdaPermission" {
    statement_id = "AllowExecutionFromAPIGateway"
    action = "lambda:InvokeFunction"
    function_name = aws_lambda_function.tf_CloudLambdaFunction.function_name
    principal = "apigateway.amazonaws.com"
    source_arn = "${aws_api_gateway_rest_api.tf_APIGateway_CloudLambdaFunction.execution_arn}/*"

    depends_on = [
      aws_api_gateway_rest_api.tf_APIGateway_CloudLambdaFunction
    ]
}
# Create rest API Gateway
resource "aws_api_gateway_rest_api" "tf_APIGateway_CloudLambdaFunction" {
    name = "tf_APIGateway_CloudLambdaFunction"
    endpoint_configuration {
      types = ["REGIONAL"]
    }
}

# API gateway resource
resource "aws_api_gateway_resource" "tf_getGW"{
    parent_id = aws_api_gateway_rest_api.tf_APIGateway_CloudLambdaFunction.root_resource_id
    path_part = "GET"
    rest_api_id = aws_api_gateway_rest_api.tf_APIGateway_CloudLambdaFunction.id
}

# API gateway method
resource "aws_api_gateway_method" "tf_methodGW" {
    authorization = "NONE"
    http_method = "GET"
    resource_id = aws_api_gateway_resource.tf_getGW.id
    rest_api_id = aws_api_gateway_rest_api.tf_APIGateway_CloudLambdaFunction.id
}

# API gateway method lambda integration

resource "aws_api_gateway_integration" "tf_integration" {
    rest_api_id = aws_api_gateway_rest_api.tf_APIGateway_CloudLambdaFunction.id
    resource_id = aws_api_gateway_resource.tf_getGW.id
    http_method = aws_api_gateway_method.tf_methodGW.http_method
    integration_http_method = "POST"
    type = "AWS"
    uri = aws_lambda_function.tf_CloudLambdaFunction.invoke_arn
}

# API gateway method response
resource "aws_api_gateway_method_response" "tf_APIGateway_Response200" {
    rest_api_id = aws_api_gateway_rest_api.tf_APIGateway_CloudLambdaFunction.id
    resource_id = aws_api_gateway_resource.tf_getGW.id
    http_method = aws_api_gateway_method.tf_methodGW.http_method
    status_code = "200"
    
    response_models = {
        "application/json" = "Empty"
    }
    response_parameters = {
        "method.response.header.Access-Control-Allow-Origin"  = true
    }
}

# API gateway method integration response from Lambda
resource "aws_api_gateway_integration_response" "tf_integration_response" {
    rest_api_id = aws_api_gateway_rest_api.tf_APIGateway_CloudLambdaFunction.id
    resource_id = aws_api_gateway_resource.tf_getGW.id
    http_method = aws_api_gateway_method.tf_methodGW.http_method
    status_code = aws_api_gateway_method_response.tf_APIGateway_Response200.status_code
    
    response_parameters = {
        "method.response.header.Access-Control-Allow-Origin" = "'*'"
    }

}

# API gateway method options
resource "aws_api_gateway_method" "tf_method_options" {
    rest_api_id = aws_api_gateway_rest_api.tf_APIGateway_CloudLambdaFunction.id
    resource_id = aws_api_gateway_resource.tf_getGW.id
    http_method = "OPTIONS"
    authorization = "NONE"
    api_key_required = false
}

# API gateway method options response
resource "aws_api_gateway_method_response" "tf_optionsMethodResponse" {
    rest_api_id = aws_api_gateway_rest_api.tf_APIGateway_CloudLambdaFunction.id
    resource_id = aws_api_gateway_resource.tf_getGW.id
    http_method = aws_api_gateway_method.tf_method_options.http_method
    status_code = "200"
    response_models = {
      "application/json" = "Empty"
    }
    response_parameters = {
      "method.response.header.Access-Control-Allow-Headers" = true
      "method.response.header.Access-Control-Allow-Methods" = true
      "method.response.header.Access-Control-Allow-Origin"  = true
    }
}

# API gateway options integration

resource "aws_api_gateway_integration" "tf_options_integration" {
    rest_api_id = aws_api_gateway_rest_api.tf_APIGateway_CloudLambdaFunction.id
    resource_id = aws_api_gateway_resource.tf_getGW.id
    http_method = "OPTIONS"
    type = "MOCK"
    passthrough_behavior = "WHEN_NO_MATCH"
    request_templates = {
      "application/json" : "{\"statusCode\": 200}"
    }
}

# API gateway options integration response
resource "aws_api_gateway_integration_response" "tf_options_integration_response" {
    rest_api_id = aws_api_gateway_rest_api.tf_APIGateway_CloudLambdaFunction.id
    resource_id = aws_api_gateway_resource.tf_getGW.id
    http_method = aws_api_gateway_integration.tf_options_integration.http_method
    status_code = "200"
    response_parameters = {
        "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'"
        "method.response.header.Access-Control-Allow-Headers" = "'GET,OPTIONS'"
        "method.response.header.Access-Control-Allow-Origin"  = "'*'"
    }
}

# Create api gateway deployment
resource "aws_api_gateway_deployment" "tf_CloudAPIGWDeployment" {
    rest_api_id = aws_api_gateway_rest_api.tf_APIGateway_CloudLambdaFunction.id

    triggers = {
        redeployment = sha1(jsonencode([
            aws_api_gateway_resource.tf_getGW,
            aws_api_gateway_method.tf_methodGW,
            aws_api_gateway_method.tf_method_options,
            aws_api_gateway_integration.tf_integration
        ]))
    }

    lifecycle {
      create_before_destroy = true 
    }
}

# Create the API gateway stage
resource "aws_api_gateway_stage" "tf_stage" {
    deployment_id = aws_api_gateway_deployment.tf_CloudAPIGWDeployment.id
    rest_api_id = aws_api_gateway_rest_api.tf_APIGateway_CloudLambdaFunction.id
    stage_name = "dev"
}