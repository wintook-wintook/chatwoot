<!--
  @tickets_cases 2L
  Visualización del avance del ticket con 3 vistas conmutables (preferencia por
  usuario en localStorage). Las tres leen los mismos case_events (from/to del
  payload, actor, reason, timestamp) → sin backend nuevo.
    - diagram  → Diagrama de recorrido (default): espina vertical del camino real.
    - timeline → Historial cronológico clásico.
    - stepper  → Ciclo de vida horizontal compacto.
-->
<script>
const STORAGE_KEY = 'gestorTickets.journeyView';

// Estados del ciclo de vida principal, en orden (espina del recorrido / stepper).
const LIFECYCLE = [
  'open',
  'classified',
  'assigned',
  'in_diagnosis',
  'in_progress',
  'resolved',
  'validating',
  'closed',
];
// Estados fuera de la espina → se dibujan como ramas laterales.
const OFF_LIFECYCLE = [
  'waiting_on_customer',
  'waiting_on_third_party',
  'waiting_on_internal',
  'escalated',
];

const STATUS_DOT = {
  open: 'bg-blue-500',
  classified: 'bg-indigo-500',
  assigned: 'bg-cyan-500',
  in_diagnosis: 'bg-teal-500',
  in_progress: 'bg-sky-500',
  waiting_on_customer: 'bg-amber-500',
  waiting_on_third_party: 'bg-amber-500',
  waiting_on_internal: 'bg-amber-500',
  escalated: 'bg-red-500',
  resolved: 'bg-green-500',
  validating: 'bg-lime-500',
  closed: 'bg-slate-500',
  cancelled: 'bg-slate-400',
};

export default {
  name: 'JourneyView',
  props: {
    events: { type: Array, default: () => [] },
    ticket: { type: Object, default: null },
    isFetching: { type: Boolean, default: false },
  },
  data() {
    return {
      view: localStorage.getItem(STORAGE_KEY) || 'diagram',
      views: ['diagram', 'timeline', 'stepper'],
      viewIcons: {
        diagram: 'navigation',
        timeline: 'document-list-clock',
        stepper: 'arrow-trending-lines',
      },
    };
  },
  computed: {
    // Transiciones reales de ESTADO del ticket (eventos con from/to en el payload
    // cuyo destino es un estado válido). Excluye cambios de sla_status (at_risk/
    // overdue) que también guardan from/to pero no son estados del ticket.
    transitions() {
      return [...this.events]
        .filter(
          e =>
            e.payload &&
            e.payload.from &&
            e.payload.to &&
            STATUS_DOT[e.payload.to] !== undefined
        )
        .sort((a, b) => new Date(a.created_at) - new Date(b.created_at))
        .map(e => ({
          to: e.payload.to,
          from: e.payload.from,
          reason: e.payload.reason || '',
          actor: this.actorName(e),
          at: e.created_at,
          eventType: e.event_type,
        }));
    },
    // Nodos del recorrido: creación (open) + cada destino de transición.
    journeyNodes() {
      if (!this.ticket) return [];
      const nodes = [
        {
          state: 'open',
          reason: '',
          actor: '',
          at: this.ticket.created_at,
          isStart: true,
          branch: false,
        },
      ];
      this.transitions.forEach(t => {
        nodes.push({
          state: t.to,
          reason: t.reason,
          actor: t.actor,
          at: t.at,
          branch: OFF_LIFECYCLE.includes(t.to),
        });
      });
      // Marca el último nodo cuyo estado coincide con el estado actual.
      for (let i = nodes.length - 1; i >= 0; i -= 1) {
        if (nodes[i].state === this.ticket.status) {
          nodes[i].current = true;
          break;
        }
      }
      return nodes;
    },
    // Pasos del ciclo de vida para el stepper.
    lifecycleSteps() {
      const visited = new Set(['open', ...this.transitions.map(t => t.to)]);
      const reachedAt = {};
      this.transitions.forEach(t => {
        reachedAt[t.to] = { at: t.at, actor: t.actor };
      });
      return LIFECYCLE.map(state => ({
        state,
        visited: visited.has(state),
        current: this.ticket && state === this.ticket.status,
        meta: reachedAt[state] || null,
      }));
    },
    // Estado actual fuera del ciclo de vida (espera / escalado / cancelado).
    offLifecycleStatus() {
      const s = this.ticket?.status;
      if (!s || LIFECYCLE.includes(s)) return null;
      return s;
    },
    hasJourney() {
      return this.journeyNodes.length > 0;
    },
  },
  methods: {
    setView(v) {
      this.view = v;
      localStorage.setItem(STORAGE_KEY, v);
    },
    statusLabel(key) {
      return this.$t(`CASE_TICKETS.STATUSES.${key}`) || key;
    },
    quotedReason(reason) {
      return `«${reason}»`;
    },
    statusDot(state) {
      return STATUS_DOT[state] || 'bg-slate-300 dark:bg-slate-600';
    },
    actorName(event) {
      if (event.actor?.name) return event.actor.name;
      return event.origin === 'bot'
        ? this.$t('CASE_TICKETS.TIMELINE.ACTOR_BOT')
        : this.$t('CASE_TICKETS.TIMELINE.ACTOR_SYSTEM');
    },
    eventLabel(event) {
      return (
        this.$t(`CASE_TICKETS.EVENT_TYPES.${event.event_type}`) ||
        event.event_type
      );
    },
    payloadSummary(event) {
      const p = event.payload || {};
      if (p.from && p.to) {
        return `${this.statusLabel(p.from)} → ${this.statusLabel(p.to)}`;
      }
      if (p.content) return p.content.slice(0, 80);
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
    stepTooltip(step) {
      const label = this.statusLabel(step.state);
      if (!step.meta) return label;
      return `${label} · ${this.formatDate(step.meta.at)} · ${step.meta.actor}`;
    },
  },
};
</script>

<template>
  <div
    class="p-4 bg-white border rounded-lg dark:bg-slate-800 border-slate-75 dark:border-slate-700"
  >
    <!-- Cabecera: título + selector de vista -->
    <div class="flex flex-wrap items-center justify-between gap-2 mb-4">
      <h3 class="text-base font-semibold text-slate-800 dark:text-slate-100">
        {{ $t('CASE_TICKETS.JOURNEY.TITLE') }}
      </h3>
      <div
        class="flex p-0.5 rounded-lg bg-slate-50 dark:bg-slate-700/50 gap-0.5"
      >
        <button
          v-for="v in views"
          :key="v"
          type="button"
          class="flex items-center gap-1.5 px-2.5 py-1 text-xs font-medium rounded-md transition-colors"
          :class="
            view === v
              ? 'bg-white dark:bg-slate-800 text-woot-600 dark:text-woot-300 shadow-sm'
              : 'text-slate-500 dark:text-slate-400 hover:text-slate-700 dark:hover:text-slate-200'
          "
          @click="setView(v)"
        >
          <fluent-icon :icon="viewIcons[v]" size="14" />
          {{ $t(`CASE_TICKETS.JOURNEY.VIEWS.${v}`) }}
        </button>
      </div>
    </div>

    <!-- Estados de carga / vacío -->
    <div v-if="isFetching" class="text-sm text-slate-400 dark:text-slate-500">
      {{ $t('CASE_TICKETS.JOURNEY.LOADING') }}
    </div>
    <div
      v-else-if="!hasJourney"
      class="text-sm text-slate-400 dark:text-slate-500"
    >
      {{ $t('CASE_TICKETS.TIMELINE.EMPTY') }}
    </div>

    <template v-else>
      <!-- ── Vista 1: Diagrama de recorrido ─────────────────────── -->
      <div v-if="view === 'diagram'" class="flex flex-col">
        <div
          v-for="(node, idx) in journeyNodes"
          :key="idx"
          class="relative flex gap-3"
          :class="node.branch ? 'pl-6' : ''"
        >
          <!-- Conector vertical -->
          <div class="relative flex flex-col items-center">
            <span
              class="z-10 flex-shrink-0 w-3 h-3 rounded-full ring-2 ring-white dark:ring-slate-800"
              :class="[
                statusDot(node.state),
                node.current
                  ? 'ring-woot-400 dark:ring-woot-500 scale-125'
                  : '',
              ]"
            />
            <span
              v-if="idx < journeyNodes.length - 1"
              class="w-px flex-1 my-0.5"
              :class="
                node.branch
                  ? 'border-l border-dashed border-slate-300 dark:border-slate-600'
                  : 'bg-slate-200 dark:bg-slate-600'
              "
            />
          </div>
          <!-- Contenido del nodo -->
          <div class="flex-1 min-w-0 pb-4">
            <div class="flex items-center gap-2">
              <span
                class="text-sm font-semibold text-slate-700 dark:text-slate-100"
                >{{ statusLabel(node.state) }}</span
              >
              <span
                v-if="node.current"
                class="px-1.5 py-0.5 text-[10px] font-medium rounded-full bg-woot-100 text-woot-700 dark:bg-woot-800 dark:text-woot-100"
                >{{ $t('CASE_TICKETS.JOURNEY.CURRENT') }}</span
              >
            </div>
            <p
              v-if="node.reason"
              class="m-0 mt-0.5 text-sm italic text-slate-500 dark:text-slate-400"
            >
              {{ quotedReason(node.reason) }}
            </p>
            <p
              v-if="!node.isStart"
              class="m-0 mt-0.5 text-xs text-slate-400 dark:text-slate-500"
            >
              {{ node.actor }} · {{ formatDate(node.at) }}
            </p>
            <p
              v-else
              class="m-0 mt-0.5 text-xs text-slate-400 dark:text-slate-500"
            >
              {{ $t('CASE_TICKETS.JOURNEY.CREATED') }} ·
              {{ formatDate(node.at) }}
            </p>
          </div>
        </div>
      </div>

      <!-- ── Vista 2: Historial cronológico ─────────────────────── -->
      <ul
        v-else-if="view === 'timeline'"
        class="flex flex-col gap-4 p-0 m-0 list-none"
      >
        <li
          v-for="event in events"
          :key="event.id"
          class="flex items-start gap-4"
        >
          <div
            class="flex-shrink-0 w-2.5 h-2.5 mt-1 rounded-full"
            :class="
              statusDot(
                event.payload && event.payload.to
                  ? event.payload.to
                  : event.event_type
              )
            "
          />
          <div class="flex-1 min-w-0">
            <p
              class="m-0 text-sm font-medium text-slate-700 dark:text-slate-200"
            >
              {{ eventLabel(event) }}
            </p>
            <p
              v-if="payloadSummary(event)"
              class="mt-0.5 m-0 text-sm text-slate-500 dark:text-slate-400"
            >
              {{ payloadSummary(event) }}
            </p>
            <p class="mt-0.5 m-0 text-xs text-slate-400 dark:text-slate-500">
              {{ actorName(event) }} · {{ formatDate(event.created_at) }}
            </p>
          </div>
        </li>
      </ul>

      <!-- ── Vista 3: Stepper de ciclo de vida ──────────────────── -->
      <div v-else class="flex flex-col gap-3">
        <div class="flex items-start">
          <template v-for="(step, idx) in lifecycleSteps">
            <div
              :key="`step-${step.state}`"
              class="flex flex-col items-center flex-1 min-w-0"
              :title="stepTooltip(step)"
            >
              <span
                class="flex items-center justify-center flex-shrink-0 w-4 h-4 rounded-full ring-2 ring-white dark:ring-slate-800"
                :class="[
                  step.visited
                    ? statusDot(step.state)
                    : 'bg-slate-200 dark:bg-slate-600',
                  step.current
                    ? 'ring-woot-400 dark:ring-woot-500 scale-125'
                    : '',
                ]"
              />
              <span
                class="mt-1.5 text-[10px] leading-tight text-center"
                :class="
                  step.visited
                    ? 'text-slate-600 dark:text-slate-300 font-medium'
                    : 'text-slate-400 dark:text-slate-500'
                "
                >{{ statusLabel(step.state) }}</span
              >
            </div>
            <span
              v-if="idx < lifecycleSteps.length - 1"
              :key="`conn-${step.state}`"
              class="flex-shrink-0 h-px mt-2 w-3 sm:w-6"
              :class="
                lifecycleSteps[idx + 1].visited
                  ? 'bg-slate-300 dark:bg-slate-500'
                  : 'bg-slate-200 dark:bg-slate-700'
              "
            />
          </template>
        </div>
        <!-- Estado actual fuera del ciclo de vida (espera / escalado) -->
        <div
          v-if="offLifecycleStatus"
          class="flex items-center gap-2 p-2 mt-1 rounded-lg bg-amber-50 dark:bg-amber-900/20"
        >
          <span
            class="flex-shrink-0 w-2.5 h-2.5 rounded-full"
            :class="statusDot(offLifecycleStatus)"
          />
          <span class="text-xs text-amber-700 dark:text-amber-300">
            {{ $t('CASE_TICKETS.JOURNEY.CURRENTLY') }}:
            {{ statusLabel(offLifecycleStatus) }}
          </span>
        </div>
      </div>
    </template>
  </div>
</template>
