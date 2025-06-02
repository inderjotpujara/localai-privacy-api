// Example: Chat with the Local LLM API
// Usage: node examples/chat-example.js

const axios = require('axios');

const API_URL = 'http://localhost:3000';
const JWT_TOKEN = 'your-jwt-token-here'; // Replace with actual token

async function testChat() {
  try {
    console.log('🤖 Testing Local LLM Chat API...\n');

    // Test regular chat
    console.log('💬 Regular Chat:');
    const chatResponse = await axios.post(`${API_URL}/chat`, {
      message: "Explain the concept of RAG (Retrieval Augmented Generation) in simple terms.",
      stream: false,
      temperature: 0.7,
      max_tokens: 200
    }, {
      headers: {
        'Authorization': `Bearer ${JWT_TOKEN}`,
        'Content-Type': 'application/json'
      }
    });

    console.log('Response:', chatResponse.data.message);
    console.log('Model:', chatResponse.data.model);
    console.log('Processing time:', chatResponse.data.processing_time_ms, 'ms\n');

    // Test streaming chat
    console.log('🌊 Streaming Chat:');
    const streamResponse = await axios.post(`${API_URL}/chat`, {
      message: "Count from 1 to 10, one number per line.",
      stream: true,
      temperature: 0.3,
      max_tokens: 100
    }, {
      headers: {
        'Authorization': `Bearer ${JWT_TOKEN}`,
        'Content-Type': 'application/json'
      },
      responseType: 'stream'
    });

    streamResponse.data.on('data', (chunk) => {
      const lines = chunk.toString().split('\n');
      for (const line of lines) {
        if (line.startsWith('data: ')) {
          const data = line.slice(6).trim();
          if (data === '[DONE]') {
            console.log('\n✅ Stream completed');
            return;
          }
          try {
            const parsed = JSON.parse(data);
            if (parsed.type === 'chunk') {
              process.stdout.write(parsed.content);
            }
          } catch (e) {
            // Ignore parse errors
          }
        }
      }
    });

  } catch (error) {
    console.error('❌ Error:', error.response?.data || error.message);
  }
}

// Run the example
testChat();
