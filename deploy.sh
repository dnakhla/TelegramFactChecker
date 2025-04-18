#!/bin/bash

# Colors for output
GREEN=' 33[0;32m'
YELLOW=' 33[1;33m'
RED=' 33[0;31m'
NC=' 33[0m' # No Color

# --- Default Values ---
DEFAULT_REGION="us-east-1"
ZIP_FILE_NAME="factchecker-lambda.zip"
DEPLOY_DIR="lambda-deployment"

# --- Variables ---
LAMBDA_FUNCTION_NAME=""
AWS_REGION="$DEFAULT_REGION"
TELEGRAM_TOKEN=""
OPENAI_KEY=""
S3_BUCKET=""
DO_DEPLOY=false
DO_SET_ENV=false

# --- Helper Functions ---
usage() {
    echo "Usage: $0 [--function-name <name>] [--region <region>] [--telegram-token <token>] [--openai-key <key>] [--s3-bucket <bucket>] [--deploy] [--set-env]"
    echo "  --function-name  : AWS Lambda function name (required for --deploy and --set-env)"
    echo "  --region         : AWS Region (optional, default: $DEFAULT_REGION)"
    echo "  --telegram-token : Telegram Bot Token (required for --set-env)"
    echo "  --openai-key     : OpenAI API Key (required for --set-env)"
    echo "  --s3-bucket      : S3 Bucket Name (required for --set-env)"
    echo "  --deploy         : Flag to deploy the zip file to AWS Lambda"
    echo "  --set-env        : Flag to set environment variables on AWS Lambda"
    exit 1
}

# --- Argument Parsing ---
# Using getopt for robust parsing
ARGS=$(getopt -o '' --long function-name:,region:,telegram-token:,openai-key:,s3-bucket:,deploy,set-env,help -n "$0" -- "$@")
if [ $? != 0 ]; then usage; fi
eval set -- "$ARGS"

while true; do
    case "$1" in
        --function-name) LAMBDA_FUNCTION_NAME="$2"; shift 2 ;;
        --region) AWS_REGION="$2"; shift 2 ;;
        --telegram-token) TELEGRAM_TOKEN="$2"; shift 2 ;;
        --openai-key) OPENAI_KEY="$2"; shift 2 ;;
        --s3-bucket) S3_BUCKET="$2"; shift 2 ;;
        --deploy) DO_DEPLOY=true; shift ;;
        --set-env) DO_SET_ENV=true; shift ;;
        --help) usage ;;
        --) shift; break ;;
        *) echo "Internal error!"; exit 1 ;;
    esac
done

# --- Start Script ---
echo -e "${YELLOW}Starting deployment process...${NC}"

# 1. Create deployment directory and copy files
echo -e "Creating deployment directory: ${GREEN}$DEPLOY_DIR${NC}"
rm -rf $DEPLOY_DIR
mkdir -p $DEPLOY_DIR

echo -e "${YELLOW}Copying project files...${NC}"
cp package.json package-lock.json config.js $DEPLOY_DIR/
# Ensure these paths are correct after restructuring
cp -r src utils services $DEPLOY_DIR/

# 2. Install dependencies
echo -e "${YELLOW}Installing dependencies...${NC}"
cd $DEPLOY_DIR || exit 1 # Exit if cd fails
npm install --omit=dev --no-fund --no-audit --progress=false # Added flags for cleaner output
if [ $? -ne 0 ]; then
    echo -e "${RED}Failed to install dependencies.${NC}"
    cd ..
    rm -rf $DEPLOY_DIR
    exit 1
fi
cd ..

# 3. Create zip file
echo -e "${YELLOW}Creating deployment package...${NC}"
rm -f "$ZIP_FILE_NAME"
cd $DEPLOY_DIR || exit 1 # Exit if cd fails
zip -r "../$ZIP_FILE_NAME" . > /dev/null # Suppress zip output
if [ $? -ne 0 ]; then
    echo -e "${RED}Failed to create zip package.${NC}"
    cd ..
    rm -rf $DEPLOY_DIR
    exit 1
fi
cd ..
echo -e "${GREEN}Deployment package created: $ZIP_FILE_NAME ($(du -h $ZIP_FILE_NAME | cut -f1))${NC}"

# 4. Cleanup deployment directory
rm -rf $DEPLOY_DIR

# 5. Deploy to AWS (Conditional)
if [ "$DO_DEPLOY" = true ]; then
    echo -e "${YELLOW}--- AWS Deployment ---${NC}"
    if [ -z "$LAMBDA_FUNCTION_NAME" ]; then
        echo -e "${RED}Error: Lambda function name (--function-name) is required for deployment.${NC}"
        usage
    fi
    if ! command -v aws &> /dev/null; then
        echo -e "${RED}Error: AWS CLI not found. Cannot deploy.${NC}"
        exit 1
    fi

    echo -e "Deploying to AWS Lambda function: ${GREEN}$LAMBDA_FUNCTION_NAME${NC} in region ${GREEN}$AWS_REGION${NC}..."
    aws lambda update-function-code \
        --function-name "$LAMBDA_FUNCTION_NAME" \
        --zip-file "fileb://$ZIP_FILE_NAME" \
        --region "$AWS_REGION"

    if [ $? -eq 0 ]; then
        echo -e "${GREEN}Deployment to Lambda successful!${NC}"
    else
        echo -e "${RED}Deployment to Lambda failed.${NC}"
        # Don't exit here, maybe user still wants to set env vars if deployment exists
    fi
fi

# 6. Set Environment Variables (Conditional)
if [ "$DO_SET_ENV" = true ]; then
    echo -e "${YELLOW}--- AWS Environment Variables ---${NC}"
    if [ -z "$LAMBDA_FUNCTION_NAME" ]; then
        echo -e "${RED}Error: Lambda function name (--function-name) is required for setting environment variables.${NC}"
        usage
    fi
     if [ -z "$TELEGRAM_TOKEN" ] || [ -z "$OPENAI_KEY" ] || [ -z "$S3_BUCKET" ]; then
        echo -e "${RED}Error: --telegram-token, --openai-key, and --s3-bucket are required for --set-env.${NC}"
        usage
    fi
     if ! command -v aws &> /dev/null; then
        echo -e "${RED}Error: AWS CLI not found. Cannot set environment variables.${NC}"
        exit 1
    fi

    echo -e "Setting environment variables for Lambda function: ${GREEN}$LAMBDA_FUNCTION_NAME${NC}..."
    ENV_VARIABLES="Variables={TELEGRAM_BOT_TOKEN=$TELEGRAM_TOKEN,OPENAI_API_KEY=$OPENAI_KEY,S3_BUCKET_NAME=$S3_BUCKET,AWS_REGION=$AWS_REGION}"

    aws lambda update-function-configuration \
        --function-name "$LAMBDA_FUNCTION_NAME" \
        --environment "$ENV_VARIABLES" \
        --region "$AWS_REGION"

    if [ $? -eq 0 ]; then
        echo -e "${GREEN}Environment variables set successfully!${NC}"
    else
        echo -e "${RED}Failed to set environment variables.${NC}"
    fi
fi

# --- Completion ---
echo -e "${GREEN}Deployment script finished.${NC}"
if [ "$DO_DEPLOY" = false ]; then
    echo -e "${YELLOW}To deploy the package, run again with the --deploy flag and required arguments.${NC}"
fi
if [ "$DO_SET_ENV" = false ]; then
    echo -e "${YELLOW}To set environment variables, run again with the --set-env flag and required arguments.${NC}"
fi
