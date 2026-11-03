# Shorts – Gemini + ElevenLabs + OpenArt

Fully automated pipeline that writes a short documentary script, narrates it in Hindi, generates matching video scenes, merges everything with `ffmpeg`, and uploads the result to YouTube as a **private Short**.

**Import file:** [`Shorts-Gemini-11labs-OpenArt.json`](Shorts-Gemini-11labs-OpenArt.json)

---

## What it does

```
Manual Trigger ──► Config ──► Load Topic History ──► Pick Topic (least-used category)
      │
      ▼
Generate Script (Gemini) ──► picks a new topic in that category (avoiding covered ones),
      │                       writes an ~80-word Hindi voiceover script, 3 English scene
      │                       prompts, and a YouTube title/description/tags (with hashtags)
      │
      ├──► ElevenLabs TTS ──► Save Voiceover to Disk (/files/run<id>_voiceover.mp3)
      │
      └──► Split Scenes ──► Loop Scenes (×3, one per scene)
                                │
                                ▼
                     Video Provider? (OpenArt by default, ElevenLabs Flows if selected)
                                │
                     generate ──► poll until rendered ──► download ──► save clip to disk
                                │
                                └──► loop back until all 3 scenes are done
                                          │
                                          ▼
                          Build Concat List ──► Concat Videos ──► Combine Video + Audio
                                          │
                                          ▼
                              Read Final Video ──► Upload to YouTube (Private)
                                          │
                                          ▼
                     Record Topic ──► Cleanup Run Files
```

- **Topic tracking**: every uploaded topic is appended to `/files/topics_covered.jsonl` (host: `n8n_data/files/topics_covered.jsonl`, one JSON line per video with `date`, `category`, `topic`, `youtubeId`). Each run picks the least-used of the 5 categories (Wonders of the World / Universe / Sea / India / Amazing Places), passes the covered topics to Gemini to avoid, and stops before any paid generation if Gemini still returns a covered topic. Delete a line to allow that topic again.
- **Script + voice**: Google Gemini writes the script and metadata; ElevenLabs converts the script to Hindi speech.
- **Video**: 3 scenes × 10s, generated in parallel with the loop via [OpenArt's MCP server](https://mcp.openart.ai/mcp) (default) or ElevenLabs' Flows video API — toggle with the `VIDEO_PROVIDER` input.
- **Merge**: `ffmpeg` concatenates the 3 clips, then merges the result with the voiceover track (`-map` used explicitly so the right audio/video streams are picked).
- **Upload**: uploads as a **private** YouTube Short — region `IN`, category `Education (27)`, and `#Shorts` is always appended to the title so YouTube classifies it correctly (the Data API has no explicit "this is a Short" flag; it infers it from format + that hashtag).
- **Cleanup**: every intermediate file is prefixed with the execution id (`run<id>_voiceover.mp3`, `run<id>_clip_*.mp4`, `run<id>_combined.mp4`, `run<id>_concat.txt`), so a run can never reuse an earlier run's clips. After a successful upload they are deleted; the final `final_output_run<id>.mp4` is kept. A failed run leaves its files in place for inspection.

## Choosing the video provider

Pass `VIDEO_PROVIDER` as input data when starting the Manual Trigger execution:

| Value | Backend | Notes |
|---|---|---|
| *(not provided, default)* | OpenArt (`byte-plus-seedance-2-5`) | 480p, 9:16, no embedded audio |
| `elevenlabs` | ElevenLabs Flows (`bytedance-seedance-v2.5`) | 720p, 9:16 — requires an ElevenLabs plan with Flows/video access (Pro tier or above) |

## Prerequisites

- The repo's Docker image, built from the included [`Dockerfile`](../Dockerfile) — it adds static `ffmpeg`/`ffprobe` binaries on top of the official n8n image, required by the `executeCommand` nodes in this workflow.
- `executeCommand` must be enabled (this repo re-enables it in `docker-compose.yml` — see the root [README's Security section](../README.md#security)).
- `/files` must be writable by n8n and reachable by workflow file nodes (already configured by this repo's `docker-compose.yml`).

## Credentials

This workflow needs **4 credentials**, created in your own n8n instance (**Credentials → Create Credential**). The imported JSON only ever contains a credential's internal `id`/`name` reference — never the underlying secret — so after importing you must create these yourself and re-attach each one to its nodes:

| Credential type | Used by | Get it from |
|---|---|---|
| Google Gemini (PaLM) API | `Generate Script (Gemini)` | [Google AI Studio](https://aistudio.google.com/apikey) |
| ElevenLabs API | `ElevenLabs TTS`, and `Trigger ElevenLabs Video` if using that provider | [ElevenLabs → Profile → API Keys](https://elevenlabs.io/app/settings/api-keys) |
| MCP (OAuth2) | `Trigger OpenArt Video`, `Poll OpenArt Video Status` | Connects to `https://mcp.openart.ai/mcp` — n8n handles the OAuth2 dynamic client registration flow, just click Connect |
| YouTube OAuth2 API | `Upload to YouTube (Private)` | [Google Cloud Console](https://console.cloud.google.com/apis/credentials) — enable the YouTube Data API v3, create an OAuth client, complete the consent flow for the channel you want to upload to (the target channel is whichever one you authorize during that consent screen — there's no separate "channel ID" field on the upload node) |

After importing, open each node showing a credential error and select (or create) the matching credential from the list above.

## Cost

Every run triggers real, billed API usage:

- **OpenArt** (default provider): ~300 credits per 10s clip × 3 clips = ~900 credits/run
- **ElevenLabs**: one TTS call (script length) + optionally 3× Flows video generations if `VIDEO_PROVIDER=elevenlabs` (requires a paid plan tier)
- **Gemini**: one text-generation call (small)
- **YouTube Data API**: counts against your daily upload quota

There is no dry-run mode — running the workflow (via the Manual Trigger, in the editor or `n8n execute --id <id>`) always performs real generation and a real (private) upload.

## Output

- A new **private** YouTube Short on the channel authorized in the YouTube credential, titled with an emoji + `#Shorts`, with an AI-written description and trending hashtags.
- A new line in `topics_covered.jsonl`; intermediate files are removed, `final_output_run<id>.mp4` is kept.
