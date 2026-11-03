# Week 7 — Serverless & Event-Driven Architecture

## 1. Overview
In this lab, PropertyLite's read path was refactored from an always-on EC2 compute instance into a fully serverless, event-driven pattern using **Amazon API Gateway (HTTP API)**, **AWS Lambda (Python 3.12)**, and **Amazon DynamoDB**. In addition, an asynchronous messaging subsystem was provisioned using **Amazon SQS** with a configured **Dead-Letter Queue (DLQ)**.

---

## 2. Request Path Architecture

### Architecture Flowchart
mermaid
flowchart LR
    Client([Client / Laptop]) -->|GET /properties/{id}| APIGW[API Gateway HTTP API\nm9k6eqk8v1.execute-api]
    APIGW -->|Proxy Payload Event| Lambda[AWS Lambda\nget-property]
    Lambda -->|GetItem L_ListingID| DynamoDB[(DynamoDB Table\nProperties)]
    DynamoDB -->|Item Document| Lambda
    Lambda -->|JSON 200 OK| APIGW
    APIGW -->|HTTP Response| Client
    

### Detailed Sequence Diagram
```
+--------+                 +-------------+                 +------------+                 +------------+
| Client |                 | API Gateway |                 |   Lambda   |                 |  DynamoDB  |
+--------+                 +-------------+                 +------------+                 +------------+
    |                             |                               |                              |
    |  GET /properties/R100234    |                               |                              |
    |---------------------------->|                               |                              |
    |                             |  Invoke Function Event        |                              |
    |                             |------------------------------>|                              |
    |                             |                               |  GetItem(Key=R100234)        |
    |                             |                               |----------------------------->|
    |                             |                               |                              |
    |                             |                               |  Return Item Document        |
    |                             |                               |<-----------------------------|
    |                             |  Return {200, Body JSON}      |                              |
    |                             |<------------------------------|                              |
    |  HTTP 200 OK (JSON)         |                               |                              |
    |<----------------------------|                               |                              |
```

---

## 3. Read Path Implementation & Test Verification

### 3.1 Endpoint Details
* **Region**: `us-west-1`
* **API Gateway ID**: `m9k6eqk8v1`
* **Route**: `GET /properties/{id}`
* **Invoke URL**: `https://m9k6eqk8v1.execute-api.us-west-1.amazonaws.com/properties/{id}`

### 3.2 Debugging & Resolution (Debug Lab 7.3)
During initial testing, the endpoint returned:
```bash
curl https://m9k6eqk8v1.execute-api.us-west-1.amazonaws.com/properties/R100234
# Output: {"message":"Internal Server Error"}
```

**CloudWatch Logs Root Cause Analysis:**
Inspection of `/aws/lambda/get-property` CloudWatch Logs revealed:
```text
[ERROR] TypeError: Object of type Decimal is not JSON serializable
Traceback (most recent call last):
  File "/var/task/lambda_function.py", line 11, in lambda_handler
    'body': json.dumps(resp.get('Item', {}))
  ...
  raise TypeError(f'Object of type {o.__class__.__name__} is not JSON serializable')
```
* **Cause**: DynamoDB numeric attributes (`L_SystemPrice`, `L_Keyword2`) are deserialized by `boto3` into Python's `decimal.Decimal` objects, which standard `json.dumps()` cannot serialize.
* **Fix**: Implemented a custom `DecimalEncoder` subclassing `json.JSONEncoder` to cast `Decimal` to standard integers/floats before returning the response.

### 3.3 Successful Test Output
```bash
root@WIN-4KVQ1CQRK4L:~# curl https://m9k6eqk8v1.execute-api.us-west-1.amazonaws.com/properties/R100234
{"L_SystemPrice": 450000, "L_Keyword2": 3, "L_ListingID": "R100234", "L_City": "Sacramento"}
```

---

## 4. IAM Least-Privilege Policy Analysis

### Policy Specification
The Lambda function execution role was attached with a custom scoped inline policy:
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "DynamoDBTableSpecificRead",
      "Effect": "Allow",
      "Action": [
        "dynamodb:GetItem"
      ],
      "Resource": "arn:aws:dynamodb:us-west-1:239124108981:table/Properties"
    }
  ]
}
```

### Justification & Security Foundations
1. **Preventing Lateral Movement (Blast Radius Minimization)**:
   * Attaching the AWS-managed policy `AmazonDynamoDBReadOnlyAccess` or wildcarding the resource (`arn:aws:dynamodb:*:*:table/*`) would permit the Lambda function to inspect or scan any DynamoDB table present or created in the account.
   * By explicitly defining `arn:aws:dynamodb:us-west-1:239124108981:table/Properties`, if the Lambda function code or runtime dependencies are ever compromised (e.g., via dependency supply chain injection), an attacker cannot query, read, or infer schema from other operational tables.
2. **Action-Level Restriction (`dynamodb:GetItem`)**:
   * The business logic in `get_property` strictly performs single-key lookups.
   * Actions like `dynamodb:Scan` or `dynamodb:Query` are withheld to eliminate high-cost, table-wide read abuse and accidental full-table dumps.
   * Write, update, and delete actions (`PutItem`, `UpdateItem`, `DeleteItem`) are blocked to enforce idempotency and immutable data integrity on the read path.

---

## 5. Amazon SQS with Dead-Letter Queue (DLQ)

### 5.1 Queue Configuration
* **Dead-Letter Queue**: `property-dlq`
  * ARN: `arn:aws:sqs:us-west-1:239124108981:property-dlq`
* **Main Queue**: `property-queue`
  * Redrive Policy: Targets `property-dlq` when `maxReceiveCount` exceeds `3`.

### 5.2 Command Log & Verification

#### 1. Dead-Letter Queue Creation & ARN Retrieval
```bash
WIN-4KVQ1CQRK4L:~# aws sqs create-queue --queue-name property-dlq
{
    "QueueUrl": "https://sqs.us-west-1.amazonaws.com/239124108981/property-dlq"
}

root@WIN-4KVQ1CQRK4L:~# aws sqs get-queue-attributes \
  --queue-url $(aws sqs get-queue-url --queue-name property-dlq --query 'QueueUrl' --output text) \
  --attribute-names QueueArn \
  --query 'Attributes.QueueArn' \
  --output text
arn:aws:sqs:us-west-1:239124108981:property-dlq
```

#### 2. Main Queue Provisioning with Redrive Policy
```bash
root@WIN-4KVQ1CQRK4L:~# aws sqs create-queue --queue-name property-queue --attributes \
  '{"RedrivePolicy":"{\"deadLetterTargetArn\":\"arn:aws:sqs:us-west-1:239124108981:property-dlq\",\"maxReceiveCount\":\"3\"}"}'
{
    "QueueUrl": "https://sqs.us-west-1.amazonaws.com/239124108981/property-queue"
}
```

#### 3. Message Publishing
```bash
root@WIN-4KVQ1CQRK4L:~# aws sqs send-message \
  --queue-url https://sqs.us-west-1.amazonaws.com/239124108981/property-queue \
  --message-body '{"PropertyId":"P1002"}'
{
    "MD5OfMessageBody": "be3f822245bbcadebb0111ec27a7ed71",
    "MessageId": "6d76838b-e79b-416d-84ab-a01c8f64c020"
}
```

#### 4. Message Consumption Verification
```bash
root@WIN-4KVQ1CQRK4L:~# aws sqs receive-message \
  --queue-url https://sqs.us-west-1.amazonaws.com/239124108981/property-queue
{
    "Messages": [
        {
            "MessageId": "6d76838b-e79b-416d-84ab-a01c8f64c020",
            "ReceiptHandle": "AQEBxgbDPQZpnnnAIXtPIBxjO58UJ66E+mMQ+8+MoT7WCYgbdcBxgfsKcoNY34JkYABmxll+XingVLPg/FdR/yyv0DlROK46qWK4b8ySZLPCLFbT/Lxs6JAdasGUiq3/7Sr8yYHhu37t2yPKlx9xgQzkpLpN3Cfm6qcoZWQGInmDron+vL8O1zRuf2EtFq02Kaq/U6xIAm9IRUJZD4MuWt2mdshLKifMfc/dguWOnyty2tQY6V33oFbaJyrpoGWgbtbVJTP53+PE3sVXr8WlsWibSTh2bvv+h2JGSv5y/I7LF2v1/awo/4XIHxUJYCbTUqOh+ay0PUFBwhsZUnGDXcPlRPk9acKUs5HtGaMyygVroZd/y9rLIZMxvd1McL/TmYd8RP1GBuvbgFZ32GwRqRsMKw==",
            "MD5OfBody": "be3f822245bbcadebb0111ec27a7ed71",
            "Body": "{\"PropertyId\":\"P1002\"}"
        }
    ]
}
```

---

## 6. Deliverable Checklist
- [x] Lambda source code packaged/saved in `week-07/` (`lambda_function.py`)
- [x] Postman/curl validation collection (`curl_collection.sh`)
- [x] Comprehensive documentation with architecture diagram and IAM security explanations (`README.md`)
