// proyecto@asistente_agentes_ia — REVISAR UNA CONVERSACIÓN REAL, EN EL CHAT
// ============================================================================
// La persona pega el link de una conversación en el chat del Asistente y este dice
// qué respuestas del agente estuvieron mal (ConversationReview en el backend). El
// resultado se escribe como un mensaje del Asistente: así queda en el hilo y, si
// después se le pide «corrígelo», el editor lo tiene a la vista.
// ============================================================================

// …/app/accounts/2/conversations/173, o «conversación 173».
const CONVERSATION_RE = /\/conversations\/\d+|\bconversaci[oó]n\s*#?\s*\d+\b/i;

export const mentionsConversation = text => CONVERSATION_RE.test(text || '');

const PREFIX = 'TRACKING_ASSISTANT_VIEW.REVIEW_';

const signalText = (signal, t) => {
  if (signal.code === 'voseo') {
    return t(`${PREFIX}SIGNAL_VOSEO_${signal.cause.toUpperCase()}`, {
      words: signal.words.join(', '),
    });
  }
  return t(`${PREFIX}SIGNAL_TAG${signal.already_fixed ? '_FIXED' : ''}`, {
    tags: signal.tags.join(' '),
    route: signal.route,
    expected: signal.expected,
  });
};

const findingText = (finding, t) => {
  const titulo = t(`${PREFIX}FINDING_${finding.verdict.toUpperCase()}`, {
    n: finding.n,
    cause: t(`${PREFIX}CAUSE_${finding.cause.toUpperCase()}`),
  });
  const lineas = [
    finding.already_fixed ? `${titulo} ${t(`${PREFIX}ALREADY_FIXED`)}` : titulo,
    `   ${t(`${PREFIX}SAID`)} «${finding.said}»`,
  ];
  if (finding.what) lineas.push(`   ${t(`${PREFIX}WHAT`)} ${finding.what}`);
  if (finding.expected)
    lineas.push(`   ${t(`${PREFIX}EXPECTED`)} ${finding.expected}`);
  if (finding.fix) lineas.push(`   ${t(`${PREFIX}FIX`)} ${finding.fix}`);
  (finding.signals || []).forEach(signal => {
    lineas.push(`   ⚠ ${signalText(signal, t)}`);
  });
  return lineas.join('\n');
};

const factText = (fact, t) => {
  if (fact.code === 'blocking')
    return t(`${PREFIX}FACT_BLOCKING`, { message: fact.message });
  return t(`${PREFIX}FACT_${fact.code.toUpperCase()}`, { name: fact.name });
};

// El mensaje del Asistente con el resultado de la revisión.
export const reviewMessage = (result, t) => {
  const { conversation, agent } = result;
  const partes = [
    t(`${PREFIX}HEADER${agent?.name ? '' : '_NO_AGENT'}`, {
      id: conversation.display_id,
      count: conversation.reviewed,
      name: agent?.name,
    }),
  ];
  if (conversation.truncated) {
    partes.push(
      t(`${PREFIX}TRUNCATED`, {
        count: conversation.reviewed,
        total: conversation.messages,
      })
    );
  }
  if (result.summary) partes.push(result.summary);
  (result.findings || []).forEach(finding => {
    partes.push(findingText(finding, t));
  });
  if (!(result.findings || []).length) partes.push(t(`${PREFIX}ALL_OK`));
  if ((result.ok || []).length) {
    partes.push(
      t(`${PREFIX}OK`, { list: result.ok.map(n => `#${n}`).join(', ') })
    );
  }
  const hechos = (result.facts || []).filter(f => f.code !== 'calendar_ok');
  if (hechos.length) {
    partes.push(hechos.map(f => `⚠ ${factText(f, t)}`).join('\n'));
  }
  if ((result.training_changes || []).length) {
    partes.push(
      [
        t(`${PREFIX}CHANGES`),
        ...result.training_changes.map(c => `- ${c}`),
      ].join('\n')
    );
  }
  return partes.join('\n\n');
};

// ¿Hay algo que el editor pueda corregir en el Entrenamiento?
export const hasTrainingFixes = result =>
  (result.training_changes || []).length > 0 ||
  (result.findings || []).some(
    f => f.cause === 'entrenamiento' && !f.already_fixed
  );
