import json
import boto3

client = boto3.client('dynamodb')

TableName = 'tf_cloudvisitorcounttable'
def lambda_handler(event, context):
    
    #Retrives current visit count
    data = client.get_item(
        TableName = 'tf_cloudvisitorcounttable',
        Key = {
            'view-count': {'S': 'view-count'}
        }
    
    )
    previousViewCount = data['Item']['Quantity']['N']
    
    # Increment view count
    response = client.update_item(
        TableName = 'tf_cloudvisitorcounttable',
        Key = {
            'view-count': {'S': 'view-count'}
        },
        UpdateExpression = 'ADD Quantity :inc',
        ExpressionAttributeValues = {":inc" : {"N": "1"}},
        ReturnValues = 'UPDATED_NEW'
    )
    
    value = response['Attributes']['Quantity']['N']
    
    return {
        'statusCode': 200,
        'body': value
    }
