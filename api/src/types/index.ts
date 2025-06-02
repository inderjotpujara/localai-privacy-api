export interface ChatMessage {
  role: 'user' | 'assistant' | 'system';
  content: string;
  timestamp?: string;
}

export interface ChatRequest {
  message: string;
  stream?: boolean;
  temperature?: number;
  max_tokens?: number;
  context?: ChatMessage[];
}

export interface ChatResponse {
  message: string;
  model: string;
  usage?: {
    prompt_tokens: number;
    completion_tokens: number;
    total_tokens: number;
  };
  timestamp: string;
}

export interface StreamChunk {
  content: string;
  done: boolean;
}

export interface RAGQuery {
  query: string;
  limit?: number;
  similarity_threshold?: number;
  include_metadata?: boolean;
}

export interface RAGResult {
  content: string;
  metadata?: Record<string, any>;
  similarity_score: number;
  document_id?: string;
}

export interface RAGResponse {
  results: RAGResult[];
  query: string;
  total_results: number;
  processing_time_ms: number;
}

export interface EmbeddingRequest {
  text: string;
  model?: string;
}

export interface EmbeddingResponse {
  embedding: number[];
  model: string;
  usage?: {
    prompt_tokens: number;
    total_tokens: number;
  };
}

export interface Document {
  id: string;
  content: string;
  metadata?: Record<string, any>;
  embedding?: number[];
  created_at: string;
  updated_at: string;
}
