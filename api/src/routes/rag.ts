import { Router, Response } from 'express';
import pino from 'pino';
import { Database } from '../services/database';
import { LocalAIService } from '../services/localai';
import { AuthenticatedRequest } from '../middleware/auth';
import { RAGQuery, RAGResponse } from '../types';
import { createError } from '../middleware/errorHandler';

const logger = pino();
const router = Router();
const database = new Database();
const localAI = new LocalAIService();

// RAG Query endpoint
router.post('/query', async (req: AuthenticatedRequest, res: Response) => {
  const startTime = Date.now();
  
  try {
    const { 
      query, 
      limit = 5, 
      similarity_threshold = 0.7, 
      include_metadata = true 
    }: RAGQuery = req.body;

    // Validation
    if (!query || typeof query !== 'string' || query.trim().length === 0) {
      throw createError('Query is required and must be a non-empty string', 400);
    }

    if (query.length > 1000) {
      throw createError('Query too long (max 1,000 characters)', 400);
    }

    if (limit < 1 || limit > 20) {
      throw createError('Limit must be between 1 and 20', 400);
    }

    if (similarity_threshold < 0 || similarity_threshold > 1) {
      throw createError('Similarity threshold must be between 0 and 1', 400);
    }

    const userId = req.user?.id || 'anonymous';
    
    logger.info({
      userId,
      query: query.substring(0, 100) + (query.length > 100 ? '...' : ''),
      limit,
      similarity_threshold,
    }, 'RAG query received');

    // Generate embedding for the query
    const embeddingResponse = await localAI.generateEmbedding({
      text: query,
      model: process.env.EMBEDDING_MODEL || 'all-MiniLM-L6-v2',
    });

    // Search for similar documents
    const results = await database.searchSimilarDocuments(
      embeddingResponse.embedding,
      limit,
      similarity_threshold
    );

    const processingTime = Date.now() - startTime;

    // Prepare response
    const response: RAGResponse = {
      results: include_metadata ? results : results.map(r => ({
        content: r.content,
        similarity_score: r.similarity_score,
        document_id: r.document_id,
      })),
      query,
      total_results: results.length,
      processing_time_ms: processingTime,
    };

    logger.info({
      userId,
      totalResults: results.length,
      processingTime,
      averageSimilarity: results.length > 0 
        ? results.reduce((sum, r) => sum + r.similarity_score, 0) / results.length 
        : 0,
    }, 'RAG query completed');

    res.json(response);

  } catch (error) {
    const processingTime = Date.now() - startTime;
    
    logger.error({
      userId: req.user?.id,
      error: error instanceof Error ? error.message : 'Unknown error',
      processingTime,
    }, 'RAG query failed');

    const statusCode = (error as any).statusCode || 500;
    const message = error instanceof Error ? error.message : 'RAG query failed';
    
    res.status(statusCode).json({
      error: statusCode >= 500 ? 'Internal Server Error' : 'RAG Query Error',
      message,
      processing_time_ms: processingTime,
    });
  }
});

// Add document to RAG store
router.post('/documents', async (req: AuthenticatedRequest, res: Response) => {
  const startTime = Date.now();
  
  try {
    const { content, metadata = {} } = req.body;

    // Validation
    if (!content || typeof content !== 'string' || content.trim().length === 0) {
      throw createError('Content is required and must be a non-empty string', 400);
    }

    if (content.length > 50000) {
      throw createError('Content too long (max 50,000 characters)', 400);
    }

    const userId = req.user?.id || 'anonymous';
    
    logger.info({
      userId,
      contentLength: content.length,
      hasMetadata: Object.keys(metadata).length > 0,
    }, 'Adding document to RAG store');

    // Generate embedding for the content
    const embeddingResponse = await localAI.generateEmbedding({
      text: content,
      model: process.env.EMBEDDING_MODEL || 'all-MiniLM-L6-v2',
    });

    // Add user context to metadata
    const enrichedMetadata = {
      ...metadata,
      added_by: userId,
      content_length: content.length,
      embedding_model: embeddingResponse.model,
    };

    // Store document with embedding
    const documentId = await database.insertDocument(
      content,
      enrichedMetadata,
      embeddingResponse.embedding
    );

    const processingTime = Date.now() - startTime;

    logger.info({
      userId,
      documentId,
      processingTime,
    }, 'Document added to RAG store');

    res.status(201).json({
      document_id: documentId,
      content_length: content.length,
      embedding_dimensions: embeddingResponse.embedding.length,
      processing_time_ms: processingTime,
      timestamp: new Date().toISOString(),
    });

  } catch (error) {
    const processingTime = Date.now() - startTime;
    
    logger.error({
      userId: req.user?.id,
      error: error instanceof Error ? error.message : 'Unknown error',
      processingTime,
    }, 'Failed to add document to RAG store');

    const statusCode = (error as any).statusCode || 500;
    const message = error instanceof Error ? error.message : 'Failed to add document';
    
    res.status(statusCode).json({
      error: statusCode >= 500 ? 'Internal Server Error' : 'Document Creation Error',
      message,
      processing_time_ms: processingTime,
    });
  }
});

// Get document by ID
router.get('/documents/:id', async (req: AuthenticatedRequest, res: Response) => {
  try {
    const { id } = req.params;
    const userId = req.user?.id || 'anonymous';

    logger.debug({ userId, documentId: id }, 'Retrieving document');

    const document = await database.getDocumentById(id);

    if (!document) {
      res.status(404).json({
        error: 'Not Found',
        message: 'Document not found',
      });
      return;
    }

    res.json({
      ...document,
      embedding: undefined, // Don't expose raw embeddings
    });

  } catch (error) {
    logger.error('Failed to retrieve document:', error);
    
    res.status(500).json({
      error: 'Internal Server Error',
      message: 'Failed to retrieve document',
    });
  }
});

// Delete document
router.delete('/documents/:id', async (req: AuthenticatedRequest, res: Response) => {
  try {
    const { id } = req.params;
    const userId = req.user?.id || 'anonymous';

    logger.info({ userId, documentId: id }, 'Deleting document');

    const deleted = await database.deleteDocument(id);

    if (!deleted) {
      res.status(404).json({
        error: 'Not Found',
        message: 'Document not found',
      });
      return;
    }

    res.json({
      message: 'Document deleted successfully',
      document_id: id,
      timestamp: new Date().toISOString(),
    });

  } catch (error) {
    logger.error('Failed to delete document:', error);
    
    res.status(500).json({
      error: 'Internal Server Error',
      message: 'Failed to delete document',
    });
  }
});

export { router as ragRouter };
