import express from 'express';
import cors from 'cors';
import helmet from 'helmet';
import compression from 'compression';
import { config } from 'dotenv';
import pino from 'pino';
import pinoHttp from 'pino-http';
import { authMiddleware } from './middleware/auth';
import { errorHandler } from './middleware/errorHandler';
import { chatRouter } from './routes/chat';
import { ragRouter } from './routes/rag';
import { healthRouter } from './routes/health';
import { Database } from './services/database';

// Load environment variables
config();

// Initialize logger
const logger = pino({
  level: process.env.LOG_LEVEL || 'info',
  transport: process.env.NODE_ENV === 'development' ? {
    target: 'pino-pretty',
    options: {
      colorize: true
    }
  } : undefined
});

// Initialize Express app
const app = express();
const port = process.env.PORT || 3000;

// Initialize database
const database = new Database();

// Security middleware
app.use(helmet({
  contentSecurityPolicy: {
    directives: {
      defaultSrc: ["'self'"],
      scriptSrc: ["'self'"],
      styleSrc: ["'self'", "'unsafe-inline'"],
      imgSrc: ["'self'", "data:", "https:"],
    },
  },
}));

// CORS configuration
app.use(cors({
  origin: process.env.CORS_ORIGIN || '*',
  credentials: true,
}));

// Request compression
app.use(compression());

// Request logging
app.use(pinoHttp({ logger }));

// Body parsing
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true, limit: '10mb' }));

// Health check (no auth required)
app.use('/health', healthRouter);

// Protected routes with JWT authentication
app.use('/chat', authMiddleware, chatRouter);
app.use('/rag', authMiddleware, ragRouter);

// Error handling
app.use(errorHandler);

// 404 handler
app.use('*', (req, res) => {
  logger.warn(`Route not found: ${req.method} ${req.originalUrl}`);
  res.status(404).json({
    error: 'Route not found',
    message: `${req.method} ${req.originalUrl} is not a valid endpoint`
  });
});

// Graceful shutdown
const gracefulShutdown = async (signal: string) => {
  logger.info(`Received ${signal}, shutting down gracefully`);
  
  try {
    await database.close();
    logger.info('Database connections closed');
    
    process.exit(0);
  } catch (error) {
    logger.error('Error during shutdown:', error);
    process.exit(1);
  }
};

// Signal handlers
process.on('SIGTERM', () => gracefulShutdown('SIGTERM'));
process.on('SIGINT', () => gracefulShutdown('SIGINT'));

// Start server
const startServer = async () => {
  try {
    // Initialize database connection
    await database.initialize();
    logger.info('Database connected successfully');

    // Start listening
    app.listen(port, () => {
      logger.info(`🚀 Local LLM API server started on port ${port}`);
      logger.info(`📚 Health check: http://localhost:${port}/health`);
      logger.info(`💬 Chat endpoint: http://localhost:${port}/chat`);
      logger.info(`🔍 RAG endpoint: http://localhost:${port}/rag/query`);
    });

  } catch (error) {
    logger.error('Failed to start server:', error);
    process.exit(1);
  }
};

// Handle unhandled promise rejections
process.on('unhandledRejection', (reason, promise) => {
  logger.error('Unhandled Rejection at:', promise, 'reason:', reason);
  process.exit(1);
});

// Handle uncaught exceptions
process.on('uncaughtException', (error) => {
  logger.error('Uncaught Exception:', error);
  process.exit(1);
});

startServer();
