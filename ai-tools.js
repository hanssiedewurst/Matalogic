let matalogicWhisperPipeline = null;

function clampNumber(value, min, max) {
  return Math.max(min, Math.min(max, value));
}

function cleanLyricLine(line) {
  return String(line || '')
    .replace(/^\s*\[[^\]]+\]\s*/, '')
    .replace(/^\s*\d+\s*$/, '')
    .trim();
}

function matamikeBuildVideoDraft(project) {
  if (!project) return;

  const duration = Math.max(1, Number(project.duration) || 180);
  const targetCount = clampNumber(Math.round(duration / 5.5), 30, 50);
  const lyrics = String(project.lyrics || '')
    .split(/\r?\n/)
    .map(cleanLyricLine)
    .filter(Boolean);

  const visualModes = [
    'cinematic establishing shot, realistic natural light, restrained camera movement',
    'performance close-up, expressive face, shallow depth of field, realistic skin',
    'handheld medium shot, subtle movement, documentary realism',
    'wide environmental shot, strong composition, atmospheric depth',
    'detail insert shot, hands and objects, tactile realism',
    'slow tracking shot, cinematic lens, motivated practical lighting',
    'silhouette and backlight, controlled haze, realistic contrast',
    'intimate shoulder-level shot, natural movement, emotionally grounded',
    'low-angle performance shot, energetic but believable camera motion',
    'quiet narrative cutaway, realistic location, visual storytelling'
  ];

  project.shots = Array.from({ length: targetCount }, (_, index) => {
    const start = index * duration / targetCount;
    const end = (index + 1) * duration / targetCount;
    const lyric = lyrics.length
      ? lyrics[Math.min(lyrics.length - 1, Math.floor(index * lyrics.length / targetCount))]
      : '';

    let storyBeat;
    if (index === 0) storyBeat = 'opening image that establishes the world and visual tone';
    else if (index === targetCount - 1) storyBeat = 'final resolving image with a memorable visual ending';
    else if (index < targetCount * 0.22) storyBeat = 'introduce character, setting and visual motif';
    else if (index < targetCount * 0.48) storyBeat = 'develop the narrative and alternate with performance coverage';
    else if (index < targetCount * 0.72) storyBeat = 'raise visual intensity and create stronger movement';
    else storyBeat = 'build toward the climax and visual payoff';

    const lyricInstruction = lyric
      ? `Visual interpretation of lyric: “${lyric.slice(0, 140)}”. Do not show written text on screen.`
      : 'Let rhythm and musical dynamics drive the action; no on-screen text.';

    return {
      id: crypto.randomUUID(),
      start,
      duration: end - start,
      prompt: `${visualModes[index % visualModes.length]}. ${storyBeat}. ${lyricInstruction}`,
      status: 'draft',
      referenceIDs: []
    };
  });

  save();
  if (typeof renderStoryboard === 'function') renderStoryboard();
  if (typeof renderOverview === 'function') renderOverview();
  toast(`Matamike hat ${targetCount} Shots als ersten Videoentwurf angelegt`);
  if (typeof chat === 'function') {
    chat(`Ich habe ${targetCount} Shots für „${project.title}“ angelegt. ${lyrics.length ? 'Die Lyrics sind in die Bildideen eingeflossen.' : 'Ohne Lyrics habe ich zunächst nach Songdauer und Dramaturgie geplant.'} 💀🎸`);
  }
}

function formatLrcTime(seconds) {
  seconds = Math.max(0, Number(seconds) || 0);
  const mins = Math.floor(seconds / 60);
  const secs = seconds - mins * 60;
  return `${String(mins).padStart(2, '0')}:${secs.toFixed(2).padStart(5, '0')}`;
}

async function getWhisperPipeline(onProgress) {
  if (matalogicWhisperPipeline) return matalogicWhisperPipeline;

  onProgress?.('Whisper-Modul wird geladen …');
  const { pipeline } = await import('https://cdn.jsdelivr.net/npm/@huggingface/transformers@4.3.1');

  onProgress?.('Spracherkennungsmodell wird geladen …');
  matalogicWhisperPipeline = await pipeline(
    'automatic-speech-recognition',
    'onnx-community/whisper-tiny',
    {
      device: 'wasm',
      dtype: { encoder_model: 'fp32', decoder_model_merged: 'q4' },
      progress_callback: data => {
        if (!data) return;
        if (data.status === 'progress' && Number.isFinite(data.progress)) {
          onProgress?.(`Modell laden: ${Math.round(data.progress)} %`);
        } else if (data.status) {
          onProgress?.(`Modell: ${data.status}`);
        }
      }
    }
  );
  return matalogicWhisperPipeline;
}

async function decodeAudioForWhisper(blob, onProgress) {
  onProgress?.('Audio wird für die Transkription dekodiert …');
  const arrayBuffer = await blob.arrayBuffer();
  const AudioCtx = window.AudioContext || window.webkitAudioContext;
  const ctx = new AudioCtx({ sampleRate: 16000 });
  const decoded = await ctx.decodeAudioData(arrayBuffer.slice(0));
  const length = decoded.length;
  const mixed = new Float32Array(length);
  const channels = Math.max(1, decoded.numberOfChannels);
  for (let ch = 0; ch < channels; ch++) {
    const data = decoded.getChannelData(ch);
    for (let i = 0; i < length; i++) mixed[i] += data[i] / channels;
  }
  await ctx.close();
  return mixed;
}

async function transcribeSongLyrics() {
  const status = document.getElementById('lyricsDetectStatus');
  const setStatus = text => {
    if (status) status.textContent = text;
  };

  let source = state.pendingAudio || null;
  if (!source) {
    const p = current();
    if (p?.audioURL) {
      try {
        source = await fetch(p.audioURL).then(r => r.blob());
      } catch (_) {}
    }
  }

  if (!source) {
    setStatus('Bitte wähle zuerst die Audiodatei des Songs aus.');
    toast('Für die Lyrics-Erkennung zuerst Audio auswählen');
    return;
  }

  const button = document.getElementById('lyricsFromAudio');
  if (button) button.disabled = true;

  try {
    setStatus('Vorbereitung …');
    const audio = await decodeAudioForWhisper(source, setStatus);
    const pipe = await getWhisperPipeline(setStatus);

    setStatus('Gesang wird transkribiert …');
    const result = await pipe(audio, {
      chunk_length_s: 30,
      stride_length_s: 5,
      return_timestamps: true,
      task: 'transcribe'
    });

    let lyrics = '';
    if (Array.isArray(result?.chunks) && result.chunks.length) {
      lyrics = result.chunks
        .map(chunk => {
          const text = String(chunk.text || '').trim();
          if (!text) return '';
          const start = Array.isArray(chunk.timestamp) ? chunk.timestamp[0] : null;
          return Number.isFinite(start) ? `[${formatLrcTime(start)}] ${text}` : text;
        })
        .filter(Boolean)
        .join('\n');
    }
    if (!lyrics) lyrics = String(result?.text || '').trim();

    const textarea = document.getElementById('projLyrics');
    if (textarea) textarea.value = lyrics;
    setStatus(lyrics ? 'Lyrics erkannt. Bitte kurz gegenhören und korrigieren.' : 'Keine verständlichen Lyrics erkannt.');
    toast(lyrics ? 'Lyrics aus dem Song erkannt' : 'Keine Lyrics erkannt');
  } catch (error) {
    console.error(error);
    setStatus(`Transkription fehlgeschlagen: ${error?.message || error}`);
    toast('Lyrics-Erkennung fehlgeschlagen');
  } finally {
    if (button) button.disabled = false;
  }
}

function injectMatamikeTools() {
  const textarea = document.getElementById('projLyrics');
  if (textarea && !document.getElementById('lyricsFromAudio')) {
    const wrap = document.createElement('div');
    wrap.style.marginTop = '10px';
    wrap.innerHTML = `
      <button class="btn" id="lyricsFromAudio" type="button">🎙 Lyrics aus Audio erkennen (Beta)</button>
      <div class="hint" id="lyricsDetectStatus" style="margin-top:8px">Läuft lokal im Browser. Bei Gesang mit lauter Begleitung kann Nachkorrektur nötig sein.</div>
    `;
    textarea.parentElement.appendChild(wrap);
    document.getElementById('lyricsFromAudio').onclick = transcribeSongLyrics;
  }

  const storyView = document.getElementById('view-storyboard');
  if (storyView && !document.getElementById('matamikeDraftBar')) {
    const bar = document.createElement('div');
    bar.id = 'matamikeDraftBar';
    bar.className = 'panel';
    bar.innerHTML = `
      <div class="workspace-head">
        <div><h3>Matamike Video Director</h3><div class="subtle">Erzeugt 30–50 Shots aus Songdauer, Lyrics und Dramaturgie.</div></div>
        <button class="btn primary" id="matamikeVideoDraft">💀🎸 Videoentwurf erzeugen</button>
      </div>`;
    storyView.prepend(bar);
    document.getElementById('matamikeVideoDraft').onclick = () => matamikeBuildVideoDraft(current());
  }

  const chatBox = document.getElementById('chat');
  if (chatBox && !document.getElementById('mikeDraftSuggestion')) {
    const button = document.createElement('button');
    button.className = 'suggestion';
    button.id = 'mikeDraftSuggestion';
    button.textContent = '💀 30–50 Shot Videoentwurf bauen';
    button.onclick = () => {
      matamikeBuildVideoDraft(current());
      showView('storyboard');
    };
    chatBox.appendChild(button);
  }
}

const originalOpenProjectModal = typeof openProjectModal === 'function' ? openProjectModal : null;
if (originalOpenProjectModal) {
  openProjectModal = function(...args) {
    const result = originalOpenProjectModal.apply(this, args);
    setTimeout(injectMatamikeTools, 0);
    return result;
  };
}

const originalRenderStoryboard = typeof renderStoryboard === 'function' ? renderStoryboard : null;
if (originalRenderStoryboard) {
  renderStoryboard = function(...args) {
    const result = originalRenderStoryboard.apply(this, args);
    setTimeout(injectMatamikeTools, 0);
    return result;
  };
}

setTimeout(injectMatamikeTools, 0);
