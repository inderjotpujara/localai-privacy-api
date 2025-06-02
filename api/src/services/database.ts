import { Pool, PoolClient } from 'pg';
import pino from 'pino';
import { Document, RAGResult } from '../types';

const logger = pino();

export class Database {
  private pool: Pool;
  private initialized = false;

  constructor() {
    const connectionString = process.env.DATABASE_URL;
    
    if (!connectionString) {
      throw new Error('DATABASE_URL environment variable is required');
    }

    this.pool = new Pool({
      connectionString,
      max: 20,
      idleTimeoutMillis: 30000,
      connectionTimeoutMillis: 2000,
    });

    // Handle pool errors
    this.pool.on('error', (err) => {
      logger.error('Database pool error:', err);
    });
  }

  async initialize(): Promise<void> {
    if (this.initialized) return;

    try {
      // Test connection
      const client = await this.pool.connect();
      
      // Create pgvector extension if not exists
      await client.query('CREATE EXTENSION IF NOT EXISTS vector');
      
      // Create documents table with vector column
      await client.query(`
        CREATE TABLE IF NOT EXISTS documents (
          id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
          content TEXT NOT NULL,
          metadata JSONB DEFAULT '{}',
          embedding vector(384), -- Adjust dimensions based on your embedding model
          created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
          updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
        )
      `);

      // Create vector index for similarity search
      await client.query(`
        CREATE INDEX IF NOT EXISTS documents_embedding_idx 
        ON documents USING ivfflat (embedding vector_cosine_ops) 
        WITH (lists = 100)
      `);

      // Create user sessions table (optional, for tracking usage)
      await client.query(`
        CREATE TABLE IF NOT EXISTS user_sessions (
          id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
          user_id VARCHAR(255) NOT NULL,
          session_data JSONB DEFAULT '{}',
          created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
          expires_at TIMESTAMP WITH TIME ZONE
        )
      `);

      client.release();
      this.initialized = true;
      logger.info('Database initialized successfully');

    } catch (error) {
      logger.error('Database initialization failed:', error);
      throw error;
    }
  }

  async insertDocument(content: string, metadata: Record<string, any> = {}, embedding?: number[]): Promise<string> {
    const client = await this.pool.connect();
    
    try {
      const query = `
        INSERT INTO documents (content, metadata, embedding)
        VALUES ($1, $2, $3)
        RETURNING id
      `;
      
      const values = [content, JSON.stringify(metadata), embedding ? `[${embedding.join(',')}]` : null];
      const result = await client.query(query, values);
      
      return result.rows[0].id;
    } catch (error) {
      logger.error('Error inserting document:', error);
      throw error;
    } finally {
      client.release();
    }
  }

  async searchSimilarDocuments(
    queryEmbedding: number[], 
    limit: number = 5, 
    similarityThreshold: number = 0.7
  ): Promise<RAGResult[]> {
    const client = await this.pool.connect();
    
    try {
      const query = `
        SELECT 
          id,
          content,
          metadata,
          1 - (embedding <=> $1::vector) as similarity_score
        FROM documents
        WHERE embedding IS NOT NULL
        AND 1 - (embedding <=> $1::vector) > $2
        ORDER BY embedding <=> $1::vector
        LIMIT $3
      `;
      
      const embeddingVector = `[${queryEmbedding.join(',')}]`;
      const result = await client.query(query, [embeddingVector, similarityThreshold, limit]);
      
      return result.rows.map(row => ({
        content: row.content,
        metadata: row.metadata,
        similarity_score: parseFloat(row.similarity_score),
        document_id: row.id
      }));
      
    } catch (error) {
      logger.error('Error searching similar documents:', error);
      throw error;
    } finally {
      client.release();
    }
  }

  async getDocumentById(id: string): Promise<Document | null> {
    const client = await this.pool.connect();
    
    try {
      const query = `
        SELECT id, content, metadata, created_at, updated_at
        FROM documents
        WHERE id = $1
      `;
      
      const result = await client.query(query, [id]);
      
      if (result.rows.length === 0) {
        return null;
      }
      
      const row = result.rows[0];
      return {
        id: row.id,
        content: row.content,
        metadata: row.metadata,
        created_at: row.created_at,
        updated_at: row.updated_at
      };
      
    } catch (error) {
      logger.error('Error getting document by ID:', error);
      throw error;
    } finally {
      client.release();
    }
  }

  async updateDocument(id: string, content?: string, metadata?: Record<string, any>, embedding?: number[]): Promise<boolean> {
    const client = await this.pool.connect();
    
    try {
      const updates: string[] = [];
      const values: any[] = [];
      let paramCount = 1;

      if (content !== undefined) {
        updates.push(`content = $${paramCount++}`);
        values.push(content);
      }

      if (metadata !== undefined) {
        updates.push(`metadata = $${paramCount++}`);
        values.push(JSON.stringify(metadata));
      }

      if (embedding !== undefined) {
        updates.push(`embedding = $${paramCount++}`);
        values.push(`[${embedding.join(',')}]`);
      }

      if (updates.length === 0) {
        return false;
      }

      updates.push(`updated_at = NOW()`);
      values.push(id);

      const query = `
        UPDATE documents 
        SET ${updates.join(', ')}
        WHERE id = $${paramCount}
      `;

      const result = await client.query(query, values);
      return (result.rowCount ?? 0) > 0;
      
    } catch (error) {
      logger.error('Error updating document:', error);
      throw error;
    } finally {
      client.release();
    }
  }

  async deleteDocument(id: string): Promise<boolean> {
    const client = await this.pool.connect();
    
    try {
      const query = 'DELETE FROM documents WHERE id = $1';
      const result = await client.query(query, [id]);
      return (result.rowCount ?? 0) > 0;
      
    } catch (error) {
      logger.error('Error deleting document:', error);
      throw error;
    } finally {
      client.release();
    }
  }

  async close(): Promise<void> {
    await this.pool.end();
    logger.info('Database connections closed');
  }

  // Health check
  async isHealthy(): Promise<boolean> {
    try {
      const client = await this.pool.connect();
      await client.query('SELECT 1');
      client.release();
      return true;
    } catch (error) {
      logger.error('Database health check failed:', error);
      return false;
    }
  }
}
