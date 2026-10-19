package handlers

import (
	"bytes"
	"encoding/json"
	"fmt"
	"net/http"
	"os"
	"strings"
)

const claudeModel = "claude-haiku-4-5-20251001"

// callClaude sends a single-turn message with the given content blocks to the
// Anthropic Messages API and returns the trimmed text of the reply, with any
// markdown code fences stripped (Claude sometimes wraps JSON in ```json blocks
// despite being told not to).
func callClaude(content []map[string]interface{}, maxTokens int) (string, error) {
	apiKey := os.Getenv("ANTHROPIC_API_KEY")
	if apiKey == "" {
		return "", fmt.Errorf("ANTHROPIC_API_KEY not configured")
	}

	reqBody, _ := json.Marshal(map[string]interface{}{
		"model":      claudeModel,
		"max_tokens": maxTokens,
		"messages": []map[string]interface{}{
			{"role": "user", "content": content},
		},
	})

	req, _ := http.NewRequest("POST", "https://api.anthropic.com/v1/messages", bytes.NewReader(reqBody))
	req.Header.Set("x-api-key", apiKey)
	req.Header.Set("anthropic-version", "2023-06-01")
	req.Header.Set("content-type", "application/json")

	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		return "", fmt.Errorf("failed to reach Anthropic API: %w", err)
	}
	defer resp.Body.Close()

	var claudeResp struct {
		Content []struct {
			Text string `json:"text"`
		} `json:"content"`
		Error *struct {
			Message string `json:"message"`
		} `json:"error"`
	}
	json.NewDecoder(resp.Body).Decode(&claudeResp)

	if claudeResp.Error != nil {
		return "", fmt.Errorf("%s", claudeResp.Error.Message)
	}
	if len(claudeResp.Content) == 0 {
		return "", fmt.Errorf("empty response from Claude")
	}

	text := strings.TrimSpace(claudeResp.Content[0].Text)
	if strings.HasPrefix(text, "```") {
		text = strings.TrimPrefix(text, "```json")
		text = strings.TrimPrefix(text, "```")
		if idx := strings.LastIndex(text, "```"); idx != -1 {
			text = text[:idx]
		}
		text = strings.TrimSpace(text)
	}
	return text, nil
}
