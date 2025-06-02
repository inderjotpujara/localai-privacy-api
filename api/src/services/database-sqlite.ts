import sqlite3 from 'sqlite3';
import { Database as SqliteDatabase, open } from 'sqlite';
import pino from 'pino';
import { Document, RAGResult } from '../types';

const logger = pino();

export class Database {
  private db: SqliteDatabase | null = null;
  private initialized = false;

  constructor() {
    // SQLite doesn't need connection configuration like PostgreSQL
  }

  async initialize(): Promise<void> {
    if (this.initialized) return;

    try {
      // Open SQLite database
      this.db = await open({
        filename: process.env.DATABASE_URL?.replace('sqlite://', '') || '/app/data/localai.db',
        driver: sqlite3.Database
      });

      // Initialize tables
      await this.db.exec(`
        -- Create documents table for RAG
        CREATE TABLE IF NOT EXISTS documents (
          id TEXT PRIMARY KEY DEFAULT (lower(hex(randomblob(16)))),
          content TEXT NOT NULL,
          metadata TEXT DEFAULT '{}',
          embedding BLOB,
          created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
          updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
        );

        -- Create user sessions table
        CREATE TABLE IF NOT EXISTS user_sessions (
          id TEXT PRIMARY KEY DEFAULT (lower(hex(randomblob(16)))),
          user_id TEXT NOT NULL,
          session_data TEXT DEFAULT '{}',
          created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
          expires_at DATETIME
        );

        -- Create indexes for better performance
        CREATE INDEX IF NOT EXISTS idx_documents_created_at ON documents(created_at);
        CREATE INDEX IF NOT EXISTS idx_user_sessions_user_id ON user_sessions(user_id);
        CREATE INDEX IF NOT EXISTS idx_user_sessions_expires_at ON user_sessions(expires_at);

        -- Create trigger to update updated_at timestamp
        CREATE TRIGGER IF NOT EXISTS update_documents_updated_at 
          AFTER UPDATE ON documents FOR EACH ROW
        BEGIN
          UPDATE documents SET updated_at = CURRENT_TIMESTAMP WHERE id = NEW.id;
        END;
      `);

      this.initialized = true;
      logger.info('SQLite database initialized successfully');

    } catch (error) {
      logger.error('Database initialization failed:', error);
      throw error;
    }
  }

  async insertDocument(content: string, metadata: Record<string, any> = {}, embedding?: number[]): Promise<string> {
    if (!this.db) throw new Error('Database not initialized');
    
    try {
      const id = this.generateId();
      const embeddingBlob = embedding ? Buffer.from(new Float32Array(embedding).buffer) : null;
      
      await this.db.run(
        'INSERT INTO documents (id, content, metadata, embedding) VALUES (?, ?, ?, ?)',
        [id, content, JSON.stringify(metadata), embeddingBlob]
      );
      
      return id;
    } catch (error) {
      logger.error('Error inserting document:', error);
      throw error;
    }
  }

  async searchSimilarDocuments(
    queryEmbedding: number[], 
    limit: number = 5, 
    similarityThreshold: number = 0.7
  ): Promise<RAGResult[]> {
    if (!this.db) throw new Error('Database not initialized');
    
    try {
      // Simplified similarity search - returns all documents with mock similarity
      // In production, implement proper vector similarity with a vector extension
      const rows = await this.db.all(
        'SELECT id, content, metadata FROM documents WHERE embedding IS NOT NULL ORDER BY created_at DESC LIMIT ?',
        [limit]
      );
      
      return rows.map((row, index) => ({
        content: row.content,
        metadata: JSON.parse(row.metadata || '{}'),
        similarity_score: Math.max(0.5, 1 - (index * 0.1)), // Mock decreasing similarity
        document_id: row.id
      }));
      
    } catch (error) {
      logger.error('Error searching similar documents:', error);
      throw error;
    }
  }

  async getDocumentById(id: string): Promise<Document | null> {
    if (!this.db) throw new Error('Database not initialized');
    
    try {
      const row = await this.db.get(
        'SELECT id, content, metadata, created_at, updated_at FROM documents WHERE id = ?',
        [id]
      );
      
      if (!row) return null;
      
      return {
        id: row.id,
        content: row.content,
        metadata: JSON.parse(row.metadata || '{}'),
        created_at: new Date(row.created_at),
        updated_at: new Date(row.updated_at)
      };
      
    } catch (error) {
      logger.error('Error getting document by ID:', error);
      throw error;
    }
  }

  async updateDocument(id: string, content?: string, metadata?: Record<string, any>, embedding?: number[]): Promise<boolean> {
    if (!this.db) throw new Error('Database not initialized');
    
    try {
      const updates: string[] = [];
      const values: any[] = [];

      if (content !== undefined) {
        updates.push('content = ?');
        values.push(content);
      }

      if (metadata !== undefined) {
        updates.push('metadata = ?');
        values.push(JSON.stringify(metadata));
      }

      if (embedding !== undefined) {
        updates.push('embedding = ?');
        values.push(Buffer.from(new Float32Array(embedding).buffer));
      }

      if (updates.length === 0) {
        return false;
      }

      values.push(id);

      const result = await this.db.run(
        `UPDATE documents SET ${updates.join(', ')} WHERE id = ?`,
        values
      );
      
      return (result.changes ?? 0) > 0;
      
    } catch (error) {
      logger.error('Error updating document:', error);
      throw error;
    }
  }

  async deleteDocument(id: string): Promise<boolean> {
    if (!this.db) throw new Error('Database not initialized');
    
    try {
      const result = await this.db.run('DELETE FROM documents WHERE id = ?', [id]);
      return (result.changes ?? 0) > 0;
      
    } catch (error) {
      logger.error('Error deleting document:', error);
      throw error;
    }
  }

  async close(): Promise<void> {
    if (this.db) {
      await this.db.close();
      this.db = null;
      logger.info('Database connections closed');
    }
  }

  async isHealthy(): Promise<boolean> {
    try {
      if (!this.db) return false;
      await this.db.get('SELECT 1');
      return true;
    } catch (error) {
      logger.error('Database health check failed:', error);
      return false;
    }
  }

  private generateId(): string {
    return Math.random().toString(36).substring(2, 15) + Date.now().toString(36);
  }
}
