import { generateTestToken } from '../middleware/auth';

describe('Auth Middleware', () => {
  describe('generateTestToken', () => {
    beforeEach(() => {
      process.env.JWT_SECRET = 'test-secret-key';
    });

    it('should generate a valid JWT token', () => {
      const token = generateTestToken('user123', 'test@example.com');
      
      expect(typeof token).toBe('string');
      expect(token.split('.')).toHaveLength(3); // JWT has 3 parts
    });

    it('should include user information in token', () => {
      const userId = 'user123';
      const email = 'test@example.com';
      const token = generateTestToken(userId, email);
      
      // Decode the payload (without verification for testing)
      const tokenParts = token.split('.');
      expect(tokenParts).toHaveLength(3);
      const payload = JSON.parse(
        Buffer.from(tokenParts[1]!, 'base64').toString()
      );
      
      expect(payload.sub).toBe(userId);
      expect(payload.id).toBe(userId);
      expect(payload.email).toBe(email);
      expect(payload.iat).toBeDefined();
      expect(payload.exp).toBeDefined();
    });

    it('should throw error if JWT_SECRET is not set', () => {
      delete process.env.JWT_SECRET;
      
      expect(() => {
        generateTestToken('user123');
      }).toThrow('JWT_SECRET not configured');
    });
  });
});
