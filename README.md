# Image to Calendar

An iPhone app that converts images (event posters, handwritten schedules, screenshots) into structured calendar events and reminders using AI-powered parsing via Dify workflows.

## 🎯 Features

- **Image to Event Parsing**: Upload or capture images containing event information
- **Intelligent Classification**: Automatically determines whether to create Calendar events or Reminders
- **Smart Detection**:
  - Conflict detection for overlapping events
  - Duplicate detection to prevent redundant entries
- **Native Integration**: Writes directly to iOS Calendar and Reminders apps using EventKit
- **User Confirmation**: Review and edit all parsed events before adding
- **Undo Functionality**: Remove recently added events with one tap
- **Privacy-First**: Images can be auto-deleted after parsing, no external data storage

## 📋 Requirements

- iOS 15.0+
- Xcode 14.0+
- Swift 5.7+
- Dify workflow backend (see Backend Setup)

## 🏗️ Architecture

```
┌─────────────────┐
│   iOS App       │
│   (SwiftUI)     │
└────────┬────────┘
         │
         ↓
┌─────────────────┐
│ Backend Proxy   │
│ (Vercel/CF)     │
└────────┬────────┘
         │
         ↓
┌─────────────────┐
│  Dify Workflow  │
│  (OCR + LLM)    │
└─────────────────┘
         │
         ↓
    ┌────────┐
    │  JSON  │
    └────────┘
         │
         ↓
┌─────────────────┐
│ iOS EventKit &  │
│   Reminders     │
└─────────────────┘
```

## 📱 App Structure

```
ImageToCalendar/
├── App/
│   └── ImageToCalendarApp.swift       # Main app entry point
├── Models/
│   └── EventModels.swift              # Data models for events
├── Services/
│   ├── DifyService.swift              # Backend API integration
│   ├── CalendarService.swift          # EventKit for Calendar
│   └── RemindersService.swift         # Reminders framework
├── Views/
│   ├── ContentView.swift              # Main upload view
│   ├── ConfirmationView.swift         # Event review/edit UI
│   ├── EventCardView.swift            # Individual event card
│   └── SettingsView.swift             # Settings & undo
├── Utilities/
│   ├── ImagePicker.swift              # Camera/photo picker
│   └── DateFormatter+Extensions.swift # Date formatting
└── Resources/
    ├── Assets.xcassets                # App icons & images
    └── Info.plist                     # Permissions & config
```

## 🚀 Quick Start

### 1. Clone and Open Project

```bash
git clone <repository-url>
cd BenhzCue
open ImageToCalendar/ImageToCalendar.xcodeproj
```

### 2. Configure Backend

The app requires a backend proxy to communicate with Dify. Set your backend URL in the app's Settings screen or configure it as an environment variable.

### 3. Build and Run

1. Select a target device (iPhone simulator or physical device)
2. Press `Cmd+R` to build and run
3. Allow camera and photo library permissions when prompted

## 🔧 Backend Setup

### Expected API Endpoint

```
POST /api/parse
Content-Type: multipart/form-data

Parameters:
- image: File (JPEG/PNG)
- text: String (optional context)

Response:
{
  "events": [
    {
      "type": "calendar" | "reminder",
      "title": "string",
      "start": "ISO8601 datetime",
      "end": "ISO8601 datetime",
      "due": "ISO8601 datetime",
      "location": "string",
      "notes": "string",
      "subtasks": ["string"],
      "confidence": 0.87,
      "pending_fields": ["time", "location"]
    }
  ]
}
```

### Sample Backend Implementation (Node.js + Vercel)

```javascript
// api/parse.js
import { FormData } from 'formdata-node';
import fetch from 'node-fetch';

export default async function handler(req, res) {
  if (req.method !== 'POST') {
    return res.status(405).json({ error: 'Method not allowed' });
  }

  try {
    // 1. Upload image to Dify
    const formData = new FormData();
    formData.append('file', req.files.image.data, {
      filename: 'image.jpg',
      contentType: 'image/jpeg',
    });

    const uploadResponse = await fetch(
      'https://api.dify.ai/v1/files/upload',
      {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${process.env.DIFY_API_KEY}`,
        },
        body: formData,
      }
    );

    const uploadData = await uploadResponse.json();
    const fileId = uploadData.id;

    // 2. Trigger Dify workflow
    const workflowResponse = await fetch(
      `https://api.dify.ai/v1/workflows/${process.env.DIFY_WORKFLOW_ID}/run`,
      {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${process.env.DIFY_API_KEY}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          inputs: {
            file_id: fileId,
            additional_text: req.body.text || '',
          },
          response_mode: 'blocking',
        }),
      }
    );

    const workflowData = await workflowResponse.json();

    // 3. Return structured events
    return res.status(200).json(workflowData.data.outputs);

  } catch (error) {
    console.error('Parse error:', error);
    return res.status(500).json({ error: error.message });
  }
}
```

### Environment Variables

```bash
DIFY_API_KEY=your-dify-api-key
DIFY_WORKFLOW_ID=your-workflow-id
```

## 📊 Dify Workflow Design

Your Dify workflow should:

1. **Accept inputs**: `file_id`, `additional_text`
2. **Extract text**: Use OCR or vision model to read image content
3. **Parse with LLM**: Use a prompt like:

```
Extract all events from this text and return JSON:
{
  "events": [
    {
      "type": "calendar" or "reminder",
      "title": "event name",
      "start": "ISO8601 if calendar",
      "end": "ISO8601 if calendar",
      "due": "ISO8601 if reminder",
      "location": "place",
      "notes": "description",
      "subtasks": ["task1", "task2"],
      "confidence": 0.0-1.0,
      "pending_fields": ["missing info"]
    }
  ]
}

Decision rules:
- Has start & end time → calendar
- Has deadline/due date → reminder
- Has checklist → reminder with subtasks
```

4. **Return JSON**: Output the structured event data

## 🔐 Permissions

The app requires:

- **Camera**: Capture event posters
- **Photo Library**: Select existing images
- **Calendar**: Create calendar events
- **Reminders**: Create reminder tasks

Permissions are requested only when needed (not on first launch).

## ⚙️ Default Behaviors

| Setting | Default | Description |
|---------|---------|-------------|
| Event duration | 60 min | If no end time specified |
| Alert timing | 10 min | Notification before event |
| Conflict threshold | 15 min | Minimum overlap to flag |
| Timezone | Device | Uses device's current timezone |

## 🎨 UI Flow

1. **Upload Screen**
   - Select photo or take picture
   - Add optional context text
   - Press "Parse Events"

2. **Processing**
   - Shows loading indicator
   - Sends to backend → Dify

3. **Confirmation Screen**
   - Review each parsed event
   - Toggle between Calendar/Reminder
   - Edit title, dates, location, notes
   - See conflict/duplicate warnings
   - Confidence scores (color-coded)

4. **System Write**
   - Request permissions if needed
   - Write to iOS Calendar/Reminders
   - Show success confirmation

5. **Settings/Undo**
   - View recent events
   - Undo last additions
   - Configure backend URL

## 📈 Success Metrics (Target)

- Parse success rate: ≥90%
- Calendar/Reminder write success: ≥95%
- Average parse latency: ≤10s (P90 ≤15s)
- User modification rate: ≤40%

## 🔒 Privacy & Safety

- Images deleted after parsing (configurable)
- No external storage of calendar data
- Explicit consent before API calls
- All data stays on device except during parsing

## 🐛 Troubleshooting

### "Permission Denied" Error

Go to Settings → ImageToCalendar → Enable Calendar and Reminders

### "Backend Error"

Check Settings → Backend Configuration → Ensure URL is correct and backend is running

### Events Not Appearing

- Verify permission status in Settings
- Check if event was added to default calendar
- Look for errors in undo list

### Low Confidence Scores

- Use clearer images with better lighting
- Add context text to help parsing
- Manually edit fields marked as "pending"

## 🛠️ Development

### Running Tests

```bash
# Run unit tests
xcodebuild test -scheme ImageToCalendar -destination 'platform=iOS Simulator,name=iPhone 14'
```

### Code Structure Guidelines

- **Models**: Pure data structures, Codable-compliant
- **Services**: Business logic, API calls, EventKit operations
- **Views**: SwiftUI views, minimal logic
- **ViewModels**: @MainActor classes with @Published properties

### Adding New Features

1. Update models if needed
2. Add service methods
3. Create/modify views
4. Update confirmation flow
5. Test permissions

## 📄 License

MIT License - See LICENSE file for details

## 🤝 Contributing

Contributions welcome! Please:

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Submit a pull request

## 📧 Support

For issues and questions:
- GitHub Issues: [repository-url]/issues
- Documentation: See inline code comments

## 🗺️ Roadmap

### v1.0 (MVP) ✅
- Basic image parsing
- Calendar/Reminder creation
- Conflict/duplicate detection
- Undo functionality

### v1.1 (Planned)
- Batch processing (multiple images)
- Custom reminder lists
- Recurring events support
- Export/import settings

### v2.0 (Future)
- iCloud sync
- Shared calendars support
- Multi-language support
- Widget support
- Apple Watch companion

## 🙏 Acknowledgments

- EventKit framework by Apple
- Dify.AI for workflow platform
- SwiftUI community

---

Built with ❤️ using Swift and SwiftUI
