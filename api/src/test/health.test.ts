import request from 'supertest';
import express from 'express';
import { healthRouter } from '../routes/health';

// Mock the database and LocalAI services for testing
jest.mock('../services/database', () => ({
  Database: jest.fn().mockImplementation(() => ({
    isHealthy: jest.fn().mockResolvedValue(true),
  })),
}));

jest.mock('../services/localai', () => ({
  LocalAIService: jest.fn().mockImplementation(() => ({
    healthCheck: jest.fn().mockResolvedValue(true),
  })),
}));

const app = express();
app.use('/health', healthRouter);

describe('Health Endpoint', () => {
  it('should return health status', async () => {
    const response = await request(app)
      .get('/health')
      .expect(200);

    expect(response.body).toHaveProperty('status');
    expect(response.body).toHaveProperty('timestamp');
    expect(response.body).toHaveProperty('uptime');
    expect(response.body).toHaveProperty('services');
  });

  it('should return readiness status', async () => {
    const response = await request(app)
      .get('/health/ready')
      .expect('Content-Type', /json/);

    expect(response.body).toHaveProperty('status');
    expect(response.body).toHaveProperty('timestamp');
  });

  it('should return liveness status', async () => {
    const response = await request(app)
      .get('/health/live')
      .expect(200);

    expect(response.body).toHaveProperty('status', 'alive');
    expect(response.body).toHaveProperty('timestamp');
    expect(response.body).toHaveProperty('uptime');
  });
});
