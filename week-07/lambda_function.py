import json
import boto3
from decimal import Decimal

# # Custom Serialization Converter: make Decimal to int or float
class DecimalEncoder(json.JSONEncoder):
    def default(self, obj):
        if isinstance(obj, Decimal):
            return int(obj) if obj % 1 == 0 else float(obj)
        return super(DecimalEncoder, self).default(obj)

dynamodb = boto3.resource('dynamodb')
table = dynamodb.Table('Properties')

def lambda_handler(event, context):
    listing_id = event['pathParameters']['id']
    resp = table.get_item(Key={'L_ListingID': listing_id})
    return {
        'statusCode': 200,
        'body': json.dumps(resp.get('Item', {}), cls=DecimalEncoder)
    }