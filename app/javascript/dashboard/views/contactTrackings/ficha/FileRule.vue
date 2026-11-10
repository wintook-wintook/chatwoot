<script>
// feat/ficha_agente_ia — CUÁNDO SE MANDA UN ARCHIVO
// ============================================================================
// Pedido del usuario (10/11/2026): «archivo x se envía si lo piden (dependiendo de cómo
// se le puso el nombre), en ocasiones en x intento del seguimiento, en el mensaje de
// bienvenida». Una o varias a la vez:
//   ☑ Cuando lo pidan   ☐ Con la bienvenida   Intentos: [1] [2] [3]
// v-model: { ask: true, welcome: false, attempts: [2] }
// ============================================================================
export const defaultRule = () => ({
  ask: true,
  welcome: false,
  attempts: [],
  routes: [],
  booking: false,
  tickets: [],
});

// «Cuando lo pidan · Con la bienvenida · Intento 2 · Al agendar · Ticket: Soporte · Ruta: precios»
export const ruleSummary = (regla, t) => {
  const r = { ...defaultRule(), ...(regla || {}) };
  const partes = [];
  if (r.ask) partes.push(t('RULE_ASK'));
  if (r.welcome) partes.push(t('RULE_WELCOME'));
  if (r.booking) partes.push(t('RULE_BOOKING'));
  r.attempts.forEach(n => partes.push(`${t('RULE_ATTEMPTS')} ${n}`));
  if (r.tickets.length)
    partes.push(`${t('RULE_TICKETS')} ${r.tickets.join(', ')}`);
  if (r.routes.length)
    partes.push(`${t('RULE_ROUTES')} ${r.routes.join(', ')}`);
  return partes.length ? partes.join(' · ') : t('FILE_RULE_SUMMARY_NONE');
};

export default {
  model: { prop: 'value', event: 'input' },
  props: {
    value: { type: Object, default: defaultRule },
    // Cuántos intentos tiene el seguimiento (para los botones).
    attempts: { type: Number, default: 3 },
    disabled: { type: Boolean, default: false },
    // «Con la ruta»: [{ value, label }] (al crear, la llave del recurso; ya creado, el nombre).
    routeOptions: { type: Array, default: () => [] },
    // «Al levantar un ticket»: [{ value, label }] ('*' = cualquiera).
    ticketOptions: { type: Array, default: () => [] },
    // «Al agendar»: solo si el agente tiene agenda.
    showBooking: { type: Boolean, default: false },
  },
  emits: ['input'],
  computed: {
    rule() {
      return { ...defaultRule(), ...(this.value || {}) };
    },
    attemptList() {
      return Array.from({ length: this.attempts || 0 }, (_, i) => i + 1);
    },
    nothing() {
      const r = this.rule;
      return (
        !r.ask &&
        !r.welcome &&
        !r.booking &&
        !r.attempts.length &&
        !r.routes.length &&
        !r.tickets.length
      );
    },
  },
  methods: {
    set(campo, valor) {
      if (this.disabled) return;
      this.$emit('input', { ...this.rule, [campo]: valor });
    },
    toggleIn(campo, valor) {
      const lista = this.rule[campo].includes(valor)
        ? this.rule[campo].filter(item => item !== valor)
        : [...this.rule[campo], valor];
      this.set(campo, lista);
    },
    toggleAttempt(n) {
      const lista = this.rule.attempts.includes(n)
        ? this.rule.attempts.filter(item => item !== n)
        : [...this.rule.attempts, n].sort((a, b) => a - b);
      this.set('attempts', lista);
    },
  },
};
</script>

<template>
  <div class="flex flex-wrap items-center gap-x-3 gap-y-1 text-xs">
    <label class="flex items-center gap-1 !m-0 cursor-pointer">
      <input
        type="checkbox"
        class="!m-0"
        :checked="rule.ask"
        :disabled="disabled"
        @change="set('ask', $event.target.checked)"
      />
      {{ $t('TRACKING_TEMPLATES.FICHA.RULE_ASK') }}
    </label>
    <label class="flex items-center gap-1 !m-0 cursor-pointer">
      <input
        type="checkbox"
        class="!m-0"
        :checked="rule.welcome"
        :disabled="disabled"
        @change="set('welcome', $event.target.checked)"
      />
      {{ $t('TRACKING_TEMPLATES.FICHA.RULE_WELCOME') }}
    </label>
    <span v-if="attemptList.length" class="flex items-center gap-1">
      {{ $t('TRACKING_TEMPLATES.FICHA.RULE_ATTEMPTS') }}
      <button
        v-for="n in attemptList"
        :key="n"
        type="button"
        class="w-6 h-6 border rounded"
        :class="
          rule.attempts.includes(n)
            ? 'border-woot-500 bg-woot-500 text-white'
            : 'border-slate-200 text-slate-600 dark:border-slate-700 dark:text-slate-300'
        "
        :disabled="disabled"
        @click="toggleAttempt(n)"
      >
        {{ n }}
      </button>
    </span>
    <label
      v-if="showBooking"
      class="flex items-center gap-1 !m-0 cursor-pointer"
    >
      <input
        type="checkbox"
        class="!m-0"
        :checked="rule.booking"
        :disabled="disabled"
        @change="set('booking', $event.target.checked)"
      />
      {{ $t('TRACKING_TEMPLATES.FICHA.RULE_BOOKING') }}
    </label>
    <span v-if="ticketOptions.length" class="flex flex-wrap items-center gap-1">
      {{ $t('TRACKING_TEMPLATES.FICHA.RULE_TICKETS') }}
      <button
        v-for="opcion in ticketOptions"
        :key="opcion.value"
        type="button"
        class="px-2 py-0.5 border rounded-full"
        :class="
          rule.tickets.includes(opcion.value)
            ? 'border-woot-500 bg-woot-500 text-white'
            : 'border-slate-200 text-slate-600 dark:border-slate-700 dark:text-slate-300'
        "
        :disabled="disabled"
        @click="toggleIn('tickets', opcion.value)"
      >
        {{ opcion.label }}
      </button>
    </span>
    <span v-if="routeOptions.length" class="flex flex-wrap items-center gap-1">
      {{ $t('TRACKING_TEMPLATES.FICHA.RULE_ROUTES') }}
      <button
        v-for="opcion in routeOptions"
        :key="opcion.value"
        type="button"
        class="px-2 py-0.5 border rounded-full"
        :class="
          rule.routes.includes(opcion.value)
            ? 'border-woot-500 bg-woot-500 text-white'
            : 'border-slate-200 text-slate-600 dark:border-slate-700 dark:text-slate-300'
        "
        :disabled="disabled"
        @click="toggleIn('routes', opcion.value)"
      >
        {{ opcion.label }}
      </button>
    </span>
    <span v-if="nothing" class="text-amber-700">
      {{ $t('TRACKING_TEMPLATES.FICHA.RULE_NOTHING') }}
    </span>
  </div>
</template>
