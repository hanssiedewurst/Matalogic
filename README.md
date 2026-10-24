# Matalogic

Matalogic is a macOS companion app for Logic Pro that connects music production, lyrics, visual references, AI video generation, and later live playback workflows.

## Product direction

Logic Pro remains the DAW. Matalogic manages the surrounding workflow:

1. Import a Logic exchange package (master/stems, MIDI tempo + markers, optional AAF metadata).
2. Import and align lyrics.
3. Manage reference photos for people, outfits, and locations.
4. Build an AI-assisted storyboard and shot list.
5. Send shots to pluggable video-generation providers.
6. Assemble approved takes against the original song.
7. Export a finished music video and a Logic-compatible movie file.

## Status

Early prototype / architecture phase.

The first implementation target is a native macOS app using Swift and SwiftUI. Audio and timeline functionality will use Apple media frameworks where practical, while video-generation services are isolated behind a provider protocol so models can be swapped without redesigning the app.
