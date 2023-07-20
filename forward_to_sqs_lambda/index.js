// Assuming you have an initialized AWS SDK with correct credentials
const AWS = require("aws-sdk");
const sqs = new AWS.SQS();
exports.handler = async (event) => {
  console.log("Received event:", JSON.stringify(event, null, 2));

  // Extract headers and body from the event
  const { headers, body } = event;
  // Replace 'your-queue-url' with your actual SQS queue URL
  const params = {
    QueueUrl: process.env.QueueUrl,
    MessageBody: JSON.stringify({ headers, body }),
  };
  try {
    await sqs.sendMessage(params).promise();
    console.log("Message sent successfully.");
    return {
      statusCode: 200,
      body: JSON.stringify({ message: "Request forwarded to SQS." }),
    };
  } catch (error) {
    console.error("Error sending message to SQS:", error);
    return {
      statusCode: 500,
      body: JSON.stringify({ message: "Internal server error." }),
    };
  }
};
