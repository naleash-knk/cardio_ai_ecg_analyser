import requests
from firebase_admin import initialize_app
from firebase_functions import https_fn, options
from firebase_functions.params import SecretParam

initialize_app()

GROQ_API_KEY = SecretParam("GROQ_API_KEY")
DEFAULT_MODEL = "llama-3.1-8b-instant"
MODEL_FALLBACKS = (
    "llama-3.1-8b-instant",
    "llama-3.3-70b-versatile",
    "mixtral-8x7b-32768",
)


def _coerce_int(value, default=0):
    try:
        if value is None:
            return default
        if isinstance(value, bool):
            return int(value)
        if isinstance(value, (int, float)):
            return int(value)
        text = str(value).strip()
        if not text:
            return default
        return int(float(text))
    except (TypeError, ValueError):
        return default


def _coerce_float(value, default=0.0):
    try:
        if value is None:
            return default
        if isinstance(value, bool):
            return float(int(value))
        if isinstance(value, (int, float)):
            number = float(value)
        else:
            text = str(value).strip()
            if not text:
                return default
            number = float(text)
        if number != number:  # NaN guard
            return default
        if number == float("inf") or number == float("-inf"):
            return default
        return number
    except (TypeError, ValueError):
        return default


def _sanitize_patient_profile(raw):
    if not isinstance(raw, dict):
        return {}
    return raw


def _sanitize_checked_samples(raw_samples):
    if not isinstance(raw_samples, list):
        return []

    cleaned = []
    for sample in raw_samples:
        if not isinstance(sample, dict):
            continue
        timestamp = _coerce_int(sample.get("timestamp", 0), 0)
        heart_rate = _coerce_int(sample.get("heartRate", 0), 0)
        rr_interval = _coerce_float(sample.get("rrInterval", 0.0), 0.0)
        if timestamp < 0:
            timestamp = 0
        if heart_rate < 0:
            heart_rate = 0
        if rr_interval < 0:
            rr_interval = 0.0
        cleaned.append(
            {
                "timestamp": timestamp,
                "heartRate": heart_rate,
                "rrInterval": rr_interval,
            }
        )
    return cleaned[-30:]


def _build_structured_context(patient_profile, ecg_report, patient_query):
    status = str(ecg_report.get("status", "none")).strip().lower()
    if status not in ("normal", "abnormal"):
        status = "none"

    checked_samples = _sanitize_checked_samples(ecg_report.get("checkedSamples", []))
    sample_lines = []
    for item in checked_samples:
        sample_lines.append(
            f'{item["timestamp"]}, {item["heartRate"]}, {item["rrInterval"]:.2f}'
        )
    samples_block = "\n".join(sample_lines) if sample_lines else "Not available."

    return (
        "Patient profile (structured):\n"
        f"{patient_profile}\n\n"
        "ECG report (structured):\n"
        f"- status: {status}\n"
        f"- checkedSamplesCount: {len(checked_samples)}\n"
        "- checkedSamples(timestamp, heartRate, rrInterval):\n"
        f"{samples_block}\n\n"
        "Instruction:\n"
        "- Use patient profile + ECG report + patient query.\n"
        "- Provide remedies and caring guidance that is practical and safe.\n"
        "- If emergency red flags are present, recommend immediate ER/professional care.\n\n"
        "Patient query:\n"
        f"{patient_query}"
    )


@https_fn.on_call(
    region="us-central1",
    timeout_sec=30,
    memory=options.MemoryOption.MB_256,
    secrets=[GROQ_API_KEY],
)
def aiAvatarChat(req: https_fn.CallableRequest):
    try:
        if req.auth is None:
            raise https_fn.HttpsError(
                code=https_fn.FunctionsErrorCode.UNAUTHENTICATED,
                message="You must be logged in to use AI chat.",
            )

        body = req.data or {}
        if not isinstance(body, dict):
            raise https_fn.HttpsError(
                code=https_fn.FunctionsErrorCode.INVALID_ARGUMENT,
                message="Request payload must be a JSON object.",
            )
        message = str(body.get("message", "")).strip()
        history = body.get("history", [])
        requested_model = str(body.get("model", DEFAULT_MODEL)).strip() or DEFAULT_MODEL
        patient_query = str(body.get("patientQuery", "")).strip()
        patient_profile = _sanitize_patient_profile(body.get("patientProfile", {}))
        ecg_report_raw = body.get("ecgReport", {})
        ecg_report = ecg_report_raw if isinstance(ecg_report_raw, dict) else {}

        if not message:
            raise https_fn.HttpsError(
                code=https_fn.FunctionsErrorCode.INVALID_ARGUMENT,
                message="message is required.",
            )

        key = GROQ_API_KEY.value
        if not key:
            raise https_fn.HttpsError(
                code=https_fn.FunctionsErrorCode.FAILED_PRECONDITION,
                message="GROQ_API_KEY is not configured.",
            )

        system_instruction = (
            "You are Aegis, a calm AI avatar assistant for ECG app users. "
            "Do not provide diagnosis. Encourage professional care for emergencies. "
            "Keep replies brief and practical."
        )

        messages = [{"role": "system", "content": system_instruction}]
        if isinstance(history, list):
            for item in history[-8:]:
                if not isinstance(item, dict):
                    continue
                role = "assistant" if item.get("role") == "assistant" else "user"
                content = str(item.get("content", "")).strip()
                if content:
                    messages.append({"role": role, "content": content})

        final_query = patient_query or message
        try:
            structured_context = _build_structured_context(
                patient_profile=patient_profile,
                ecg_report=ecg_report,
                patient_query=final_query,
            )
        except Exception as context_error:
            print(f"aiAvatarChat: context build failed: {context_error}")
            structured_context = (
                "Patient profile (structured):\n{}\n\n"
                "ECG report (structured):\n- status: none\n- checkedSamplesCount: 0\n"
                "- checkedSamples(timestamp, heartRate, rrInterval):\nNot available.\n\n"
                "Instruction:\n"
                "- Use patient profile + ECG report + patient query.\n"
                "- Provide remedies and caring guidance that is practical and safe.\n"
                "- If emergency red flags are present, recommend immediate ER/professional care.\n\n"
                "Patient query:\n"
                f"{final_query}"
            )
        merged_message = f"{message}\n\n{structured_context}".strip()
        messages.append({"role": "user", "content": merged_message})

        candidate_models = []
        for name in (requested_model, *MODEL_FALLBACKS):
            if name and name not in candidate_models:
                candidate_models.append(name)

        print(f"aiAvatarChat: trying models={candidate_models}")
        last_status = None
        for model in candidate_models:
            url = "https://api.groq.com/openai/v1/chat/completions"
            try:
                response = requests.post(
                    url,
                    headers={
                        "Authorization": f"Bearer {key}",
                        "Content-Type": "application/json",
                    },
                    json={
                        "model": model,
                        "messages": messages,
                        "temperature": 0.5,
                        "max_tokens": 300,
                    },
                    timeout=25,
                )
            except Exception as error:
                print(f"aiAvatarChat: request exception for model={model}: {error}")
                continue

            if response.status_code < 300:
                try:
                    data = response.json()
                except Exception as error:
                    print(f"aiAvatarChat: invalid json for model={model}: {error}")
                    continue
                reply = ""
                try:
                    content = data["choices"][0]["message"]["content"]
                    if isinstance(content, str):
                        reply = content.strip()
                    else:
                        reply = str(content).strip()
                except (KeyError, IndexError, TypeError):
                    reply = ""
                if reply:
                    return {"reply": reply}
                print(f"aiAvatarChat: empty reply for model={model}")
                continue

            last_status = response.status_code
            print(
                "aiAvatarChat: model request failed "
                f"model={model} status={response.status_code} body={response.text[:500]}"
            )
            if response.status_code == 404:
                continue

        if last_status in (401, 403):
            raise https_fn.HttpsError(
                code=https_fn.FunctionsErrorCode.PERMISSION_DENIED,
                message="Groq API key rejected or missing permissions.",
            )
        if last_status == 429:
            raise https_fn.HttpsError(
                code=https_fn.FunctionsErrorCode.RESOURCE_EXHAUSTED,
                message="Groq quota/rate limit exceeded. Upgrade plan or retry later.",
            )

        raise https_fn.HttpsError(
            code=https_fn.FunctionsErrorCode.INTERNAL,
            message="AI service temporarily unavailable. Please try again.",
        )
    except https_fn.HttpsError:
        raise
    except Exception as error:
        print(f"aiAvatarChat: unhandled error: {error}")
        raise https_fn.HttpsError(
            code=https_fn.FunctionsErrorCode.INTERNAL,
            message="Server error while generating AI response.",
        )
