// Example: RAG (Retrieval Augmented Generation) usage
// Usage: node examples/rag-example.js

const axios = require('axios');

const API_URL = 'http://localhost:3000';
const JWT_TOKEN = 'your-jwt-token-here'; // Replace with actual token

async function testRAG() {
  try {
    console.log('🔍 Testing Local LLM RAG API...\n');

    // Add sample documents
    console.log('📄 Adding sample documents to knowledge base...');
    
    const documents = [
      {
        content: "LocalAI is a self-hosted, community-driven, local OpenAI-compatible API. It acts as a drop-in replacement REST API that is compatible with OpenAI API specifications for local inferencing.",
        metadata: { source: "localai-docs", category: "introduction" }
      },
      {
        content: "RAG (Retrieval Augmented Generation) combines the power of large language models with external knowledge bases. It retrieves relevant information and uses it to generate more accurate and contextual responses.",
        metadata: { source: "ai-concepts", category: "techniques" }
      },
      {
        content: "pgvector is a PostgreSQL extension that provides vector similarity search capabilities. It enables efficient storage and querying of high-dimensional vectors for machine learning applications.",
        metadata: { source: "database-docs", category: "technology" }
      }
    ];

    const documentIds = [];
    
    for (const doc of documents) {
      const response = await axios.post(`${API_URL}/rag/documents`, doc, {
        headers: {
          'Authorization': `Bearer ${JWT_TOKEN}`,
          'Content-Type': 'application/json'
        }
      });
      
      documentIds.push(response.data.document_id);
      console.log(`✅ Added document: ${response.data.document_id}`);
    }

    console.log('\n🔍 Querying knowledge base...');

    // Test different queries
    const queries = [
      "What is LocalAI?",
      "How does RAG work?",
      "Tell me about vector databases",
      "What technologies are mentioned?"
    ];

    for (const query of queries) {
      console.log(`\n❓ Query: "${query}"`);
      
      const response = await axios.post(`${API_URL}/rag/query`, {
        query,
        limit: 2,
        similarity_threshold: 0.5,
        include_metadata: true
      }, {
        headers: {
          'Authorization': `Bearer ${JWT_TOKEN}`,
          'Content-Type': 'application/json'
        }
      });

      const results = response.data.results;
      console.log(`📊 Found ${results.length} relevant documents:`);
      
      results.forEach((result, index) => {
        console.log(`  ${index + 1}. Similarity: ${result.similarity_score.toFixed(3)}`);
        console.log(`     Content: ${result.content.substring(0, 100)}...`);
        console.log(`     Category: ${result.metadata?.category || 'N/A'}`);
      });
      
      console.log(`⏱️  Processing time: ${response.data.processing_time_ms}ms`);
    }

    // Test retrieving a specific document
    if (documentIds.length > 0) {
      console.log(`\n📖 Retrieving document: ${documentIds[0]}`);
      
      const docResponse = await axios.get(`${API_URL}/rag/documents/${documentIds[0]}`, {
        headers: {
          'Authorization': `Bearer ${JWT_TOKEN}`
        }
      });
      
      console.log('Document details:', {
        id: docResponse.data.id,
        content_length: docResponse.data.content.length,
        metadata: docResponse.data.metadata,
        created_at: docResponse.data.created_at
      });
    }

  } catch (error) {
    console.error('❌ Error:', error.response?.data || error.message);
  }
}

// Run the example
testRAG();
