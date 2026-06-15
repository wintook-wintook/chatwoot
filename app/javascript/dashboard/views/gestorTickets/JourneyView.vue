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

// @tickets_cases — Recorrido "Fases + desvíos": espina obligatoria de 5 fases
// (cada una agrupa sus sub-estados); 'En espera' y 'Escalado' NO son fases de la
// espina sino desvíos que se dibujan sangrados bajo la fase donde ocurrieron.
const SPINE = [
  { key: 'new', dot: 'bg-blue-500', states: ['open', 'classified'] },
  { key: 'assigned', dot: 'bg-cyan-500', states: ['assigned', 'in_diagnosis'] },
  { key: 'progress', dot: 'bg-sky-500', states: ['in_progress'] },
  { key: 'resolved', dot: 'bg-green-500', states: ['resolved', 'validating'] },
  { key: 'closed', dot: 'bg-slate-500', states: ['closed', 'cancelled'] },
];
const DETOUR_KIND = {
  waiting_on_customer: 'waiting',
  waiting_on_third_party: 'waiting',
  waiting_on_internal: 'waiting',
  escalated: 'escalated',
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
          toLevel: e.payload.to_level, // @tickets_cases 2D — nivel de escalado (N1/N2/N3)
        }));
    },
    // @tickets_cases — Recorrido "Fases + desvíos": espina de 5 fases con el
    // sub-estado realmente alcanzado, y los desvíos (espera/escalado) sangrados
    // bajo la fase en la que ocurrieron. No se inventan pasos no recorridos.
    phaseJourney() {
      if (!this.ticket) return [];
      const phases = SPINE.map(p => ({
        key: p.key,
        dot: p.dot,
        reached: false,
        subState: null,
        meta: null,
        current: false,
        detoursAfter: [],
      }));
      const steps = [
        {
          to: 'open',
          at: this.ticket.created_at,
          actor: '',
          reason: '',
          isStart: true,
        },
        ...this.transitions,
      ];
      let curIdx = 0;
      steps.forEach(s => {
        const idx = SPINE.findIndex(p => p.states.includes(s.to));
        if (idx >= 0) {
          const ph = phases[idx];
          ph.reached = true;
          ph.subState = s.to;
          ph.meta = {
            at: s.at,
            actor: s.actor,
            reason: s.reason,
            isStart: !!s.isStart,
          };
          curIdx = idx;
        } else if (DETOUR_KIND[s.to]) {
          phases[curIdx].detoursAfter.push({
            kind: DETOUR_KIND[s.to],
            state: s.to,
            at: s.at,
            actor: s.actor,
            reason: s.reason,
            level: s.toLevel,
          });
        }
      });
      const cur = this.ticket.status;
      const curSpine = SPINE.findIndex(p => p.states.includes(cur));
      if (curSpine >= 0) phases[curSpine].current = true;
      phases.forEach(ph =>
        ph.detoursAfter.forEach(d => {
          d.current = d.state === cur;
        })
      );
      return phases;
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
    // @tickets_cases — etiqueta de fase reutilizando las columnas del Tablero
    phaseLabel(key) {
      return this.$t(`CASE_TICKETS.KANBAN.COLUMNS.${key}`) || key;
    },
    detourBadge(kind) {
      return kind === 'escalated'
        ? 'bg-red-100 text-red-700 dark:bg-red-900/40 dark:text-red-300'
        : 'bg-amber-100 text-amber-700 dark:bg-amber-900/40 dark:text-amber-300';
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
      <!-- ── Vista 1: Recorrido por fases (espina + desvíos) ─────── -->
      <div v-if="view === 'diagram'" class="relative">
        <!-- Espina vertical continua (detrás de los nodos) -->
        <span
          class="absolute left-[9px] top-2.5 bottom-3 w-0.5 bg-slate-200 dark:bg-slate-600"
        />
        <div
          v-for="(ph, idx) in phaseJourney"
          :key="ph.key"
          class="relative flex gap-4"
          :class="idx < phaseJourney.length - 1 ? 'pb-5' : ''"
        >
          <!-- Nodo de fase (punto con halo que enmascara la espina) -->
          <span
            class="z-10 flex-shrink-0 w-[18px] h-[18px] mt-1 rounded-full ring-4 ring-white dark:ring-slate-800"
            :class="[
              ph.reached ? ph.dot : 'bg-slate-200 dark:bg-slate-600',
              ph.current ? '!ring-woot-100 dark:!ring-woot-900' : '',
            ]"
          >
            <span
              v-if="ph.current"
              class="block w-full h-full rounded-full animate-ping opacity-50"
              :class="ph.dot"
            />
          </span>
          <!-- Contenido de la fase -->
          <div class="flex-1 min-w-0" :class="ph.reached ? '' : 'opacity-40'">
            <div class="flex flex-wrap items-center gap-2">
              <span
                class="text-sm font-semibold text-slate-800 dark:text-slate-100"
                >{{ phaseLabel(ph.key) }}</span
              >
              <span
                v-if="ph.reached && ph.subState"
                class="text-xs text-slate-500 dark:text-slate-400"
                >→ {{ statusLabel(ph.subState) }}</span
              >
              <span
                v-if="ph.current"
                class="px-2 py-0.5 text-[10px] font-semibold rounded-full bg-woot-100 text-woot-700 dark:bg-woot-800 dark:text-woot-100"
                >{{ $t('CASE_TICKETS.JOURNEY.CURRENT') }}</span
              >
            </div>
            <p
              v-if="ph.meta && ph.meta.reason"
              class="m-0 mt-1 text-sm italic text-slate-500 dark:text-slate-400"
            >
              {{ quotedReason(ph.meta.reason) }}
            </p>
            <p
              v-if="ph.reached"
              class="m-0 mt-1 text-xs text-slate-400 dark:text-slate-500"
            >
              <template v-if="ph.meta && ph.meta.isStart">
                {{ $t('CASE_TICKETS.JOURNEY.CREATED') }}
              </template>
              <template v-else> {{ ph.meta && ph.meta.actor }} </template>
              · {{ formatDate(ph.meta && ph.meta.at) }}
            </p>
            <!-- Desvíos (espera / escalado) bajo la fase -->
            <div
              v-for="(d, di) in ph.detoursAfter"
              :key="`detour-${idx}-${di}`"
              class="flex flex-wrap items-center gap-2 mt-1.5 text-xs"
            >
              <span class="text-slate-400 dark:text-slate-500">↳</span>
              <span
                class="px-1.5 py-0.5 rounded font-medium"
                :class="detourBadge(d.kind)"
              >
                {{ d.kind === 'escalated' ? '⚠' : '⏸' }}
                {{ statusLabel(d.state)
                }}<template v-if="d.level != null">
                  · N{{ d.level + 1 }}</template>
              </span>
              <span class="text-slate-400 dark:text-slate-500">
                {{
                  d.current
                    ? $t('CASE_TICKETS.JOURNEY.CURRENTLY')
                    : $t('CASE_TICKETS.JOURNEY.RETURNED')
                }}
                · {{ formatDate(d.at) }}
              </span>
            </div>
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
