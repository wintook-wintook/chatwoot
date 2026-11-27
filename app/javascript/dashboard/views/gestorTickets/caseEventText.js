// Plan Actividad del caso — cómo se cuenta un evento de la bitácora del caso
// (etiqueta, resumen del payload, quién lo hizo). Lo comparten el Historial
// (JourneyView) y la Actividad del caso. Salió tal cual de JourneyView.
import { formatDay } from 'dashboard/helper/caseCommercial';
import { formatDueDay } from 'dashboard/helper/taskDue';

export default {
  methods: {
    statusLabel(key) {
      // $t devuelve la ruta cruda si falta la traducción; con $te caemos al valor.
      const k = `CASE_TICKETS.STATUSES.${key}`;
      return this.$te(k) ? this.$t(k) : key;
    },
    // @tickets_cases — etiqueta de prioridad (para eventos priority_changed).
    priorityLabel(key) {
      const k = `CASE_TICKETS.PRIORITIES.${key}`;
      return this.$te(k) ? this.$t(k) : key;
    },
    actorName(event) {
      if (event.actor?.name) return event.actor.name;
      // Tareas con el cliente — lo hizo un contacto en su portal.
      if (event.payload?.contact) return event.payload.contact;
      return event.origin === 'bot'
        ? this.$t('CASE_TICKETS.TIMELINE.ACTOR_BOT')
        : this.$t('CASE_TICKETS.TIMELINE.ACTOR_SYSTEM');
    },
    // @tickets_cases — bitácora: nota interna con contenido (se pinta destacada).
    isNote(event) {
      return (
        event.event_type === 'internal_note' && !!(event.payload || {}).content
      );
    },
    eventLabel(event) {
      const k = `CASE_TICKETS.EVENT_TYPES.${event.event_type}`;
      return this.$te(k) ? this.$t(k) : event.event_type;
    },
    // @tickets_cases F1 — eventos de reunión: folio · título · fecha de la cita
    // (y el alcance cuando la acción fue sobre la serie completa).
    meetingSummary(p) {
      const parts = [p.folio, p.title].filter(Boolean);
      if (p.starts_at) parts.push(this.formatDate(p.starts_at));
      if (p.scope === 'all') {
        parts.push(this.$t('CASE_TICKETS.JOURNEY.MEETING_SCOPE_ALL'));
      }
      return parts.length ? parts.join(' · ') : null;
    },
    payloadSummary(event) {
      const p = event.payload || {};
      if (event.event_type.startsWith('meeting_')) {
        return this.meetingSummary(p);
      }
      // Plan-Clase-Comercial F4 — eventos de oportunidad.
      const commercial = this.commercialSummary(event.event_type, p);
      if (commercial) return commercial;
      // Vencimiento: from/to son fechas.
      // El de una tarea (source: meeting) es solo el día; el del caso lleva hora.
      if (event.event_type === 'due_date_changed') {
        const fmt = p.source === 'meeting' ? formatDueDay : this.formatDate;
        return `${p.from ? fmt(p.from) : '—'} → ${p.to ? fmt(p.to) : '—'}`;
      }
      if (p.from && p.to) {
        // Prioridad usa etiquetas de prioridad; el resto, de estado.
        const label =
          event.event_type === 'priority_changed'
            ? this.priorityLabel
            : this.statusLabel;
        return `${label(p.from)} → ${label(p.to)}`;
      }
      if (p.content) return p.content.slice(0, 80);
      return null;
    },
    // Plan-Clase-Comercial F4 — resultado + motivo + nota; fecha de «retomar el»;
    // y qué datos comerciales cambiaron (monto, moneda, cierre, probabilidad).
    commercialSummary(type, p) {
      const fields = 'CASE_TICKETS.COMMERCIAL.FIELDS';
      if (type === 'outcome_set') {
        return [
          p.outcome && this.$t(`CASE_TICKETS.COMMERCIAL.OUTCOMES.${p.outcome}`),
          p.outcome_reason,
          p.note,
        ]
          .filter(Boolean)
          .join(' · ');
      }
      if (type === 'postponed') {
        // changed: se cambió una pospuesta que ya estaba (fecha, motivo o comentario).
        return [
          p.changed
            ? this.$t('CASE_TICKETS.COMMERCIAL.POSTPONE_CHANGED')
            : null,
          this.$t('CASE_TICKETS.COMMERCIAL.POSTPONED_UNTIL', {
            date: formatDay(p.until),
          }),
          p.reason_label,
          p.reason,
        ]
          .filter(Boolean)
          .join(' · ');
      }
      if (type === 'stage_advanced') {
        return this.$t('CASE_TICKETS.STAGE_ADVANCE.EVENT', {
          from: p.from,
          to: p.to,
        });
      }
      // Plan-Plantilla-Tareas-Etapa — nacieron las tareas de la etapa.
      if (type === 'stage_tasks_added') {
        return this.$t('CASE_TICKETS.TASKS.STAGE.EVENT', {
          count: p.count,
          stage: p.stage,
          titles: (p.titles || []).join(', '),
        });
      }
      // Se ligó (o se creó) la conversación del caso.
      // Plan Actividad del caso — tareas y cotizaciones dejan huella.
      // Tareas con el cliente — qué hizo en el portal y su comentario o archivo.
      if (type === 'task_client_update') {
        const folio = p.sequence
          ? `T${String(p.sequence).padStart(3, '0')}`
          : null;
        return [
          [folio, p.title].filter(Boolean).join(' · '),
          this.$t(`CLIENT_TASKS.KINDS.${p.kind}`),
          p.content || p.file,
        ]
          .filter(Boolean)
          .join(' — ');
      }
      // El caso interno se ligó a un cliente.
      if (type === 'client_assigned') {
        return this.$t('CASE_TICKETS.ASSIGN_CLIENT.EVENT', {
          client: [p.organization, p.contact].filter(Boolean).join(' · '),
        });
      }
      // Tarea ↔ tarea agendada: a qué pasó y para cuándo.
      if (type === 'task_converted') {
        const folio =
          p.folio ||
          (p.sequence ? `T${String(p.sequence).padStart(3, '0')}` : null);
        const when = p.starts_at ? this.formatDate(p.starts_at) : '';
        return [
          [folio, p.title].filter(Boolean).join(' · '),
          this.$t(`CASE_TICKETS.JOURNEY.CONVERTED.${p.direction}`, { when }),
        ]
          .filter(Boolean)
          .join(' — ');
      }
      // Reporte (cierre, avance o actividad): lo que se hizo.
      if (type === 'task_reported') return p.content || p.title || null;
      if (type.startsWith('task_')) {
        const folio = p.sequence
          ? `T${String(p.sequence).padStart(3, '0')}`
          : null;
        return [folio, p.title].filter(Boolean).join(' · ') || null;
      }
      // Asistente (Dali) D3 — seguimiento delegado a un agente IA.
      if (type === 'tracking_triggered' && p.agent) {
        return [p.agent, p.objective].filter(Boolean).join(' · ');
      }
      if (type === 'quote_created') return p.folio || null;
      if (type === 'quote_status_changed') {
        return [
          p.folio,
          `${this.$t(`QUOTES.STATUSES.${p.from}`)} → ${this.$t(
            `QUOTES.STATUSES.${p.to}`
          )}`,
        ].join(' · ');
      }
      if (type === 'conversation_unlinked') {
        return this.$t('CASE_TICKETS.CONVERSATION_ACTIONS.EVENT', {
          id: p.display_id,
          inbox: p.inbox_name || '—',
        });
      }
      if (type === 'conversation_link') {
        let key = p.created ? 'EVENT_CREATED' : 'EVENT';
        if (p.extra) key = 'EVENT_EXTRA';
        return this.$t(`CASE_TICKETS.CONVERSATION_ACTIONS.${key}`, {
          id: p.display_id,
          inbox: p.inbox_name || '—',
        });
      }
      // Plan-Metricas-Comercial — compromiso del cliente: se marcó, se movió la
      // fecha, se quitó o cambió la nota.
      if (type === 'commitment_changed') {
        const c = 'CASE_TICKETS.COMMERCIAL.COMMITMENT.EVENTS';
        const text = this.$t(`${c}.${p.action}`, {
          on: formatDay(p.on),
          from: formatDay(p.from),
          to: formatDay(p.to),
        });
        return [text, p.note].filter(Boolean).join(' · ');
      }
      if (type === 'amount_changed') {
        const labels = {
          amount: `${fields}.AMOUNT`,
          currency: `${fields}.CURRENCY`,
          expected_close_at: `${fields}.EXPECTED_CLOSE`,
          probability: `${fields}.PROBABILITY`,
        };
        return Object.keys(labels)
          .filter(k => p[k])
          .map(
            k =>
              `${this.$t(labels[k])}: ${p[k].from ?? '—'} → ${p[k].to ?? '—'}`
          )
          .join(' · ');
      }
      if (p.previous_outcome) {
        return `${this.$t('CASE_TICKETS.COMMERCIAL.FIELDS.OUTCOME')}: ${this.$t(
          `CASE_TICKETS.COMMERCIAL.OUTCOMES.${p.previous_outcome}`
        )}${p.reason ? ` · ${p.reason}` : ''}`;
      }
      return null;
    },
    formatDate(d) {
      if (!d) return '';
      return new Date(d).toLocaleString(undefined, {
        day: '2-digit',
        month: '2-digit',
        year: 'numeric',
        hour: '2-digit',
        minute: '2-digit',
      });
    },
  },
};
