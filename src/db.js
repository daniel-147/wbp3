'use strict';

// The only module that talks to AWS, so everything else stays easy to mock in tests.
// On EC2 the SDK picks up credentials from the instance role; no keys in the repo.

const { randomUUID } = require('crypto');
const { DynamoDBClient } = require('@aws-sdk/client-dynamodb');
const { DynamoDBDocumentClient, PutCommand } = require('@aws-sdk/lib-dynamodb');

const REGION = process.env.AWS_REGION || 'eu-west-2';
const TABLE_NAME = process.env.DYNAMODB_TABLE || 'wbp3-submissions';

const docClient = DynamoDBDocumentClient.from(new DynamoDBClient({ region: REGION }));

async function saveSubmission(data) {
  const item = {
    id: randomUUID(),            // partition key
    createdAt: new Date().toISOString(),
    ...data,
  };

  await docClient.send(new PutCommand({
    TableName: TABLE_NAME,
    Item: item,
  }));

  return item;
}

module.exports = { saveSubmission, REGION, TABLE_NAME };
