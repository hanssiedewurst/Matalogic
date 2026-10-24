# Matalogic v0.1 Architecture

## Goal

Matalogic is a native macOS companion for Logic Pro. Logic remains responsible for recording, editing, plugins, mixing and mastering. Matalogic owns the surrounding workflow: project metadata, lyrics, references, AI-assisted storyboarding, video generation and later live playback.

## v0.1 workflow

1. Export a Logic exchange folder containing a master audio file, optional stems, Standard MIDI File, optional AAF and optional lyrics.
2. Import the folder into Matalogic.
3. Read the master duration and waveform.
4. Parse MIDI tempo changes and markers into the song timeline.
5. Import lyrics from TXT/LRC/SRT and align them manually or automatically.
6. Add reference images categorized as person, outfit, location or style.
7. Create storyboard shots with start time, duration, prompt and reference IDs.
8. Submit individual shots to a `VideoProvider` implementation.
9. Keep multiple takes per shot, approve one, then assemble all approved shots against the original master.
10. Export 1080p/4K deliverables plus a movie suitable for reopening alongside the Logic project.

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

MIDI is the primary source for tempo and marker timing. AAF is optional enrichment for region/track metadata. The `.logicx` package is intentionally not parsed in v0.1.

## Video provider boundary

All external renderers implement:

```swift
protocol VideoProvider {
    var name: String { get }
    func generate(_ request: VideoGenerationRequest) async throws -> VideoGenerationResult
}
```

This prevents provider-specific API formats from leaking into the domain model. Initial development uses `MockVideoProvider`; a Runway adapter is the first planned network implementation.

## Persistence plan

Prototype: in-memory models.

Next step: SwiftData for metadata plus a project package on disk for large media files.

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

## Near-term milestones

### Milestone 1 — project shell
- Native SwiftUI app
- project list/detail view
- import-folder discovery
- domain model
- mock video provider

### Milestone 2 — real Logic handoff
- AVFoundation duration + waveform
- MIDI tempo and marker parser
- TXT/LRC/SRT lyrics parser
- import validation report

### Milestone 3 — visual production
- reference library
- storyboard editor
- shot/take model
- first real video provider adapter
- render queue with resumable job state

### Milestone 4 — finishing
- timeline assembly
- master-audio muxing
- export presets
- per-shot regeneration

### Later — live mode
- backing tracks and stems
- click/count-in routing
- lyrics/teleprompter
- video output
- MIDI/timecode sync
- optional DMX integration
