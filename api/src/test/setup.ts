import { config } from 'dotenv';

// Load test environment variables
config({ path: '.env.test' });

// Set test environment
process.env.NODE_ENV = 'test';
process.env.LOG_LEVEL = 'silent';

// Mock external services for testing
jest.mock('../services/localai');
jest.mock('../services/database');

// Global test timeout
jest.setTimeout(30000);
