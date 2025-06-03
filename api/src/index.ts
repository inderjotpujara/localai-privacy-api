import express, { Request, Response } from 'express';
import fetch from 'node-fetch';
import dotenv from 'dotenv';

dotenv.config();
const PORT = process.env.PORT || 3000;
const LLM_BASE_URL = process.env.LLM_BASE_URL || 'http://localhost:8080/v1';

const app = express();
app.use(express.json());

app.post('/chat', async (req: Request, res: Response) => {
  try {
    console.log('Received request:', JSON.stringify(req.body, null, 2));
    console.log('Forwarding to:', `${LLM_BASE_URL}/chat/completions`);
    
    const apiRes = await fetch(`${LLM_BASE_URL}/chat/completions`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(req.body)
    });
    
    console.log('Response status:', apiRes.status);
    console.log('Response headers:', Object.fromEntries(apiRes.headers.entries()));
    
    if (!apiRes.ok) {
      const errorText = await apiRes.text();
      console.error('API error response:', errorText);
      return res.status(apiRes.status).json({ error: 'LLM API error', details: errorText });
    }
    
    const data = await apiRes.json();
    console.log('Received data from LLM:', data);
    res.json(data);
  } catch (e) {
    console.error('Error in /chat endpoint:', e);
    const errorMessage = e instanceof Error ? e.message : 'Unknown error';
    res.status(500).json({ error: 'LLM backend error', details: errorMessage });
  }
});

app.listen(PORT, () => {
  console.log(`API listening on port ${PORT}`);
});
