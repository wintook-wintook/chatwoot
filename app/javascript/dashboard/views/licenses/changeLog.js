// feat/licencias F6.4 — DE UN EVENTO DEL REGISTRO A SU FRASE
// ============================================================================
// El servidor (Licenses::AccountChangeLog) manda { kind, event, params, comment }; aquí se arma
// lo que lee la persona, con las traducciones de LICENSES.CHANGES. `t` es (clave, args) → texto.
// ============================================================================
export const KINDS = [
  'licenses',
  'agents',
  'features',
  'account',
  'inboxes',
  'other',
  'access',
];

export const KIND_ICONS = {
  licenses: 'lock-shield',
  agents: 'people-team',
  features: 'settings',
  account: 'building-bank',
  inboxes: 'mail-inbox',
  other: 'list',
  access: 'person',
};

// channel_whatsapp → whatsapp; case_management → case management
export const featureLabel = name =>
  String(name || '')
    .replace(/^channel_/, '')
    .replace(/_/g, ' ');

const ACCOUNT_FIELDS = [
  'name',
  'status',
  'locale',
  'domain',
  'support_email',
  'limits',
  'custom_attributes',
  'auto_resolve_duration',
];

export const changeText = (evento, t) => {
  const p = evento.params || {};
  const nombre = p.name || '—';
  const campos = (p.fields || [])
    .map(campo =>
      ACCOUNT_FIELDS.includes(campo)
        ? t(`CHANGES.FIELDS.${campo.toUpperCase()}`)
        : campo
    )
    .join(', ');
  const estado = valor => (valor ? t(`STATUS.${valor.toUpperCase()}`) : '—');
  const rol = valor => (valor ? t(`DETAIL.ROLES.${valor.toUpperCase()}`) : '—');
  const ev = clave => `CHANGES.EVENTS.${clave}`;

  switch (evento.event) {
    case 'license_created':
      return t(ev('LICENSE_CREATED'), {
        name: nombre,
        days: p.duration_days,
        agents: p.max_agents,
      });
    case 'license_agents':
      return t(ev('LICENSE_AGENTS'), { name: nombre, from: p.from, to: p.to });
    case 'license_status':
      return t(ev('LICENSE_STATUS'), {
        name: nombre,
        from: estado(p.from),
        to: estado(p.to),
      });
    case 'license_changed':
      return t(ev('LICENSE_CHANGED'), { name: nombre, fields: campos });
    case 'agent_added':
      return t(ev('AGENT_ADDED'), { name: nombre, role: rol(p.role) });
    case 'agent_role':
      return t(ev('AGENT_ROLE'), {
        name: nombre,
        from: rol(p.from),
        to: rol(p.to),
      });
    case 'agent_removed':
      return t(ev('AGENT_REMOVED'), { name: nombre });
    case 'features_changed':
      return [
        (p.on || []).length &&
          t(ev('FEATURES_ON'), { list: p.on.map(featureLabel).join(', ') }),
        (p.off || []).length &&
          t(ev('FEATURES_OFF'), { list: p.off.map(featureLabel).join(', ') }),
      ]
        .filter(Boolean)
        .join(' · ');
    case 'account_status':
      return t(
        ev(p.to === 'suspended' ? 'ACCOUNT_SUSPENDED' : 'ACCOUNT_REACTIVATED')
      );
    case 'account_changed':
      return p.to && (p.fields || []).includes('name')
        ? t(ev('ACCOUNT_RENAMED'), { from: p.from || '—', to: p.to })
        : t(ev('ACCOUNT_CHANGED'), { fields: campos });
    case 'inbox_created':
      return t(ev('INBOX_CREATED'), { name: nombre });
    case 'inbox_deleted':
      return t(ev('INBOX_DELETED'), { name: nombre });
    case 'inbox_changed':
      return t(ev('INBOX_CHANGED'), { name: nombre, fields: campos });
    case 'inbox_member_added':
    case 'inbox_member_removed':
      return t(ev(evento.event.toUpperCase()), {
        name: nombre,
        inbox: p.inbox || '—',
      });
    case 'record_created':
    case 'record_changed':
    case 'record_deleted':
      return t(ev(evento.event.toUpperCase()), {
        type: t(`CHANGES.TYPES.${String(p.type).toUpperCase()}`),
        name: nombre,
      });
    case 'sign_in':
      return t(ev('SIGN_IN'));
    case 'sign_out':
      return t(ev('SIGN_OUT'));
    default:
      return evento.event;
  }
};
