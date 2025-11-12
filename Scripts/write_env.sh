#!/bin/bash

# Define the .env file path - now at project root
ENV_FILE_PATH="./.env"

# Clear the contents of the .env file or create it if it doesn't exist
> $ENV_FILE_PATH

# Azure OpenAI Configuration - using output names from main.bicep
echo "# Azure OpenAI Configuration" >> $ENV_FILE_PATH
echo "AZURE_OPENAI_ENDPOINT=$(azd env get-value AZURE_OPENAI_ENDPOINT)" >> $ENV_FILE_PATH
echo "AZURE_OPENAI_DEPLOYMENT=$(azd env get-value AZURE_OPENAI_CHAT_DEPLOYMENT)" >> $ENV_FILE_PATH
echo "" >> $ENV_FILE_PATH

# Database Configuration - using output names from main.bicep
echo "# Database Configuration" >> $ENV_FILE_PATH
echo "AZURE_PG_HOST=$(azd env get-value AZURE_POSTGRES_DOMAIN)" >> $ENV_FILE_PATH
echo "AZURE_PG_NAME=$(azd env get-value AZURE_POSTGRES_DBNAME)" >> $ENV_FILE_PATH
echo "AZURE_PG_USER=$(azd env get-value AZURE_POSTGRES_USER)" >> $ENV_FILE_PATH
echo "AZURE_PG_PORT=5432" >> $ENV_FILE_PATH
echo "AZURE_PG_SSLMODE=require" >> $ENV_FILE_PATH

echo "Environment file created at $ENV_FILE_PATH"
