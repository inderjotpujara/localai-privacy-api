import { Router, Request, Response } from 'express';
import pino from 'pino';
import { Database } from '../services/database';
import { LocalAIService } from '../services/localai';

const logger = pino();
const router = Router();
const database = new Database();
const localAI = new LocalAIService();

// Health check endpoint (no authentication required)
router.get('/', async (req: Request, res: Response) => {
  const startTime = Date.now();
  
  try {
    // Check all service dependencies
    const [dbHealthy, localAIHealthy] = await Promise.allSettled([
      database.isHealthy(),
      localAI.healthCheck(),
    ]);

    const dbStatus = dbHealthy.status === 'fulfilled' && dbHealthy.value;
    const localAIStatus = localAIHealthy.status === 'fulfilled' && localAIHealthy.value;
    
    const overall = dbStatus && localAIStatus;
    const processingTime = Date.now() - startTime;

    const healthData = {
      status: overall ? 'healthy' : 'unhealthy',
      timestamp: new Date().toISOString(),
      uptime: process.uptime(),
      version: process.env.npm_package_version || '1.0.0',
      node_version: process.version,
      memory: {
        used: Math.round(process.memoryUsage().heapUsed / 1024 / 1024),
        total: Math.round(process.memoryUsage().heapTotal / 1024 / 1024),
        external: Math.round(process.memoryUsage().external / 1024 / 1024),
      },
      services: {
        database: {
          status: dbStatus ? 'healthy' : 'unhealthy',
          url: process.env.DATABASE_URL ? 'configured' : 'not configured',
        },
        localai: {
          status: localAIStatus ? 'healthy' : 'unhealthy',
          url: process.env.LOCALAI_URL || 'http://localhost:8080',
          model: process.env.LOCALAI_MODEL || 'llama3',
        },
      },
      environment: {
        node_env: process.env.NODE_ENV || 'development',
        port: process.env.PORT || 3000,
        log_level: process.env.LOG_LEVEL || 'info',
      },
      processing_time_ms: processingTime,
    };

    // Log health check result
    logger.info({
      overall,
      dbStatus,
      localAIStatus,
      processingTime,
    }, 'Health check completed');

    // Return appropriate status code
    const statusCode = overall ? 200 : 503;
    res.status(statusCode).json(healthData);

  } catch (error) {
    const processingTime = Date.now() - startTime;
    
    logger.error({
      error: error instanceof Error ? error.message : 'Unknown error',
      processingTime,
    }, 'Health check failed');

    res.status(503).json({
      status: 'unhealthy',
      error: 'Health check failed',
      message: error instanceof Error ? error.message : 'Unknown error',
      timestamp: new Date().toISOString(),
      processing_time_ms: processingTime,
    });
  }
});

// Readiness probe (for Kubernetes/Docker)
router.get('/ready', async (req: Request, res: Response) => {
  try {
    const dbHealthy = await database.isHealthy();
    
    if (dbHealthy) {
      res.status(200).json({
        status: 'ready',
        timestamp: new Date().toISOString(),
      });
    } else {
      res.status(503).json({
        status: 'not ready',
        reason: 'Database not available',
        timestamp: new Date().toISOString(),
      });
    }
  } catch (error) {
    res.status(503).json({
      status: 'not ready',
      error: error instanceof Error ? error.message : 'Unknown error',
      timestamp: new Date().toISOString(),
    });
  }
});

// Liveness probe (for Kubernetes/Docker)
router.get('/live', (req: Request, res: Response) => {
  res.status(200).json({
    status: 'alive',
    timestamp: new Date().toISOString(),
    uptime: process.uptime(),
  });
});

export { router as healthRouter };
