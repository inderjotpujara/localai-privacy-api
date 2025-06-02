import axios, { AxiosInstance } from 'axios';
import pino from 'pino';
import { ChatMessage, ChatRequest, ChatResponse, EmbeddingRequest, EmbeddingResponse, StreamChunk } from '../types';

const logger = pino();

export class LocalAIService {
  private client: AxiosInstance;
  private baseUrl: string;
  private model: string;

  constructor() {
    this.baseUrl = process.env.LOCALAI_URL || 'http://localhost:8080';
    this.model = process.env.LOCALAI_MODEL || 'llama3';
    
    this.client = axios.create({
      baseURL: this.baseUrl,
      timeout: 120000, // 2 minutes timeout for LLM responses
      headers: {
        'Content-Type': 'application/json',
      },
    });

    // Add request/response interceptors for logging
    this.client.interceptors.request.use(
      (config) => {
        logger.debug(`LocalAI Request: ${config.method?.toUpperCase()} ${config.url}`);
        return config;
      },
      (error) => {
        logger.error('LocalAI Request Error:', error);
        return Promise.reject(error);
      }
    );

    this.client.interceptors.response.use(
      (response) => {
        logger.debug(`LocalAI Response: ${response.status} ${response.statusText}`);
        return response;
      },
      (error) => {
        logger.error('LocalAI Response Error:', {
          status: error.response?.status,
          statusText: error.response?.statusText,
          data: error.response?.data,
          message: error.message,
        });
        return Promise.reject(error);
      }
    );
  }

  async chat(request: ChatRequest): Promise<ChatResponse> {
    try {
      const messages = this.buildMessages(request);
      
      const payload = {
        model: this.model,
        messages,
        temperature: request.temperature || 0.7,
        max_tokens: request.max_tokens || 512,
        stream: false, // Non-streaming response
      };

      const response = await this.client.post('/v1/chat/completions', payload);
      
      const choice = response.data.choices?.[0];
      if (!choice) {
        throw new Error('No response from LocalAI');
      }

      return {
        message: choice.message.content,
        model: response.data.model || this.model,
        usage: response.data.usage,
        timestamp: new Date().toISOString(),
      };

    } catch (error) {
      logger.error('Error in chat completion:', error);
      throw this.handleError(error);
    }
  }

  async *chatStream(request: ChatRequest): AsyncGenerator<StreamChunk, void, unknown> {
    try {
      const messages = this.buildMessages(request);
      
      const payload = {
        model: this.model,
        messages,
        temperature: request.temperature || 0.7,
        max_tokens: request.max_tokens || 512,
        stream: true,
      };

      const response = await this.client.post('/v1/chat/completions', payload, {
        responseType: 'stream',
      });

      let buffer = '';
      
      for await (const chunk of response.data) {
        buffer += chunk.toString();
        
        // Process complete lines
        const lines = buffer.split('\n');
        buffer = lines.pop() || ''; // Keep incomplete line in buffer
        
        for (const line of lines) {
          if (line.trim() === '') continue;
          if (line.startsWith('data: ')) {
            const data = line.slice(6).trim();
            
            if (data === '[DONE]') {
              yield { content: '', done: true };
              return;
            }
            
            try {
              const parsed = JSON.parse(data);
              const delta = parsed.choices?.[0]?.delta;
              
              if (delta?.content) {
                yield { 
                  content: delta.content, 
                  done: false 
                };
              }
            } catch (parseError) {
              logger.warn('Failed to parse SSE data:', data);
            }
          }
        }
      }
      
    } catch (error) {
      logger.error('Error in streaming chat:', error);
      throw this.handleError(error);
    }
  }

  async generateEmbedding(request: EmbeddingRequest): Promise<EmbeddingResponse> {
    try {
      const payload = {
        model: request.model || 'all-MiniLM-L6-v2',
        input: request.text,
      };

      const response = await this.client.post('/v1/embeddings', payload);
      
      const embedding = response.data.data?.[0]?.embedding;
      if (!embedding) {
        throw new Error('No embedding returned from LocalAI');
      }

      return {
        embedding,
        model: response.data.model || payload.model,
        usage: response.data.usage,
      };

    } catch (error) {
      logger.error('Error generating embedding:', error);
      throw this.handleError(error);
    }
  }

  async getModels(): Promise<string[]> {
    try {
      const response = await this.client.get('/v1/models');
      return response.data.data?.map((model: any) => model.id) || [];
    } catch (error) {
      logger.error('Error fetching models:', error);
      throw this.handleError(error);
    }
  }

  async healthCheck(): Promise<boolean> {
    try {
      const response = await this.client.get('/readyz', { timeout: 5000 });
      return response.status === 200;
    } catch (error) {
      logger.warn('LocalAI health check failed:', error);
      return false;
    }
  }

  private buildMessages(request: ChatRequest): ChatMessage[] {
    const messages: ChatMessage[] = [];
    
    // Add context messages if provided
    if (request.context && request.context.length > 0) {
      messages.push(...request.context);
    }
    
    // Add the user message
    messages.push({
      role: 'user',
      content: request.message,
      timestamp: new Date().toISOString(),
    });

    return messages;
  }

  private handleError(error: any): Error {
    if (error.response) {
      // LocalAI returned an error response
      const status = error.response.status;
      const message = error.response.data?.error?.message || error.response.statusText;
      
      switch (status) {
        case 400:
          return new Error(`Bad request to LocalAI: ${message}`);
        case 404:
          return new Error(`Model not found: ${this.model}`);
        case 500:
          return new Error(`LocalAI server error: ${message}`);
        case 503:
          return new Error('LocalAI service unavailable');
        default:
          return new Error(`LocalAI error (${status}): ${message}`);
      }
    } else if (error.request) {
      // Request was made but no response received
      return new Error('Unable to connect to LocalAI. Please check if the service is running.');
    } else {
      // Something else happened
      return new Error(`LocalAI service error: ${error.message}`);
    }
  }
}
