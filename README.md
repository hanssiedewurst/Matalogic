# Matalogic

Matalogic is a native macOS companion for Logic Pro focused on song management, lyrics, AI-assisted music-video production and live playback workflows.

Logic remains the DAW. Matalogic handles the workflow around the song.

## Current prototype

- native SwiftUI macOS app with a three-column workspace
- Logic exchange-folder import
- master audio duration + waveform
- MIDI tempo + marker import
- TXT/LRC/SRT lyrics import
- stem discovery
- visual-reference library for people, outfits, locations and style
- storyboard editor with per-shot prompts and reference assignment
- multiple takes per shot with approval state
- persistent render queue
- real Runway image-to-video adapter plus mock renderer
- **Matamike**, the built-in project assistant 💀🎸
- Live Mode foundation with quick encores

## UI

The current app shell has:

1. navigation and project list on the left
2. the active workspace in the center
3. Matamike permanently available on the right

Workspaces currently include Overview, Song, References, Storyboard, Render Queue and Live Mode.

## Logic handoff

Export a folder from Logic with a structure similar to:

```text
My Song/
├── Master.wav
├── My Song.mid
├── My Song.aaf       # optional
├── lyrics.lrc        # optional
└── Stems/
    ├── Drums.wav
    ├── Bass.wav
    ├── Guitar.wav
    └── Vocals.wav
```

Supported master/stem formats: WAV, AIF/AIFF, M4A and CAF.

Matalogic currently uses Standard MIDI as the primary source for tempo and marker timing. AAF is retained for future metadata enrichment; `.logicx` is deliberately not reverse engineered.

## Lyrics

- `.txt` — plain lyric lines
- `.lrc` — timed lyric lines
- `.srt` — timed subtitle/lyric blocks

## Matamike

Matamike is Matalogic's assistant: a skeleton with sombrero and guitar. The current local provider can inspect the selected project and help with Logic import, lyrics, tempo/markers, missing assets and the video workflow.

Matamike also supports structured actions. For example:

> Pack Midnight Highway als Zugabe rein

If the song exists in the project list, Matamike adds it directly to Live Mode as an encore.

The assistant is isolated behind `MatamikeProviding`, so a network LLM can be connected later without replacing the chat UI or action system.

## Video generation

Milestone 3 includes a real Runway provider using the current image-to-video API. Reference images are sent as data URIs and the returned task ID is written to the persistent render queue before polling begins.

Set the API key before launching Matalogic:

```bash
export RUNWAYML_API_SECRET="your-key"
swift run Matalogic
```

Without an API key, use the built-in Mock provider to test the complete storyboard and queue workflow without spending credits.

## Development

Requirements:

- macOS 14+
- Swift 5.10+

From the repository root:

```bash
swift build
swift test
swift run Matalogic
```

You can also open `Package.swift` directly in Xcode and run the `Matalogic` executable target.

GitHub Actions runs build and tests on macOS for pull requests and feature-branch pushes.

## Roadmap

Milestones 1–3 now cover the project shell, real Logic handoff and visual-production workflow.

Next is finishing: assembling approved takes on the song timeline, muxing the master audio, export presets and per-shot regeneration improvements. Live Mode will then expand into backing tracks, click/count-in, video output, teleprompter and timecode/MIDI sync.

See [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) for the current architecture and milestone plan.
