# Dify Workflow Configuration Guide

This guide explains how to set up a Dify workflow for the Image to Calendar iOS app.

## Overview

The workflow needs to:
1. Accept an uploaded image file
2. Extract text using OCR or vision model
3. Parse the text with an LLM to identify events
4. Return structured JSON with event data

## Workflow Structure

```
Input → Vision/OCR → LLM Parser → JSON Output
```

## Step-by-Step Setup

### 1. Create New Workflow

1. Log in to Dify
2. Go to **Studio** → **Workflows**
3. Click **Create Workflow**
4. Name it "Image to Calendar Parser"

### 2. Configure Inputs

Add the following input variables:

| Variable Name | Type | Required | Description |
|---------------|------|----------|-------------|
| `file_id` | File | Yes | Uploaded image file ID |
| `additional_text` | String | No | User-provided context |

### 3. Add Vision/OCR Node

**Option A: Using GPT-4 Vision**

1. Add **LLM** node
2. Select model: `gpt-4-vision-preview` or `gpt-4o`
3. Set context variables:
   ```
   {{#file_id#}}
   ```
4. System prompt:
   ```
   Extract all text from this image. The image may contain:
   - Event posters
   - Meeting schedules
   - Handwritten notes
   - Screenshots of calendars

   Return only the extracted text without interpretation.
   ```

**Option B: Using Dedicated OCR**

1. Add **Tool** node
2. Select OCR tool (e.g., Tesseract, Google Vision)
3. Input: `{{#file_id#}}`

### 4. Add LLM Parser Node

1. Add **LLM** node after vision/OCR
2. Select model: `gpt-4` or `claude-sonnet-3.5`
3. Input variables:
   - `extracted_text`: Output from previous node
   - `additional_text`: From workflow input
4. System prompt:

```markdown
You are an expert at parsing event information from text.

Extract all events, meetings, tasks, and deadlines from the following text.

Additional context from user: {{#additional_text#}}

For each event, determine:
1. **Type**: "calendar" or "reminder"
   - Use "calendar" if there's a specific start/end time
   - Use "reminder" if it's a deadline, task, or todo item

2. **Required fields**:
   - title: The event name
   - For calendar: start (ISO8601), end (ISO8601)
   - For reminder: due (ISO8601)

3. **Optional fields**:
   - location: Physical or virtual location
   - notes: Additional details
   - subtasks: Array of sub-items (for reminders)
   - confidence: Your confidence score (0.0-1.0)
   - pending_fields: Array of fields you couldn't determine

**Decision rules**:
- Start AND end time found → type: "calendar"
- Only due date/deadline → type: "reminder"
- Contains checklist or tasks → type: "reminder" with subtasks
- Ambiguous time ("this Wednesday") → mark "time" as pending, use best guess
- No location found → omit or leave empty string
- Multiple events on same day → create separate entries

**Date parsing**:
- Use current date as context: {{#sys.date#}}
- Relative dates: "tomorrow", "next week", "Wednesday"
- Time: Convert to 24-hour ISO8601 format
- Timezone: Assume user's timezone (you can include in inputs)

**Output format** (strict JSON only):

{
  "events": [
    {
      "type": "calendar",
      "title": "Team Standup",
      "start": "2025-11-15T09:00:00Z",
      "end": "2025-11-15T09:30:00Z",
      "location": "Zoom",
      "notes": "Daily sync meeting",
      "confidence": 0.95,
      "pending_fields": []
    },
    {
      "type": "reminder",
      "title": "Submit report",
      "due": "2025-11-20T17:00:00Z",
      "notes": "Q4 financial report",
      "subtasks": ["Gather data", "Write summary", "Review with manager"],
      "confidence": 0.87,
      "pending_fields": ["time"]
    }
  ]
}

If no events found, return: {"events": []}

Text to parse:
{{#extracted_text#}}
```

5. Configure output:
   - Format: JSON
   - Variable name: `parsed_events`

### 5. Add Code Node (Optional Validation)

If you want to validate the JSON before returning:

```python
import json
from datetime import datetime

def main(parsed_events: str) -> dict:
    try:
        data = json.loads(parsed_events)

        # Validate structure
        if "events" not in data:
            return {"events": []}

        validated_events = []
        for event in data["events"]:
            # Required fields
            if "type" not in event or "title" not in event:
                continue

            # Validate type
            if event["type"] not in ["calendar", "reminder"]:
                continue

            # Validate dates
            if event["type"] == "calendar":
                if "start" not in event or "end" not in event:
                    continue
                # Validate ISO8601
                try:
                    datetime.fromisoformat(event["start"].replace("Z", "+00:00"))
                    datetime.fromisoformat(event["end"].replace("Z", "+00:00"))
                except:
                    continue

            if event["type"] == "reminder" and "due" in event:
                try:
                    datetime.fromisoformat(event["due"].replace("Z", "+00:00"))
                except:
                    continue

            # Set defaults
            if "confidence" not in event:
                event["confidence"] = 0.5
            if "pending_fields" not in event:
                event["pending_fields"] = []

            validated_events.append(event)

        return {"events": validated_events}

    except Exception as e:
        return {"events": [], "error": str(e)}

# Dify will call this with parsed_events input
result = main(parsed_events)
return result
```

### 6. Configure Output

1. Add **End** node
2. Set output variable: `result`
3. Map to validated events: `{{#code_node_output#}}`

## Complete Workflow Example

```yaml
name: Image to Calendar Parser
version: 1.0

inputs:
  - name: file_id
    type: file
    required: true
  - name: additional_text
    type: string
    required: false

nodes:
  - id: vision
    type: llm
    model: gpt-4-vision-preview
    inputs:
      - file: "{{#file_id#}}"
    prompt: "Extract all text from this image..."
    output: extracted_text

  - id: parser
    type: llm
    model: gpt-4
    inputs:
      - extracted_text: "{{#vision.extracted_text#}}"
      - additional_text: "{{#additional_text#}}"
    prompt: "Parse events from text..."
    output: parsed_events

  - id: validator
    type: code
    language: python
    code: |
      # Validation code here
    inputs:
      - parsed_events: "{{#parser.parsed_events#}}"
    output: validated_events

outputs:
  - name: result
    value: "{{#validator.validated_events#}}"
```

## Testing the Workflow

### Test Case 1: Event Poster

**Input Image**: Conference poster with:
- Title: "AI Summit 2025"
- Date: "November 15-16, 2025"
- Time: "9:00 AM - 5:00 PM"
- Location: "San Francisco Convention Center"

**Expected Output**:
```json
{
  "events": [
    {
      "type": "calendar",
      "title": "AI Summit 2025 - Day 1",
      "start": "2025-11-15T09:00:00-08:00",
      "end": "2025-11-15T17:00:00-08:00",
      "location": "San Francisco Convention Center",
      "notes": "AI Summit 2025",
      "confidence": 0.95,
      "pending_fields": []
    },
    {
      "type": "calendar",
      "title": "AI Summit 2025 - Day 2",
      "start": "2025-11-16T09:00:00-08:00",
      "end": "2025-11-16T17:00:00-08:00",
      "location": "San Francisco Convention Center",
      "notes": "AI Summit 2025",
      "confidence": 0.95,
      "pending_fields": []
    }
  ]
}
```

### Test Case 2: Todo List

**Input Image**: Handwritten checklist:
- "Buy groceries"
- "Call dentist - by Friday"
- "Submit project proposal - Nov 20 5pm"

**Expected Output**:
```json
{
  "events": [
    {
      "type": "reminder",
      "title": "Buy groceries",
      "notes": "Shopping task",
      "confidence": 0.8,
      "pending_fields": ["due"]
    },
    {
      "type": "reminder",
      "title": "Call dentist",
      "due": "2025-11-15T17:00:00Z",
      "notes": "By Friday",
      "confidence": 0.75,
      "pending_fields": ["time"]
    },
    {
      "type": "reminder",
      "title": "Submit project proposal",
      "due": "2025-11-20T17:00:00Z",
      "notes": "Project deadline",
      "confidence": 0.90,
      "pending_fields": []
    }
  ]
}
```

### Test Case 3: Meeting Schedule

**Input Image**: Screenshot of Zoom meeting:
- "Team Standup"
- "Tomorrow 9:00-9:30 AM"
- "Zoom link: https://zoom.us/j/123456"

**Expected Output**:
```json
{
  "events": [
    {
      "type": "calendar",
      "title": "Team Standup",
      "start": "2025-11-12T09:00:00Z",
      "end": "2025-11-12T09:30:00Z",
      "location": "https://zoom.us/j/123456",
      "notes": "Virtual meeting",
      "confidence": 0.92,
      "pending_fields": []
    }
  ]
}
```

## Optimization Tips

### 1. Improve OCR Accuracy

- Preprocess images: resize, denoise, enhance contrast
- Use multiple OCR engines and combine results
- Add retry logic for low-confidence extractions

### 2. Better Date Parsing

- Include user's timezone in workflow inputs
- Use NLP libraries for relative date parsing
- Provide current date/time as context to LLM

### 3. Handle Edge Cases

- Multiple events on same line
- Events spanning multiple days
- Recurring events (expand first occurrence)
- Conflicting time formats (12h vs 24h)

### 4. Confidence Scoring

Adjust confidence based on:
- OCR quality
- Date format clarity
- Missing fields count
- LLM response certainty

### 5. Caching

- Cache common patterns (e.g., "tomorrow", "next week")
- Store parsed results for duplicate images
- Use Dify's built-in caching features

## Troubleshooting

### Issue: Low confidence scores

**Solution**:
- Improve image quality
- Add more context in additional_text
- Fine-tune LLM prompt with examples

### Issue: Missing events

**Solution**:
- Check OCR accuracy (test extracted_text output)
- Ensure LLM prompt covers all event types
- Add logging to see intermediate outputs

### Issue: Wrong dates

**Solution**:
- Verify current date is passed correctly
- Check timezone handling
- Add explicit date format examples in prompt

### Issue: JSON parsing errors

**Solution**:
- Add validation node
- Use JSON repair libraries
- Set LLM temperature to 0 for consistency

## Advanced Features

### Multi-language Support

Add language detection and translate before parsing:

```python
from langdetect import detect
from googletrans import Translator

def translate_if_needed(text: str) -> str:
    lang = detect(text)
    if lang != 'en':
        translator = Translator()
        return translator.translate(text, dest='en').text
    return text
```

### Recurring Events

Detect patterns like "Every Monday at 2pm":

```json
{
  "type": "calendar",
  "title": "Weekly Team Meeting",
  "start": "2025-11-11T14:00:00Z",
  "end": "2025-11-11T15:00:00Z",
  "recurrence": {
    "frequency": "weekly",
    "interval": 1,
    "by_day": ["MO"],
    "count": 52
  },
  "confidence": 0.85
}
```

### Smart Categorization

Auto-assign calendar categories:

```python
def categorize_event(title: str, notes: str) -> str:
    keywords = {
        "work": ["meeting", "standup", "review", "sprint"],
        "personal": ["dentist", "gym", "birthday"],
        "health": ["doctor", "therapy", "checkup"],
        "finance": ["tax", "payment", "invoice"]
    }

    text = (title + " " + notes).lower()
    for category, words in keywords.items():
        if any(word in text for word in words):
            return category
    return "other"
```

## API Rate Limits

Be aware of Dify and LLM provider rate limits:

- OpenAI GPT-4 Vision: 100 requests/min
- Anthropic Claude: 50 requests/min
- Dify workflow: Check your plan limits

Implement queuing in backend if needed.

## Monitoring

Track these metrics in Dify:

- **Success rate**: % of successful parses
- **Confidence distribution**: Average confidence scores
- **Processing time**: P50, P90, P99 latencies
- **Error types**: OCR failures, JSON errors, etc.

## Cost Optimization

- Use GPT-4o-mini for simple images
- Implement image compression before upload
- Cache common queries
- Batch process when possible

## Security

- Validate file types (only images)
- Limit file size (10MB max)
- Sanitize extracted text
- Don't log sensitive information

## Next Steps

1. Test workflow with various image types
2. Tune confidence thresholds
3. Add feedback loop to improve prompts
4. Monitor usage and costs
5. Iterate on edge cases

## Resources

- [Dify Documentation](https://docs.dify.ai)
- [OpenAI Vision API](https://platform.openai.com/docs/guides/vision)
- [ISO8601 Date Format](https://en.wikipedia.org/wiki/ISO_8601)

---

Happy parsing! 🎉
