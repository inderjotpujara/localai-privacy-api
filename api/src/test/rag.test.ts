import request from 'supertest';
import express from 'express';
import { ragRouter } from '../routes/rag';
import { authMiddleware } from '../middleware/auth';

// Mock the services
jest.mock('../services/database');
jest.mock('../services/localai');

const app = express();
app.use(express.json());
app.use('/rag', authMiddleware, ragRouter);

// Mock valid JWT for testing
const mockAuthMiddleware = (req: any, res: any, next: any) => {
  req.user = { id: 'test-user', email: 'test@example.com' };
  next();
};

app.use('/rag-test', mockAuthMiddleware, ragRouter);

describe('RAG Endpoints', () => {
  describe('POST /rag/query', () => {
    it('should require authentication', async () => {
      const response = await request(app)
        .post('/rag/query')
        .send({
          query: 'test query',
          limit: 5
        });

      expect(response.status).toBe(401);
    });

    it('should validate query parameter', async () => {
      const response = await request(app)
        .post('/rag-test/query')
        .send({
          limit: 5
        });

      expect(response.status).toBe(400);
      expect(response.body.message).toContain('Query is required');
    });

    it('should validate query length', async () => {
      const longQuery = 'a'.repeat(1001);
      const response = await request(app)
        .post('/rag-test/query')
        .send({
          query: longQuery,
          limit: 5
        });

      expect(response.status).toBe(400);
      expect(response.body.message).toContain('Query too long');
    });

    it('should validate limit parameter', async () => {
      const response = await request(app)
        .post('/rag-test/query')
        .send({
          query: 'test query',
          limit: 25
        });

      expect(response.status).toBe(400);
      expect(response.body.message).toContain('Limit must be between 1 and 20');
    });
  });

  describe('POST /rag/documents', () => {
    it('should validate content parameter', async () => {
      const response = await request(app)
        .post('/rag-test/documents')
        .send({
          metadata: { source: 'test' }
        });

      expect(response.status).toBe(400);
      expect(response.body.message).toContain('Content is required');
    });

    it('should validate content length', async () => {
      const longContent = 'a'.repeat(50001);
      const response = await request(app)
        .post('/rag-test/documents')
        .send({
          content: longContent
        });

      expect(response.status).toBe(400);
      expect(response.body.message).toContain('Content too long');
    });
  });
});
