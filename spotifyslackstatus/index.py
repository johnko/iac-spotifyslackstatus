import os
import logging
import json

logger = logging.getLogger()
logger.setLevel(logging.INFO)

def hello(event, context):
    # logger.info("## ENVIRONMENT VARIABLES\n" + json.dumps(dict(**os.environ)))
    logger.info("## EVENT\n" + json.dumps(event))

    responseCode = 200
    responseBody = {
        "message": "Hello"
    }

    response = {
        "statusCode": responseCode,
        "headers": {
            "x-custom-header" : "my custom header value"
        },
        "body": json.dumps(responseBody),
    }
    return response

def goodbye(event, context):
    # logger.info("## ENVIRONMENT VARIABLES\n" + json.dumps(dict(**os.environ)))
    logger.info("## EVENT\n" + json.dumps(event))

    responseCode = 200
    responseBody = {
        "message": "Goodbye"
    }

    response = {
        "statusCode": responseCode,
        "headers": {
            "x-custom-header" : "my custom header value"
        },
        "body": json.dumps(responseBody),
    }
    return response
