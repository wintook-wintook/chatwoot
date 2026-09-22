/*
 * Generador de los temas de color del dashboard.
 *
 * Cada tema redefine las escalas `woot` (acento) y `slate` (neutros), que
 * tailwind.config.js expone como variables CSS. La salida de `css` se pega
 * en app/javascript/dashboard/assets/scss/_woot.scss, dentro de @layer base.
 *
 *   node theme/tints.js contraste            mide el contraste WCAG
 *   node theme/tints.js css sepia            imprime el bloque de un tema
 *   node theme/tints.js swatches             muestras para la pantalla de Perfil
 *
 * Un tema sirve para modo claro y oscuro a la vez, porque el marcado usa la
 * misma rampa con variantes `dark:`. Por eso, antes de cambiar un tema, hay
 * que correr `contraste` y comparar contra `default`: ningún par debería
 * quedar por debajo de lo que ya da el tema por omisión.
 */
/* eslint-disable no-console */
const radix = require('@radix-ui/colors');

const hslToRgb = (h, s, l) => {
  const f = n => {
    const k = (n + h * 12) % 12;
    const a = s * Math.min(l, 1 - l);
    return Math.round(255 * (l - a * Math.max(-1, Math.min(k - 3, 9 - k, 1))));
  };
  return [f(0), f(8), f(4)];
};

const parse = value => {
  const m = value
    .trim()
    .match(/^hsl\(\s*([\d.]+),\s*([\d.]+)%,\s*([\d.]+)%\s*\)$/i);
  return hslToRgb(+m[1] / 360, +m[2] / 100, +m[3] / 100);
};

const relLum = ([r, g, b]) => {
  const f = c => {
    const v = c / 255;
    return v <= 0.03928 ? v / 12.92 : ((v + 0.055) / 1.055) ** 2.4;
  };
  return 0.2126 * f(r) + 0.7152 * f(g) + 0.0722 * f(b);
};

const ratio = (a, b) => {
  const [hi, lo] = [relLum(a), relLum(b)].sort((x, y) => y - x);
  return (hi + 0.05) / (lo + 0.05);
};

// Pasos de Radix que usaba cada escala antes de volverse variable.
const ACCENT = {
  25: ['', 2],
  50: ['', 3],
  75: ['', 4],
  100: ['', 5],
  200: ['', 7],
  300: ['', 8],
  400: ['D', 11],
  500: ['D', 10],
  600: ['D', 9],
  700: ['D', 8],
  800: ['D', 6],
  900: ['D', 2],
};
const NEUTRAL = {
  25: ['', 2],
  50: ['', 3],
  75: ['', 4],
  100: ['', 5],
  200: ['', 7],
  300: ['', 8],
  400: ['D', 11],
  500: ['D', 10],
  600: ['', 11],
  700: ['D', 8],
  800: ['D', 4],
  900: ['D', 1],
};

// Alto contraste: cada tono conserva su papel, pero los pasos se separan.
// Dos no se pueden empujar porque hacen doble papel en el marcado:
//   300: texto en modo oscuro (268 usos) y borde en claro -> se queda claro.
//   500: texto en claro (302 usos) y en oscuro (200) -> gris medio exacto,
//        el que maximiza el peor de los dos contrastes (4.58 contra blanco
//        y contra negro por igual).
const GRIS_BIMODAL = [117, 117, 117];
const HC_NEUTRAL = {
  25: [255, 255, 255],
  50: [255, 255, 255],
  75: ['', 2],
  100: ['', 3],
  200: ['', 7],
  300: ['', 8],
  400: ['D', 12],
  500: GRIS_BIMODAL,
  600: ['', 12],
  700: ['D', 6],
  800: ['D', 2],
  900: [0, 0, 0],
};
const HC_ACCENT = {
  25: ['', 1],
  50: ['', 2],
  75: ['', 3],
  100: ['', 4],
  200: ['', 8],
  300: ['', 9],
  400: ['D', 12],
  500: ['', 11],
  600: ['', 11],
  700: ['', 12],
  800: ['D', 4],
  900: ['D', 1],
};

// Sepia: los pasos vivos de una escala cálida son demasiado claros para
// texto blanco encima, así que el acento sale de los pasos oscuros.
const SEPIA_ACCENT = {
  25: ['', 1],
  50: ['', 2],
  75: ['', 3],
  100: ['', 4],
  200: ['', 7],
  300: ['', 8],
  400: ['D', 11],
  500: ['', 11],
  600: ['', 11],
  700: ['', 12],
  800: ['D', 4],
  900: ['D', 1],
};

// Gira el tono hacia el ámbar y devuelve el color a la luminancia que tenía,
// para que el contraste de la rampa `sand` se conserve intacto. Cerca del
// blanco la saturación HSL casi no pinta (el matiz se multiplica por
// min(l, 1-l)), así que se compensa para que el papel se vea crema.
const SEPIA_TONO = 34 / 360;
const sepiaTint = rgb => {
  const [r, g, b] = rgb.map(v => v / 255);
  const l0 = (Math.max(r, g, b) + Math.min(r, g, b)) / 2;
  const s = Math.min(0.9, Math.max(0.018 / Math.min(l0, 1 - l0), 0.2));
  const objetivo = relLum(rgb);
  let lo = 0;
  let hi = 1;
  let out = rgb;
  for (let i = 0; i < 40; i += 1) {
    const mid = (lo + hi) / 2;
    out = hslToRgb(SEPIA_TONO, s, mid);
    if (relLum(out) < objetivo) lo = mid;
    else hi = mid;
  }
  return out;
};

const TEMAS = {
  default: { accent: ['blue', ACCENT], neutral: ['slate', NEUTRAL] },
  calido: { accent: ['orange', ACCENT], neutral: ['sand', NEUTRAL] },
  bosque: { accent: ['grass', ACCENT], neutral: ['sage', NEUTRAL] },
  indigo: { accent: ['indigo', ACCENT], neutral: ['mauve', NEUTRAL] },
  sepia: {
    accent: ['bronze', SEPIA_ACCENT],
    neutral: ['sand', NEUTRAL],
    tint: sepiaTint,
  },
  contraste: { accent: ['blue', HC_ACCENT], neutral: ['gray', HC_NEUTRAL] },
};

const KEYS = [25, 50, 75, 100, 200, 300, 400, 500, 600, 700, 800, 900];

const ramp = (base, steps) =>
  Object.fromEntries(
    Object.entries(steps).map(([key, step]) => {
      if (typeof step[0] === 'number') return [key, step];
      const scale = step[0] === 'D' ? `${base}Dark` : base;
      return [key, parse(radix[scale][base + step[1]])];
    })
  );

const build = name => {
  const tema = TEMAS[name];
  const slate = ramp(tema.neutral[0], tema.neutral[1]);
  if (tema.tint)
    KEYS.forEach(k => {
      slate[k] = tema.tint(slate[k]);
    });
  return { woot: ramp(tema.accent[0], tema.accent[1]), slate };
};

// Los pares que más aparecen en el marcado del dashboard.
const PARES = [
  ['claro  texto slate-500 / fondo slate-25', 'slate', 500, 'slate', 25],
  ['claro  texto slate-600 / fondo slate-25', 'slate', 600, 'slate', 25],
  ['claro  texto slate-700 / fondo slate-50', 'slate', 700, 'slate', 50],
  ['claro  texto slate-800 / fondo slate-50', 'slate', 800, 'slate', 50],
  ['oscuro texto slate-400 / fondo slate-800', 'slate', 400, 'slate', 800],
  ['oscuro texto slate-200 / fondo slate-800', 'slate', 200, 'slate', 800],
  ['oscuro texto slate-100 / fondo slate-900', 'slate', 100, 'slate', 900],
  ['oscuro texto slate-300 / fondo slate-700', 'slate', 300, 'slate', 700],
];

const nivel = v => {
  if (v >= 7) return 'AAA';
  if (v >= 4.5) return 'AA';
  if (v >= 3) return 'AA-grande';
  return 'BAJO';
};

const hex = v =>
  `#${v
    .map(x => x.toString(16).padStart(2, '0'))
    .join('')
    .toUpperCase()}`;

const [accion, ...args] = process.argv.slice(2);

if (accion === 'contraste') {
  Object.keys(TEMAS).forEach(name => {
    const c = build(name);
    console.log(`\n== ${name} ==`);
    PARES.forEach(([label, s1, k1, s2, k2]) => {
      const v = ratio(c[s1][k1], c[s2][k2]);
      console.log(
        `  ${label.padEnd(42)} ${v.toFixed(2).padStart(6)}  ${nivel(v)}`
      );
    });
    [500, 600].forEach(k => {
      const v = ratio([255, 255, 255], c.woot[k]);
      console.log(
        `  ${`acento blanco / fondo woot-${k}`.padEnd(42)} ${v
          .toFixed(2)
          .padStart(6)}  ${nivel(v)}`
      );
    });
  });
} else if (accion === 'css') {
  (args.length ? args : Object.keys(TEMAS)).forEach(name => {
    const c = build(name);
    console.log(`  body[data-tema='${name}'] {`);
    KEYS.forEach(k =>
      console.log(`    --color-woot-${k}: ${c.woot[k].join(' ')};`)
    );
    console.log('');
    KEYS.forEach(k =>
      console.log(`    --color-slate-${k}: ${c.slate[k].join(' ')};`)
    );
    console.log('  }\n');
  });
} else if (accion === 'swatches') {
  Object.keys(TEMAS).forEach(name => {
    const c = build(name);
    console.log(
      `  ${name}: ['${hex(c.woot[600])}', '${hex(c.woot[300])}', '${hex(
        c.slate[100]
      )}', '${hex(c.slate[800])}'],`
    );
  });
} else {
  console.log('uso: node theme/tints.js [contraste|css [tema...]|swatches]');
}
