/* eslint-disable max-classes-per-file */
import { createRingtone, RINGTONES } from '../whatsappCallRingtone';

// Un AudioContext de prueba que cuenta los osciladores que se programan.
/* eslint-disable class-methods-use-this, no-empty-function */
class FakeParam {
  setValueAtTime() {}

  exponentialRampToValueAtTime() {}
}

class FakeContext {
  constructor() {
    this.currentTime = 0;
    this.state = 'running';
    this.destination = {};
    this.osciladores = 0;
    FakeContext.last = this;
  }

  async resume() {}

  async close() {
    this.state = 'closed';
  }

  createOscillator() {
    this.osciladores += 1;
    const nodo = {
      frequency: new FakeParam(),
      connect: destino => destino,
      start() {},
      stop() {},
    };
    return nodo;
  }

  createGain() {
    return { gain: new FakeParam(), connect: destino => destino };
  }
}
/* eslint-enable class-methods-use-this, no-empty-function */

describe('Timbre de las llamadas', () => {
  beforeEach(() => {
    vi.useFakeTimers();
    window.AudioContext = FakeContext;
    window.HTMLMediaElement.prototype.play = vi.fn().mockResolvedValue();
    window.HTMLMediaElement.prototype.pause = vi.fn();
  });

  afterEach(() => {
    vi.useRealTimers();
  });

  it('hay cuatro tonos y la marimba es la primera', () => {
    expect(RINGTONES).toEqual(['marimba', 'classic', 'digital', 'bell']);
  });

  it.each(['marimba', 'classic', 'digital'])(
    '%s se genera en el navegador y se repite hasta detenerlo',
    tono => {
      const timbre = createRingtone(tono);
      timbre.start();
      const primeraVuelta = FakeContext.last.osciladores;
      expect(primeraVuelta).toBeGreaterThan(0);

      vi.advanceTimersByTime(3000);
      expect(FakeContext.last.osciladores).toBeGreaterThan(primeraVuelta);

      const ctx = FakeContext.last;
      timbre.stop();
      expect(ctx.state).toBe('closed');
    }
  );

  it('la vista previa toca una sola vez', () => {
    createRingtone('digital', { veces: 1 }).start();
    const ctx = FakeContext.last;
    const osciladores = ctx.osciladores;
    vi.advanceTimersByTime(5000);
    expect(ctx.osciladores).toBe(osciladores);
    expect(ctx.state).toBe('closed');
  });

  it('la campana usa el archivo de siempre', () => {
    const timbre = createRingtone('bell');
    timbre.start();
    expect(window.HTMLMediaElement.prototype.play).toHaveBeenCalled();
    timbre.stop();
    expect(window.HTMLMediaElement.prototype.pause).toHaveBeenCalled();
  });

  it('un nombre desconocido suena como la marimba', () => {
    createRingtone('no-existe').start();
    expect(FakeContext.last.osciladores).toBeGreaterThan(0);
  });
});
