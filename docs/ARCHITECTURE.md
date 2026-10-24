# Matalogic Architecture

## Goal

Matalogic is a native macOS companion for Logic Pro. Logic remains responsible for recording, editing, plugins, mixing and mastering. Matalogic owns the surrounding workflow: project metadata, lyrics, references, AI-assisted storyboarding, video generation and live playback support.

Matamike is the built-in assistant. He is represented as a skeleton with sombrero and guitar and receives the currently selected song plus the available project list as context. The first implementation is local and deterministic; the `MatamikeProviding` boundary allows a real LLM provider to be added later without changing the chat UI or action system.

## Current UI shell

The app now uses a three-column layout:

- left: navigation and project list
- center: active workspace
- right: persistent Matamike chat

Current workspaces:

- Overview
- Song
- References
- Storyboard
- Render Queue
- Live Mode

## Current workflow

1. Export a Logic exchange folder containing a master audio file, optional stems, Standard MIDI File, optional AAF and optional lyrics.
2. Import the folder into Matalogic.
3. Read the master duration and build a normalized waveform with AVFoundation.
4. Parse Standard MIDI tempo and marker events into the song timeline.
5. Import lyrics from TXT/LRC/SRT; LRC and SRT timing is retained.
6. Add reference images categorized as person, outfit, location or style.
7. Create storyboard shots with start time, duration, prompt and reference IDs.
8. Submit individual shots to a `VideoProvider` implementation.
9. Keep multiple takes per shot and approve one.
10. Track jobs in a persistent Render Queue; Runway task IDs can be resumed after an interrupted app session.
11. Later, assemble all approved shots against the original master and export the final movie.

## Logic import contract

Preferred package layout:

```text
Song Name/
├── Master.wav
├── Song Name.mid
├── Song Name.aaf       # optional enrichment
├── lyrics.lrc          # optional
└── Stems/
    ├── Drums.wav
    ├── Bass.wav
    ├── Guitar.wav
    └── Vocals.wav
```

Supported master/stem formats in the current importer: WAV, AIFF/AIF, M4A and CAF.

MIDI is the primary source for tempo and marker timing. The parser currently supports PPQ-based Standard MIDI files, tempo meta events and marker meta events. SMPTE-timed MIDI is deliberately rejected for now. AAF is optional enrichment for future region/track metadata. The `.logicx` package is intentionally not parsed.

## Lyrics

- TXT: plain lines without timing
- LRC: timestamped lines, including automatic end-time inference from the next line
- SRT: start/end timing retained

## Matamike boundary

Assistant backends return text plus optional structured actions:

```swift
protocol MatamikeProviding: Sendable {
    func reply(
        to message: String,
        project: SongProject?,
        availableProjects: [SongProject]
    ) async -> MatamikeReply
}
```

`LocalMatamikeProvider` currently answers project-aware questions about Logic import, lyrics, tempo/markers, project completeness and the video workflow.

Structured actions currently include quick encores. Example:

```text
Pack Midnight Highway als Zugabe rein
```

If the song title matches an existing project, Matamike emits an `addEncore` action and Live Mode receives the song immediately.

## Video provider boundary

All external renderers implement:

```swift
protocol VideoProvider: Sendable {
    var name: String { get }
    func generate(_ request: VideoGenerationRequest) async throws -> VideoGenerationResult
}
```

This prevents provider-specific API formats from leaking into the domain model.

Current implementations:

- `MockVideoProvider` for free UI/workflow testing
- `RunwayVideoProvider` for real image-to-video generation

The Runway adapter creates `/v1/image_to_video` tasks, stores the returned task ID immediately, then polls the task endpoint. Local reference images are encoded as data URIs. The render queue persists task IDs and attempts to resume interrupted Runway jobs when Matalogic starts again and an API key is available.

## Persistence plan

Current prototype:

- song/project models: in memory
- render queue: persisted in `UserDefaults`
- large media: referenced by file URL

Next persistence step: SwiftData for metadata plus a project package on disk for media copied into Matalogic ownership.

Suggested package:

```text
MySong.matalogic/
├── project.sqlite
├── audio/
├── stems/
├── lyrics/
├── references/
│   ├── people/
│   ├── outfits/
│   └── locations/
├── storyboard/
├── generations/
└── exports/
```

## Milestones

### Milestone 1 — project shell ✅
- Native SwiftUI app
- project list/detail view
- import-folder discovery
- domain model
- mock video provider

### Milestone 2 — real Logic handoff ✅
- AVFoundation duration + waveform
- MIDI tempo and marker parser
- TXT/LRC/SRT lyrics parser
- real file import from the macOS UI
- imported master/stem/marker/lyric status visible in the project dashboard
- parser tests and macOS CI

### Matamike foundation ✅
- built-in assistant UI
- skeleton/sombrero/guitar avatar
- selected-song context
- local helper provider
- structured assistant actions
- quick encore insertion into Live Mode
- provider boundary for a future LLM

### Milestone 3 — visual production ✅
- reference library with image import
- storyboard editor
- shot/take model
- reference assignment per shot
- first real video provider adapter (Runway)
- mock provider for no-cost testing
- persistent render queue with Runway task IDs
- automatic resume of interrupted Runway polling
- full three-column production UI

### Milestone 4 — finishing
- timeline assembly
- master-audio muxing
- export presets
- local download of provider outputs before ephemeral URLs expire
- improved per-shot regeneration and versioning

### Live mode expansion
- backing tracks and stems
- click/count-in routing
- lyrics/teleprompter
- video output
- MIDI/timecode sync
- optional DMX integration
- dynamic setlist operations through Matamike
