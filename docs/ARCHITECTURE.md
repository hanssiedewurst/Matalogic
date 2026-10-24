# Matalogic Architecture

## Goal

Matalogic is a native macOS companion for Logic Pro. Logic remains responsible for recording, editing, plugins, mixing and mastering. Matalogic owns the surrounding workflow: project metadata, lyrics, references, AI-assisted storyboarding, video generation and later live playback.

Matamike is the built-in assistant. He is represented as a skeleton with sombrero and guitar and receives the currently selected song as context.

## Platform baseline

- macOS 13+
- one Universal app containing `x86_64` and `arm64`
- tested in CI by building both architectures and verifying the final executable with `lipo`
- intended for an Intel iMac and Apple Silicon MacBook from the same download

## Shared two-Mac workflow

Matalogic can remember one shared exchange root via a security-scoped bookmark. The folder can live on SMB/NAS, iCloud Drive, Dropbox or another filesystem mounted on both Macs.

Each child folder is treated as a song candidate when Matalogic can discover supported audio files in it.

Recommended layout:

```text
Matalogic Exchange/
└── Song Name/
    ├── Master.wav
    ├── Song Name.mid
    ├── Song Name.aaf          # optional
    ├── lyrics.lrc             # optional
    ├── Tracks/
    │   ├── Lead Vocal.wav
    │   ├── Backing Vocal.wav
    │   ├── Drums.wav
    │   ├── Bass.wav
    │   └── Guitar.wav
    └── References/
        ├── People/
        ├── Outfits/
        ├── Locations/
        └── Style/
```

The track folder can also be named `Spuren`, `Stems`, `Audio` or `Audio Files`.

## Logic import contract

Preferred Logic workflow:

1. bounce/export a stereo master
2. export all Logic tracks as individual audio files
3. optionally export Standard MIDI for tempo and markers
4. optionally export AAF for richer track/position metadata
5. place reference images in the shared song folder

The `.logicx` package is intentionally not reverse engineered.

### Track classification

Matalogic classifies common Logic track names into roles:

- lead vocal
- backing vocal
- drums
- bass
- guitar
- keys
- synth
- percussion
- other

Names such as `Lead Vocal`, `Vocals`, `Vox`, `Gesang`, `Backing Vocal`, `BGV`, `Drums`, `Bass`, `Guitar` and German variants are recognized.

The detected lead vocal is the preferred source for automatic lyrics transcription.

## Lyrics

Lyrics can be provided as:

- TXT
- LRC with timing
- SRT with timing
- automatic transcription from a detected vocal track

The first native vocal transcription uses Apple's Speech framework. It supports a German or English recognition mode from the UI and groups recognized word segments into timed `LyricLine` entries. This is a beta path; a future provider can replace it with local Whisper or a cloud transcription service without changing the project model.

## Current workflow

1. Select the shared exchange folder once on each Mac.
2. Export a Logic song into a child folder.
3. Matalogic discovers master, individual tracks, vocal roles, MIDI, AAF, lyrics and reference images.
4. Import the song.
5. If no lyric file exists, transcribe a detected vocal track.
6. Add or review people/outfit/location/style references.
7. Create storyboard shots.
8. Submit shots to Mock or Runway.
9. Review takes and approve one per shot.
10. Add songs to Live Mode or as a Matamike-controlled encore.

## Matamike boundary

All assistant backends implement a provider boundary so a network LLM can replace the local helper without changing the chat/action UI. Structured actions currently include adding a known project to Live Mode as an encore.

## Video provider boundary

External renderers implement `VideoProvider`. Runway is the first real adapter and the Mock provider is retained for free workflow tests. The render queue persists provider task IDs so interrupted Runway jobs can be resumed.

## Persistence direction

The shared Logic source folder is now persistent through the exchange-root bookmark. The next storage step is a small Matalogic sidecar inside each shared song directory so storyboard decisions, lyrics corrections and project metadata synchronize between both Macs as well.

Suggested future sidecar:

```text
Song Name/
└── .matalogic/
    ├── project.json
    ├── generations/
    └── exports/
```

## Milestones

### Milestone 1 — project shell ✅
- Native SwiftUI app
- project list/detail view
- domain model
- mock video provider

### Milestone 2 — real Logic handoff ✅
- AVFoundation duration + waveform
- MIDI tempo and marker parser
- TXT/LRC/SRT lyrics parser
- real file import
- macOS CI

### Matamike foundation ✅
- built-in assistant UI
- skeleton/sombrero/guitar avatar
- selected-song context
- structured encore action

### Milestone 3 — visual production ✅
- reference library
- storyboard editor
- shot/take model
- Runway adapter
- resumable render queue

### Compatibility + collaboration ✅
- macOS 13 baseline
- Universal Intel + Apple Silicon app build
- shared exchange-folder bookmark
- Logic all-tracks discovery
- vocal-track role detection
- automatic reference-folder discovery
- vocal lyrics transcription beta

### Milestone 4 — finishing
- shared `.matalogic` sidecar metadata
- timeline assembly
- master-audio muxing
- export presets
- per-shot regeneration/versioning

### Later — live mode
- backing tracks and stems
- click/count-in routing
- lyrics/teleprompter
- video output
- MIDI/timecode sync
- optional DMX integration
