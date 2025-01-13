data "aws_lambda_function" "lambda_user_preference" {
  function_name = "LambdaUserPreference"
}

data "aws_lambda_function" "lambda_user_recommendation" {
  function_name = "LambdaUserRecommendation"
}

resource "aws_api_gateway_rest_api" "recommendation_book" {
  name = "RecommendationBook"
}

resource "aws_api_gateway_resource" "user_preference" {
  rest_api_id = aws_api_gateway_rest_api.recommendation_book.id
  parent_id   = aws_api_gateway_rest_api.recommendation_book.root_resource_id
  path_part   = "userpreference"
}

resource "aws_api_gateway_resource" "user_preference_user_id" {
  rest_api_id = aws_api_gateway_rest_api.recommendation_book.id
  parent_id   = aws_api_gateway_resource.user_preference.id
  path_part   = "{user_id}"
}

resource "aws_api_gateway_resource" "user_recommendation" {
  rest_api_id = aws_api_gateway_rest_api.recommendation_book.id
  parent_id   = aws_api_gateway_rest_api.recommendation_book.root_resource_id
  path_part   = "userrecommendation"
}

resource "aws_api_gateway_resource" "user_recommendation_user_id" {
  rest_api_id = aws_api_gateway_rest_api.recommendation_book.id
  parent_id   = aws_api_gateway_resource.user_recommendation.id
  path_part   = "{user_id}"
}

resource "aws_api_gateway_method" "user_preference_methods" {
  for_each = toset(["POST", "GET", "PUT", "DELETE"])
  rest_api_id   = aws_api_gateway_rest_api.recommendation_book.id
  resource_id   = aws_api_gateway_resource.user_preference.id
  http_method   = each.value
  authorization = "NONE"
}

resource "aws_api_gateway_method" "user_preference_user_id_get" {
  rest_api_id   = aws_api_gateway_rest_api.recommendation_book.id
  resource_id   = aws_api_gateway_resource.user_preference_user_id.id
  http_method   = "GET"
  authorization = "NONE"
  request_parameters = {
    "method.request.path.user_id" = true
  }
}

resource "aws_api_gateway_method" "user_recommendation_get" {
  rest_api_id   = aws_api_gateway_rest_api.recommendation_book.id
  resource_id   = aws_api_gateway_resource.user_recommendation.id
  http_method   = "GET"
  authorization = "NONE"
}

resource "aws_api_gateway_method" "user_recommendation_user_id_get" {
  rest_api_id   = aws_api_gateway_rest_api.recommendation_book.id
  resource_id   = aws_api_gateway_resource.user_recommendation_user_id.id
  http_method   = "GET"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "user_preference_integration" {
  for_each = aws_api_gateway_method.user_preference_methods
  rest_api_id = aws_api_gateway_rest_api.recommendation_book.id
  resource_id = aws_api_gateway_resource.user_preference.id
  http_method = each.value.http_method
  integration_http_method = "POST"
  type = "AWS_PROXY"
  uri = data.aws_lambda_function.lambda_user_preference.invoke_arn
}

resource "aws_api_gateway_integration" "user_preference_user_id_get_integration" {
  rest_api_id = aws_api_gateway_rest_api.recommendation_book.id
  resource_id = aws_api_gateway_resource.user_preference_user_id.id
  http_method = aws_api_gateway_method.user_preference_user_id_get.http_method
  integration_http_method = "POST"
  type = "AWS_PROXY"
  uri = data.aws_lambda_function.lambda_user_preference.invoke_arn
  request_parameters = {
    "integration.request.path.user_id" = "method.request.path.user_id"
  }
}

resource "aws_api_gateway_integration" "recommendation_get_integration" {
  rest_api_id = aws_api_gateway_rest_api.recommendation_book.id
  resource_id = aws_api_gateway_resource.user_recommendation.id
  http_method = aws_api_gateway_method.user_recommendation_get.http_method
  integration_http_method = "POST"
  type = "AWS_PROXY"
  uri = data.aws_lambda_function.lambda_user_recommendation.invoke_arn
}

resource "aws_api_gateway_integration" "recommendation_user_id_get_integration" {
  rest_api_id = aws_api_gateway_rest_api.recommendation_book.id
  resource_id = aws_api_gateway_resource.user_recommendation_user_id.id
  http_method = aws_api_gateway_method.user_recommendation_user_id_get.http_method
  integration_http_method = "POST"
  type = "AWS_PROXY"
  uri = data.aws_lambda_function.lambda_user_recommendation.invoke_arn
}

resource "aws_api_gateway_method" "root_any_method" {
  rest_api_id   = aws_api_gateway_rest_api.recommendation_book.id
  resource_id   = aws_api_gateway_rest_api.recommendation_book.root_resource_id
  http_method   = "ANY"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "root_any_integration" {
  rest_api_id = aws_api_gateway_rest_api.recommendation_book.id
  resource_id = aws_api_gateway_rest_api.recommendation_book.root_resource_id
  http_method = aws_api_gateway_method.root_any_method.http_method
  integration_http_method = "POST"
  type = "MOCK"
}

resource "aws_api_gateway_deployment" "recommendation_book_deployment" {
  depends_on = [
    aws_api_gateway_integration.user_preference_user_id_get_integration,
    aws_api_gateway_integration.user_preference_integration,
    aws_api_gateway_integration.recommendation_get_integration,
    aws_api_gateway_integration.recommendation_user_id_get_integration,
    aws_api_gateway_integration.root_any_integration
  ]
  rest_api_id = aws_api_gateway_rest_api.recommendation_book.id
}

resource "aws_api_gateway_stage" "prod" {
  deployment_id = aws_api_gateway_deployment.recommendation_book_deployment.id
  rest_api_id   = aws_api_gateway_rest_api.recommendation_book.id
  stage_name    = "prod"
}

resource "aws_lambda_permission" "api_gateway_invoke_user_preference" {
  for_each = toset(["POST", "GET", "PUT", "DELETE"])
  statement_id  = "AllowAPIGatewayInvoke_${each.value}"
  action        = "lambda:InvokeFunction"
  function_name = data.aws_lambda_function.lambda_user_preference.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.recommendation_book.execution_arn}/*/${each.value}/userpreference"
}

resource "aws_lambda_permission" "api_gateway_invoke_user_preference_user_id_get" {
  statement_id  = "AllowAPIGatewayInvoke_GET_user_id"
  action        = "lambda:InvokeFunction"
  function_name = data.aws_lambda_function.lambda_user_preference.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.recommendation_book.execution_arn}/*/GET/userpreference/*"
}

resource "aws_lambda_permission" "api_gateway_invoke_recommendation" {
  statement_id  = "AllowAPIGatewayInvoke_GET"
  action        = "lambda:InvokeFunction"
  function_name = data.aws_lambda_function.lambda_user_recommendation.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.recommendation_book.execution_arn}/*/GET/userrecommendation"
}

resource "aws_lambda_permission" "api_gateway_invoke_recommendation_user_id_get" {
  statement_id  = "AllowAPIGatewayInvoke_GET_user_id"
  action        = "lambda:InvokeFunction"
  function_name = data.aws_lambda_function.lambda_user_recommendation.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.recommendation_book.execution_arn}/*/GET/userrecommendation/*"
}

resource "aws_api_gateway_method" "user_preference_user_id_any" {
  rest_api_id   = aws_api_gateway_rest_api.recommendation_book.id
  resource_id   = aws_api_gateway_resource.user_preference_user_id.id
  http_method   = "ANY"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "user_preference_user_id_any_integration" {
  rest_api_id             = aws_api_gateway_rest_api.recommendation_book.id
  resource_id             = aws_api_gateway_resource.user_preference_user_id.id
  http_method             = "ANY"
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = data.aws_lambda_function.lambda_user_preference.invoke_arn
}

output "api_gateway_url" {
  value = "https://${aws_api_gateway_rest_api.recommendation_book.id}.execute-api.${var.region}.amazonaws.com/prod"
}

variable "region" {
  default = "sa-east-1"
}