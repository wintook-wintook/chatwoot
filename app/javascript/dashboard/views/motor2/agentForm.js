// Motor 2.0 — la ficha en la pantalla ↔ lo que guarda la API (Motor2::AgentJson / AgentForm).

export const SKILLS = [
  'data',
  'offers',
  'appointments',
  'tickets',
  'files',
  'handoff',
];

export const emptySkills = () => ({
  data: { on: false, fields: [] },
  offers: { on: false, objection: '', steps: [] },
  appointments: { on: false, kind: 'llamada', location: '', when: '' },
  tickets: { on: false, types: [], priority: '' },
  files: { on: true },
  handoff: { on: true, when: '', user_id: null, team_id: null },
});

export const emptyForm = () => ({
  name: '',
  customer_display_name: '',
  objective: '',
  ai_context: '',
  channel: {
    inboxId: null,
    retryValue: 1,
    retryUnit: 'days',
    attempts: 3,
    whatsappTemplates: [],
    emailSignature: '',
  },
  calendarIds: [],
  duration: 30,
  keywordActions: [],
  fileRules: {},
  motor2: {
    tone: 'tu',
    instructions: '',
    welcome: '',
    never: '',
    business: [],
    sources: [],
    skills: emptySkills(),
  },
});

export const fromAgent = agent => {
  const base = emptyForm();
  const m2 = agent.motor2 || {};
  const skills = emptySkills();
  Object.keys(skills).forEach(key => {
    skills[key] = { ...skills[key], ...((m2.skills || {})[key] || {}) };
  });
  return {
    ...base,
    name: agent.name || '',
    customer_display_name: agent.customer_display_name || '',
    objective: agent.objective || '',
    ai_context: agent.ai_context || '',
    channel: {
      inboxId: agent.inbox_id,
      retryValue: agent.retry_interval_value || 1,
      retryUnit: agent.retry_interval_unit || 'days',
      attempts: agent.attempts || 3,
      whatsappTemplates: agent.whatsapp_templates || [],
      emailSignature: agent.email_signature || '',
    },
    calendarIds: agent.calendar_integration_ids || [],
    duration: agent.calendar_event_duration || 30,
    keywordActions: agent.keyword_actions || [],
    fileRules: agent.file_rules || {},
    motor2: { ...base.motor2, ...m2, skills },
  };
};

export const toPayload = form => ({
  name: form.name.trim(),
  customer_display_name: form.customer_display_name.trim(),
  objective: form.objective.trim(),
  ai_context: form.ai_context,
  inbox_id: form.channel.inboxId,
  retry_interval_value: form.channel.retryValue,
  retry_interval_unit: form.channel.retryUnit,
  attempts: form.channel.attempts,
  whatsapp_templates: form.channel.whatsappTemplates,
  email_signature: form.channel.emailSignature,
  calendar_integration_ids: form.calendarIds,
  calendar_event_duration: form.duration,
  keyword_actions: form.keywordActions,
  file_rules: form.fileRules,
  motor2: form.motor2,
});

// Lo mínimo para guardar (lo mismo que valida el modelo).
export const missingFields = form => {
  const faltan = [];
  if (form.name.trim().length < 2) faltan.push('name');
  if (form.objective.trim().length < 5) faltan.push('objective');
  return faltan;
};
