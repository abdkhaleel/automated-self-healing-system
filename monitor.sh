#!/bin/bash

if [ -f .env ]; then
    export $(grep -v '^#' .env | xargs)
else
    echo "Error: .env file not found!"
    exit 1
fi

if [ -z "$S3_BUCKET" ] || [ -z "$SNS_TOPIC_ARN" ]; then
    echo "Error: Configuration missing in .env file."
    echo "Please define S3_BUCKET and SNS_TOPIC_ARN."
    exit 1
fi

PID_FILE="app.pid"
LOG_FILE="application.log"

AWS_CMD="aws --endpoint-url=$AWS_ENDPOINT --profile $AWS_PROFILE"

echo "[CI/CD] Compiling $APP_NAME..."
if javac $APP_NAME.java; then
    echo "Build Success! Starting Monitor..."
else
    echo "Build Failed! Fix your Java code."
    exit 1
fi

start_app() {
    echo "Starting $APP_NAME..."
    java $APP_NAME > /dev/null 2>&1 &
    sleep 2
}

start_app

while true; do
    if [ -f "$PID_FILE" ]; then
        echo "[$(date +'%H:%M:%S')] System Healthy"
    else
        echo "[$(date +'%H:%M:%S')] CRITICAL ALERT: $APP_NAME has crashed!"

        TIMESTAMP=$(date +'%Y%m%d_%H%M%S')
        
        echo "   Uploading evidence to S3..."
        $AWS_CMD s3 cp $LOG_FILE $S3_BUCKET/crash-log-$TIMESTAMP.log

        echo "   cw Sending SNS Alert..."
        $AWS_CMD sns publish \
            --topic-arn "$SNS_TOPIC_ARN" \
            --message "ALERT: Service $APP_NAME crashed at $TIMESTAMP." \
            --subject "CRITICAL INCIDENT - $APP_NAME"

        echo "   Initiating Self-Healing..."
        start_app
    fi

    sleep 5
done