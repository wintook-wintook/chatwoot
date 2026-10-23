// diag/llamadas_whatsapp — EL TIMBRE DE UNA LLAMADA ENTRANTE
// ============================================================================
// Tonos generados en el navegador (Web Audio), sin archivos de audio: son propios,
// no copias de los de WhatsApp ni de ningún teléfono. Se elige por bandeja en la
// pestaña «Llamadas» (provider_config.ringtone).
//   marimba   arpegio de marimba (por omisión)
//   classic   teléfono clásico: «ring-ring» (440 + 480 Hz trinado)
//   digital   tres pitidos
//   bell      la campana de las notificaciones (bell.mp3)
// createRingtone(nombre) → { start, stop }. start repite el patrón hasta stop.
// ============================================================================
export const RINGTONES = ['marimba', 'classic', 'digital', 'bell'];
export const DEFAULT_RINGTONE = 'marimba';

const BELL_URL = '/audio/dashboard/bell.mp3';

// Una nota con ataque rápido y caída (suena a percusión).
const nota = (ctx, destino, { freq, at, dur, tipo = 'sine', vol = 0.3 }) => {
  const osc = ctx.createOscillator();
  const gain = ctx.createGain();
  osc.type = tipo;
  osc.frequency.setValueAtTime(freq, at);
  gain.gain.setValueAtTime(0.0001, at);
  gain.gain.exponentialRampToValueAtTime(vol, at + 0.01);
  gain.gain.exponentialRampToValueAtTime(0.0001, at + dur);
  osc.connect(gain).connect(destino);
  osc.start(at);
  osc.stop(at + dur + 0.05);
};

// Marimba: fundamental + armónico 4× suave, en un arpegio de dos frases.
const marimba = (ctx, destino, t0) => {
  const frases = [
    [659.25, 783.99, 987.77, 783.99],
    [587.33, 739.99, 880.0, 739.99],
  ];
  frases.forEach((frase, i) => {
    frase.forEach((freq, j) => {
      const at = t0 + i * 0.8 + j * 0.16;
      nota(ctx, destino, { freq, at, dur: 0.35, vol: 0.32 });
      nota(ctx, destino, { freq: freq * 4, at, dur: 0.08, vol: 0.05 });
    });
  });
  return 2.6;
};

// Teléfono clásico: dos ráfagas de 440 + 480 Hz trinadas a 20 Hz.
const classic = (ctx, destino, t0) => {
  [0, 0.55].forEach(inicio => {
    const at = t0 + inicio;
    const gain = ctx.createGain();
    const lfo = ctx.createOscillator();
    const lfoGain = ctx.createGain();
    gain.gain.setValueAtTime(0.0001, at);
    gain.gain.exponentialRampToValueAtTime(0.12, at + 0.02);
    gain.gain.setValueAtTime(0.12, at + 0.4);
    gain.gain.exponentialRampToValueAtTime(0.0001, at + 0.45);
    lfo.frequency.value = 20;
    lfoGain.gain.value = 0.06;
    lfo.connect(lfoGain).connect(gain.gain);
    [440, 480].forEach(freq => {
      const osc = ctx.createOscillator();
      osc.frequency.value = freq;
      osc.connect(gain);
      osc.start(at);
      osc.stop(at + 0.5);
    });
    gain.connect(destino);
    lfo.start(at);
    lfo.stop(at + 0.5);
  });
  return 3;
};

const digital = (ctx, destino, t0) => {
  [0, 0.2, 0.4].forEach(inicio => {
    nota(ctx, destino, {
      freq: 1046.5,
      at: t0 + inicio,
      dur: 0.12,
      tipo: 'square',
      vol: 0.08,
    });
  });
  return 1.6;
};

const PATRONES = { marimba, classic, digital };

const createBell = () => {
  let audio = null;
  return {
    start() {
      try {
        audio = new Audio(BELL_URL);
        audio.loop = true;
        const reproduccion = audio.play();
        if (reproduccion && reproduccion.catch) reproduccion.catch(() => {});
      } catch (error) {
        audio = null;
      }
    },
    stop() {
      if (audio) audio.pause();
      audio = null;
    },
  };
};

// veces: cuántas repeticiones (0 = hasta stop). La vista previa usa 1.
export const createRingtone = (nombre, { veces = 0 } = {}) => {
  const patron = PATRONES[nombre] || (nombre === 'bell' ? null : marimba);
  if (!patron) return createBell();

  let ctx = null;
  let timer = null;
  let tocadas = 0;

  const stop = () => {
    clearTimeout(timer);
    timer = null;
    if (ctx && ctx.state !== 'closed') ctx.close().catch(() => {});
    ctx = null;
  };

  const tocar = () => {
    if (!ctx) return;
    const duracion = patron(ctx, ctx.destination, ctx.currentTime + 0.05);
    tocadas += 1;
    if (veces && tocadas >= veces) {
      timer = setTimeout(stop, duracion * 1000);
      return;
    }
    timer = setTimeout(tocar, duracion * 1000);
  };

  return {
    start() {
      try {
        const Contexto = window.AudioContext || window.webkitAudioContext;
        ctx = new Contexto();
        // Puede nacer suspendido por las reglas de autoplay.
        const reanudar = ctx.resume();
        if (reanudar && reanudar.catch) reanudar.catch(() => {});
        tocadas = 0;
        tocar();
      } catch (error) {
        ctx = null;
      }
    },
    stop,
  };
};
