const AWS = require('aws-sdk');

exports.handler = async function (event, context,) {
  console.log(new Date() + " EVENT: \n" + JSON.stringify(event, null, 2));

  const client = new AWS.S3();
  const params = {
    Bucket: 'playground-test-bucket',
    Key: 'file.txt',
  }

  const data = await client.getObject(params).promise();
  if (!data) return callback("No data");
  console.log(data);
  return JSON.stringify(data);
  // return `${context.functionName} invoked by request ${context.awsRequestId} foo = ${process.env.foo}`;
}
