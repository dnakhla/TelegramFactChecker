import dotenv from 'dotenv';

// Load environment variables from .env file
dotenv.config();

/**
 * Application-wide configuration
 */
export const CONFIG = {
  TELEGRAM_BOT_TOKEN: process.env.TELEGRAM_BOT_TOKEN,
  OPENAI_API_KEY: process.env.OPENAI_API_KEY,
  S3_BUCKET_NAME: process.env.S3_BUCKET_NAME,
  AWS_REGION: process.env.AWS_REGION || 'us-east-1',
  MAX_TOKENS: 350,
  GPT_MODEL: 'gpt-4.1-mini', // Using the model from the original config
  MESSAGE_LIMIT: 1000,
  DEFAULT_SENSITIVITY: 75,
  SERPER_API_KEY: process.env.SERPER_API_KEY,
  BRAVE_API_KEY: process.env.BRAVE_API_KEY,
};