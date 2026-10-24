# Matalogic

Matalogic is a native macOS companion for Logic Pro focused on song management, lyrics, AI-assisted music-video production and live playback workflows.

Logic remains the DAW. Matalogic handles the workflow around the song.

## Current prototype

- native SwiftUI macOS app with a three-column workspace
- **Universal macOS build: Intel `x86_64` + Apple Silicon `arm64`**
- deployment target macOS 13+
- shared exchange-folder browser for two-Mac workflows
- Logic exchange import from master + exported individual tracks
- automatic Lead/Backing Vocal track detection from Logic track names
- Apple Speech lyrics transcription from a detected vocal track (German/English beta)
- master audio duration + waveform
- MIDI tempo + marker import
- TXT/LRC/SRT lyrics import
- visual-reference library for people, outfits, locations and style
- automatic reference discovery from the exchange folder
- storyboard editor with per-shot prompts and reference assignment
- multiple takes per shot with approval state
- persistent render queue
- real Runway image-to-video adapter plus mock renderer
- **Matamike**, the built-in project assistant 💀🎸
- Live Mode foundation with quick encores

## Supported Macs

The package targets macOS 13 or newer. CI builds one universal `.app` containing both:

- `x86_64` for Intel Macs such as a 2019 iMac
- `arm64` for Apple Silicon Macs

GitHub Actions verifies both architectures with `lipo` and uploads `Matalogic-universal.zip` as a workflow artifact.

## Shared exchange workflow

Both Macs can point Matalogic at the same folder on a NAS/SMB share, iCloud Drive, Dropbox or another shared filesystem. Matalogic stores the selected folder as a security-scoped bookmark and scans its child folders for Logic exports.

Recommended layout:

```text
Matalogic Exchange/
└── My Song/
    ├── Master.wav
    ├── My Song.mid
    ├── My Song.aaf             # optional
    ├── lyrics.lrc              # optional
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

The track folder may also be named `Spuren`, `Stems`, `Audio` or `Audio Files`.

## Logic handoff

A practical Logic Pro workflow is:

1. Export a normal stereo master/bounce into the song folder.
2. Use **File → Export → All Tracks as Audio Files** for the individual tracks and place them in `Tracks/`.
3. Export Standard MIDI when tempo and Logic markers should be transferred.
4. Optionally export the project as AAF for richer track/position metadata later.
5. Put singer/person/outfit/location/style reference images in the `References` folders.

Matalogic does not reverse engineer `.logicx` bundles. The interchange stays explicit and portable.

Supported audio extensions in the importer include WAV, AIF/AIFF, M4A, CAF, MP3 and AAC. For production exchange, WAV or AIFF is preferred.

## Lyrics

Lyrics can come from:

- `.txt` — plain lyric lines
- `.lrc` — timed lyric lines
- `.srt` — timed subtitle/lyric blocks
- a detected Logic vocal track using **Lyrics aus Vocals**

Vocal detection recognizes common track names such as `Lead Vocal`, `Vocals`, `Vox`, `Gesang`, `Backing Vocal`, `BGV` and related variants. The first native transcription implementation uses Apple's Speech framework and groups recognized words into timed lyric lines. German and English are selectable in the UI.

## Reference images

References can be added manually in the References workspace or loaded automatically from the song's shared `References/` directory. Supported categories are:

- Person / singer
- Outfit
- Location
- Style

These references are assigned to storyboard shots and later sent to compatible video providers.

## Matamike

Matamike is Matalogic's assistant: a skeleton with sombrero and guitar. The current local provider can inspect the selected project and help with Logic import, lyrics, tempo/markers, missing assets and the video workflow.

Matamike also supports structured actions. For example:

> Pack Midnight Highway als Zugabe rein

If the song exists in the project list, Matamike adds it directly to Live Mode as an encore.

## Video generation

Milestone 3 includes a Runway provider using image-to-video. Reference images are sent as data URIs and the returned task ID is written to the persistent render queue before polling begins.

Set the API key before launching Matalogic:

```bash
export RUNWAYML_API_SECRET="your-key"
swift run Matalogic
```

Without an API key, use the built-in Mock provider to test the storyboard and queue workflow without spending credits.

## Development

Requirements:

- macOS 13+
- Swift 5.10+

From the repository root:

```bash
swift build
swift test
swift run Matalogic
```

Build the universal app locally with:

```bash
bash scripts/build-universal-app.sh
```

The result is `dist/Matalogic-universal.zip`.

## Roadmap

Milestones 1–3 cover the project shell, Logic handoff and visual-production workflow. The current compatibility/shared-workspace work prepares Matalogic for an Intel iMac + Apple Silicon MacBook setup.

The shared exchange folder currently synchronizes the **source material** (Logic exports, vocal tracks, MIDI/AAF and reference images). The next persistence step is a `.matalogic/project.json` sidecar in each song folder so corrected lyrics, storyboard decisions and Matalogic-only metadata also synchronize between both Macs.

After that: finishing approved video takes against the master audio and expansion of Live Mode into backing tracks, click/count-in, teleprompter, video output and MIDI/timecode sync.

See [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) for the current architecture and milestone plan.
