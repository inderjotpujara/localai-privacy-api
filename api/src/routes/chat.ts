import { Router, Response } from 'express';
import pino from 'pino';
import { LocalAIService } from '../services/localai';
import { AuthenticatedRequest } from '../middleware/auth';
import { ChatRequest } from '../types';
import { createError } from '../middleware/errorHandler';

const logger = pino();
const router = Router();
const localAI = new LocalAIService();

// Chat endpoint with optional streaming
router.post('/', async (req: AuthenticatedRequest, res: Response) => {
  const startTime = Date.now();
  
  try {
    const { message, stream = false, temperature, max_tokens, context }: ChatRequest = req.body;

    // Validation
    if (!message || typeof message !== 'string' || message.trim().length === 0) {
      throw createError('Message is required and must be a non-empty string', 400);
    }

    if (message.length > 10000) {
      throw createError('Message too long (max 10,000 characters)', 400);
    }

    const userId = req.user?.id || 'anonymous';
    
    logger.info({
      userId,
      messageLength: message.length,
      stream,
      temperature,
      max_tokens,
    }, 'Chat request received');

    const chatRequest: ChatRequest = {
      message,
      stream,
      temperature,
      max_tokens,
      context,
    };

    if (stream) {
      // Server-Sent Events for streaming
      res.writeHead(200, {
        'Content-Type': 'text/event-stream',
        'Cache-Control': 'no-cache',
        'Connection': 'keep-alive',
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Headers': 'Cache-Control'
      });

      // Send initial connection event
      res.write('data: {"type":"connection","status":"connected"}\n\n');

      try {
        let totalContent = '';
        
        for await (const chunk of localAI.chatStream(chatRequest)) {
          if (chunk.done) {
            // Send completion event
            const completionData = {
              type: 'completion',
              content: totalContent,
              processing_time_ms: Date.now() - startTime,
              model: process.env.LOCALAI_MODEL || 'llama3',
              timestamp: new Date().toISOString(),
            };
            
            res.write(`data: ${JSON.stringify(completionData)}\n\n`);
            res.write('data: [DONE]\n\n');
            break;
          } else {
            totalContent += chunk.content;
            
            // Send chunk event
            const chunkData = {
              type: 'chunk',
              content: chunk.content,
            };
            
            res.write(`data: ${JSON.stringify(chunkData)}\n\n`);
          }
        }

        logger.info({
          userId,
          responseLength: totalContent.length,
          processingTime: Date.now() - startTime,
        }, 'Streaming chat completed');

      } catch (streamError) {
        logger.error('Streaming error:', streamError);
        const errorData = {
          type: 'error',
          error: streamError instanceof Error ? streamError.message : 'Unknown streaming error',
        };
        res.write(`data: ${JSON.stringify(errorData)}\n\n`);
      }

      res.end();

    } else {
      // Regular JSON response
      const response = await localAI.chat(chatRequest);
      
      const processingTime = Date.now() - startTime;
      
      logger.info({
        userId,
        responseLength: response.message.length,
        processingTime,
        usage: response.usage,
      }, 'Chat completed');

      res.json({
        ...response,
        processing_time_ms: processingTime,
      });
    }

  } catch (error) {
    const processingTime = Date.now() - startTime;
    
    logger.error({
      userId: req.user?.id,
      error: error instanceof Error ? error.message : 'Unknown error',
      processingTime,
    }, 'Chat request failed');

    if (req.body.stream && res.headersSent) {
      // For streaming requests that have already started
      const errorData = {
        type: 'error',
        error: error instanceof Error ? error.message : 'Unknown error',
      };
      res.write(`data: ${JSON.stringify(errorData)}\n\n`);
      res.end();
    } else {
      // For regular requests or streaming that hasn't started yet
      const statusCode = (error as any).statusCode || 500;
      const message = error instanceof Error ? error.message : 'Chat request failed';
      
      res.status(statusCode).json({
        error: statusCode >= 500 ? 'Internal Server Error' : 'Chat Error',
        message,
        processing_time_ms: processingTime,
      });
    }
  }
});

// Get available models
router.get('/models', async (req: AuthenticatedRequest, res: Response) => {
  try {
    const models = await localAI.getModels();
    
    res.json({
      models,
      current_model: process.env.LOCALAI_MODEL || 'llama3',
      timestamp: new Date().toISOString(),
    });

  } catch (error) {
    logger.error('Failed to fetch models:', error);
    res.status(500).json({
      error: 'Internal Server Error',
      message: 'Failed to fetch available models',
    });
  }
});

export { router as chatRouter };
