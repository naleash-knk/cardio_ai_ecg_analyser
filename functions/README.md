# AI Chat Cloud Function Setup

## 1) Create Python virtual environment and install dependencies

```bash
cd functions
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
```

## 2) Set Groq API key as Firebase Secret

```bash
firebase functions:secrets:set GROQ_API_KEY --project YOUR_PROJECT_ID
```

## 3) Deploy functions

```bash
firebase deploy --only functions --project YOUR_PROJECT_ID
```

This deploys `aiAvatarChat` in `us-central1`.

## 4) Flutter side

Flutter uses `cloud_functions` and calls:

- function: `aiAvatarChat`
- region: `us-central1`

If your function region changes, update it in:

- `lib/ai_chat/ai_chat_service.dart`

## 5) Security

- Function requires authenticated users (`request.auth` check).
- Groq API key is server-side only via Firebase Secret.

## 6) Firebase init notes (for Python)

If this repo is not initialized yet, run:

```bash
firebase init functions
```

Then choose:
- existing project (`YOUR_PROJECT_ID`)
- language: `Python`
- source directory: `functions`

Do not overwrite existing `functions/main.py` and `functions/requirements.txt`.
