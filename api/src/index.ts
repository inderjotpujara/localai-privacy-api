import express, { Request, Response } from "express";
import fetch from "node-fetch";
import dotenv from "dotenv";

dotenv.config();
const PORT = process.env.PORT || 3000;
const LLM_BASE_URL = process.env.LLM_BASE_URL || "http://localhost:8080/v1";

const app = express();
app.use(express.json());

app.post("/chat", async (req: Request, res: Response) => {
  try {
    console.log("Received request:", JSON.stringify(req.body, null, 2));
    console.log("Forwarding to:", `${LLM_BASE_URL}/chat/completions`);

    const apiRes = await fetch(`${LLM_BASE_URL}/chat/completions`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(req.body),
    });

    console.log("Response status:", apiRes.status);
    console.log(
      "Response headers:",
      Object.fromEntries(apiRes.headers.entries())
    );

    if (!apiRes.ok) {
      const errorText = await apiRes.text();
      console.error("API error response:", errorText);
      return res
        .status(apiRes.status)
        .json({ error: "LLM API error", details: errorText });
    }

    const data = await apiRes.json();
    console.log("Received data from LLM:", data);
    res.json(data);
  } catch (e) {
    console.error("Error in /chat endpoint:", e);
    const errorMessage = e instanceof Error ? e.message : "Unknown error";
    res.status(500).json({ error: "LLM backend error", details: errorMessage });
  }
});

app.post("/summarize", async (req: Request, res: Response) => {
  try {
    const {
      text,
      instructions = "Provide a concise summary",
      max_tokens = 150,
      model = "llama3.2:1b",
    } = req.body;

    // Validate required parameters
    if (!text) {
      return res
        .status(400)
        .json({ error: "Missing required parameter: text" });
    }

    if (typeof text !== "string" || text.trim().length === 0) {
      return res
        .status(400)
        .json({ error: "Text parameter must be a non-empty string" });
    }

    console.log("Received summarization request:", {
      textLength: text.length,
      instructions,
      max_tokens,
    });

    // Create a structured prompt for summarization
    const prompt = `Please summarize the following text according to these instructions: "${instructions}"

Text to summarize:
${text}

Summary:`;

    const requestBody = {
      model,
      messages: [
        {
          role: "user",
          content: prompt,
        },
      ],
      max_tokens,
      temperature: 0.3, // Lower temperature for more focused summarization
      stream: false,
    };

    console.log(
      "Forwarding summarization request to:",
      `${LLM_BASE_URL}/chat/completions`
    );

    const apiRes = await fetch(`${LLM_BASE_URL}/chat/completions`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(requestBody),
    });

    console.log("Response status:", apiRes.status);

    if (!apiRes.ok) {
      const errorText = await apiRes.text();
      console.error("API error response:", errorText);
      return res
        .status(apiRes.status)
        .json({ error: "LLM API error", details: errorText });
    }

    const data = (await apiRes.json()) as any;
    console.log("Received summarization data from LLM");

    // Extract just the summary content for cleaner response
    const summary =
      data.choices?.[0]?.message?.content || "No summary generated";

    res.json({
      summary: summary.trim(),
      original_length: text.length,
      summary_length: summary.trim().length,
      instructions_used: instructions,
      model_used: model,
    });
  } catch (e) {
    console.error("Error in /summarize endpoint:", e);
    const errorMessage = e instanceof Error ? e.message : "Unknown error";
    res
      .status(500)
      .json({ error: "Summarization backend error", details: errorMessage });
  }
});

app.post("/custom-summarize", async (req: Request, res: Response) => {
  try {
    const {
      text,
      style = "concise", // concise, detailed, bullet-points, technical, creative
      tone = "neutral", // neutral, formal, casual, academic
      length = "medium", // short, medium, long
      focus_areas = [], // array of specific areas to focus on
      max_tokens = 200,
      model = "llama3.2:1b",
    } = req.body;

    // Validate required parameters
    if (!text) {
      return res
        .status(400)
        .json({ error: "Missing required parameter: text" });
    }

    if (typeof text !== "string" || text.trim().length === 0) {
      return res
        .status(400)
        .json({ error: "Text parameter must be a non-empty string" });
    }

    console.log("Received custom summarization request:", {
      textLength: text.length,
      style,
      tone,
      length,
      focus_areas,
      max_tokens,
    });

    // Build dynamic instructions based on parameters
    let instructions = "";

    // Style-based instructions
    switch (style) {
      case "bullet-points":
        instructions += "Create a bullet-point summary with key points. ";
        break;
      case "technical":
        instructions +=
          "Provide a technical summary focusing on key concepts and terminology. ";
        break;
      case "detailed":
        instructions += "Provide a comprehensive and detailed summary. ";
        break;
      case "creative":
        instructions += "Create an engaging and creative summary. ";
        break;
      default:
        instructions += "Provide a concise and clear summary. ";
    }

    // Length-based instructions
    switch (length) {
      case "short":
        instructions += "Keep it brief (1-2 sentences). ";
        break;
      case "long":
        instructions +=
          "Provide an extensive summary with multiple paragraphs. ";
        break;
      default:
        instructions += "Use moderate length (2-4 sentences). ";
    }

    // Tone-based instructions
    switch (tone) {
      case "formal":
        instructions += "Use formal and professional language. ";
        break;
      case "casual":
        instructions += "Use casual and conversational language. ";
        break;
      case "academic":
        instructions += "Use academic and scholarly language. ";
        break;
      default:
        instructions += "Use neutral and clear language. ";
    }

    // Focus areas
    if (focus_areas && focus_areas.length > 0) {
      instructions += `Pay special attention to these areas: ${focus_areas.join(
        ", "
      )}. `;
    }

    // Create a structured prompt for custom summarization
    const prompt = `Please summarize the following text according to these specific instructions: "${instructions.trim()}"

    Text to summarize:
    ${text}

    Summary:`;

    const requestBody = {
      model,
      messages: [
        {
          role: "user",
          content: prompt,
        },
      ],
      max_tokens,
      temperature: style === "creative" ? 0.7 : 0.3, // Higher temperature for creative style
      stream: false,
    };

    console.log(
      "Forwarding custom summarization request to:",
      `${LLM_BASE_URL}/chat/completions`
    );

    const apiRes = await fetch(`${LLM_BASE_URL}/chat/completions`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(requestBody),
    });

    console.log("Response status:", apiRes.status);

    if (!apiRes.ok) {
      const errorText = await apiRes.text();
      console.error("API error response:", errorText);
      return res
        .status(apiRes.status)
        .json({ error: "LLM API error", details: errorText });
    }

    const data = (await apiRes.json()) as any;
    console.log("Received custom summarization data from LLM");

    // Extract just the summary content for cleaner response
    const summary =
      data.choices?.[0]?.message?.content || "No summary generated";

    res.json({
      summary: summary.trim(),
      original_length: text.length,
      summary_length: summary.trim().length,
      configuration: {
        style,
        tone,
        length,
        focus_areas,
        instructions_used: instructions.trim(),
      },
      model_used: model,
      timestamp: new Date().toISOString(),
    });
  } catch (e) {
    console.error("Error in /custom-summarize endpoint:", e);
    const errorMessage = e instanceof Error ? e.message : "Unknown error";
    res
      .status(500)
      .json({
        error: "Custom summarization backend error",
        details: errorMessage,
      });
  }
});

app.listen(PORT, () => {
  console.log(`API listening on port ${PORT}`);
});
