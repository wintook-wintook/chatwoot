// Color por agente: el mismo en el panel «Compañeros» y en el calendario.
// fix/calendario_eliminar F4 — cada quien puede escoger fondo y letra de sus compañeros;
// se guarda en sus preferencias del sistema (ui_settings.calendar_coworker_colors):
//   { "<agent_id>": { bg: '#0ea5e9', text: 'auto' | 'white' | 'black' } }
const AGENT_COLORS = [
  '#f43f5e',
  '#fb923c',
  '#a3e635',
  '#22d3ee',
  '#818cf8',
  '#e879f9',
];

export const COWORKER_COLORS_KEY = 'calendar_coworker_colors';
export const TEXT_COLORS = { white: '#ffffff', black: '#1f2937' };

export const coworkerColorsFrom = uiSettings =>
  (uiSettings && uiSettings[COWORKER_COLORS_KEY]) || {};

export const defaultAgentColor = agentId =>
  AGENT_COLORS[(agentId || 0) % AGENT_COLORS.length];

export const agentColor = (agentId, custom = {}) =>
  (custom[agentId] && custom[agentId].bg) || defaultAgentColor(agentId);

// Luminancia relativa WCAG de un hex #rrggbb.
const luminance = hex => {
  const [r, g, b] = [1, 3, 5].map(i => {
    const c = parseInt(hex.slice(i, i + 2), 16) / 255;
    return c <= 0.03928 ? c / 12.92 : ((c + 0.055) / 1.055) ** 2.4;
  });
  return 0.2126 * r + 0.7152 * g + 0.0722 * b;
};

const contrast = (a, b) => {
  const [hi, lo] = [luminance(a), luminance(b)].sort((x, y) => y - x);
  return (hi + 0.05) / (lo + 0.05);
};

// «Automática»: la que más contraste tenga sobre el fondo (blanca u oscura).
export const autoTextColor = bg =>
  contrast(bg, TEXT_COLORS.white) >= contrast(bg, TEXT_COLORS.black)
    ? TEXT_COLORS.white
    : TEXT_COLORS.black;

export const textColorFor = (bg, choice) =>
  TEXT_COLORS[choice] || autoTextColor(bg);

export const agentTextColor = (agentId, custom = {}) =>
  textColorFor(
    agentColor(agentId, custom),
    custom[agentId] && custom[agentId].text
  );
