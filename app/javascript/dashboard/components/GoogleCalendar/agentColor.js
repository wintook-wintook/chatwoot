// Color fijo por agente: el mismo en el panel «Compañeros» y en el calendario.
const AGENT_COLORS = [
  '#f43f5e',
  '#fb923c',
  '#a3e635',
  '#22d3ee',
  '#818cf8',
  '#e879f9',
];

export const agentColor = agentId =>
  AGENT_COLORS[(agentId || 0) % AGENT_COLORS.length];
