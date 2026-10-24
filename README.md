# Matalogic

Matalogic is a native macOS companion for Logic Pro focused on song management, lyrics, AI-assisted music-video production and later live playback.

Logic remains the DAW. Matalogic handles the workflow around the song.

## Current prototype

- native SwiftUI macOS app
- Logic exchange-folder import
- master audio duration + waveform
- MIDI tempo + marker import
- TXT/LRC/SRT lyrics import
- stem discovery
- provider-agnostic video-generation interface
- **Matamike**, the built-in project assistant 💀🎸

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

The assistant is isolated behind `MatamikeProviding`, so a network LLM can be connected later without replacing the chat UI.

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

GitHub Actions runs build and parser tests on macOS for pull requests and feature-branch pushes.

## Roadmap

The next development milestone is visual production: reference-image management, storyboard editing, shot/take tracking, a real video provider and a resumable render queue.

See [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) for the current architecture and milestone plan.
