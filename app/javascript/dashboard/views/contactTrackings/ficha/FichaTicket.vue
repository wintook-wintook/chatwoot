<script>
// feat/ficha_agente_ia — CUÁNDO SE LEVANTA ESTE TICKET
// ============================================================================
// Pedido del usuario (10/11/2026): «faltan las reglas de por qué se debe levantar un
// ticket… deben existir algunos motivos». Los motivos, en palabras del cliente, son lo
// que mira el clasificador para elegir la ruta del ticket; la prioridad va en la directiva.
//   Motivos: [reporta una falla ✕] [quiere hablar con una persona ✕] [+ escribir…]
//   Sugeridos: + presenta una queja  + es una urgencia  …
//   Prioridad: [media ▾]
// v-model: { reasons: [], priority: '' }  (Ficha::TicketUse en el servidor)
// ============================================================================
import { useAlert } from 'dashboard/composables';
import FichaAPI from 'dashboard/api/fichaAgente';

const PRIORITIES = ['', 'baja', 'media', 'alta', 'urgente'];
const SUGGESTED = [
  'SUG_PERSON',
  'SUG_FAILURE',
  'SUG_COMPLAINT',
  'SUG_URGENT',
  'SUG_QUOTE',
  'SUG_INVOICE',
  'SUG_UNSOLVED',
];
const MAX_REASONS = 8;

export default {
  model: { prop: 'value', event: 'input' },
  props: {
    // La tarjeta del tipo de ticket (name, summary con los campos que pide).
    card: { type: Object, required: true },
    value: { type: Object, default: null },
    disabled: { type: Boolean, default: false },
    // Rutas de fuente que pueden escalar a este ticket si no encuentran la respuesta.
    escalationOptions: { type: Array, default: () => [] },
    suggestContext: { type: Object, default: () => ({}) },
  },
  emits: ['input'],
  data() {
    return { draft: '', priorities: PRIORITIES, suggesting: false };
  },
  computed: {
    reasons() {
      return (this.value && this.value.reasons) || [];
    },
    escalateFrom() {
      return (this.value && this.value.escalate_from) || [];
    },
    priority() {
      return (this.value && this.value.priority) || '';
    },
    suggestions() {
      return SUGGESTED.map(key => this.t(key)).filter(
        texto => !this.reasons.includes(texto)
      );
    },
    full() {
      return this.reasons.length >= MAX_REASONS;
    },
  },
  methods: {
    t(key, args) {
      return this.$t(`TRACKING_TEMPLATES.FICHA.${key}`, args);
    },
    emit(cambios) {
      if (this.disabled) return;
      this.$emit('input', {
        reasons: this.reasons,
        priority: this.priority,
        escalate_from: this.escalateFrom,
        ...cambios,
      });
    },
    add(texto) {
      const motivo = (texto || '')
        .replace(/[(),]/g, ' ')
        .replace(/\s+/g, ' ')
        .trim();
      if (!motivo || this.full || this.reasons.includes(motivo)) return;
      this.emit({ reasons: [...this.reasons, motivo] });
      this.draft = '';
    },
    toggleEscalation(valor) {
      const lista = this.escalateFrom.includes(valor)
        ? this.escalateFrom.filter(item => item !== valor)
        : [...this.escalateFrom, valor];
      this.emit({ escalate_from: lista });
    },
    // ✨ La IA propone motivos con el nombre del tipo, lo que pide y lo que hace el agente.
    async suggest() {
      this.suggesting = true;
      try {
        const { data } = await FichaAPI.ticketSuggest(
          this.card.id,
          this.suggestContext
        );
        const nuevos = (data.reasons || []).filter(
          m => !this.reasons.includes(m)
        );
        this.emit({
          reasons: [...this.reasons, ...nuevos].slice(0, MAX_REASONS),
        });
      } catch (error) {
        const datos = error && error.response && error.response.data;
        useAlert((datos && datos.error) || this.t('SUGGEST_ERROR'));
      } finally {
        this.suggesting = false;
      }
    },
    remove(motivo) {
      this.emit({ reasons: this.reasons.filter(item => item !== motivo) });
    },
  },
};
</script>

<template>
  <div class="flex flex-col gap-3 text-sm">
    <div class="flex items-center justify-between gap-2">
      <span class="text-slate-800 dark:text-slate-100">
        {{ t('TICKET_WHEN', { name: card.name }) }}
      </span>
      <woot-button
        size="tiny"
        variant="smooth"
        icon="wand"
        :is-loading="suggesting"
        :is-disabled="disabled || suggesting || full"
        @click="suggest"
      >
        {{ t('SUGGEST') }}
      </woot-button>
    </div>
    <div class="flex flex-wrap items-center gap-1">
      <span
        v-for="motivo in reasons"
        :key="motivo"
        class="flex items-center gap-1 px-2 py-0.5 text-xs rounded-full bg-woot-500 text-white"
      >
        {{ motivo }}
        <button
          type="button"
          class="leading-none"
          :disabled="disabled"
          :aria-label="t('TICKET_REMOVE')"
          @click="remove(motivo)"
        >
          <fluent-icon icon="dismiss" size="10" />
        </button>
      </span>
      <input
        v-if="!full"
        v-model="draft"
        type="text"
        maxlength="80"
        class="!mb-0 !h-7 !w-56 text-xs"
        :placeholder="t('TICKET_ADD_PLACEHOLDER')"
        :disabled="disabled"
        @keydown.enter.prevent="add(draft)"
        @blur="add(draft)"
      />
    </div>
    <p v-if="!reasons.length" class="!m-0 text-xs text-amber-700">
      {{ t('TICKET_NO_REASONS') }}
    </p>
    <div v-if="suggestions.length && !full" class="flex flex-wrap gap-1">
      <span class="text-xs text-slate-500">{{ t('TICKET_SUGGESTED') }}</span>
      <button
        v-for="texto in suggestions"
        :key="texto"
        type="button"
        class="px-2 py-0.5 text-xs border rounded-full border-slate-200 text-slate-600 hover:border-woot-500 dark:border-slate-700 dark:text-slate-300"
        :disabled="disabled"
        @click="add(texto)"
      >
        {{ t('TICKET_ADD_ONE', { text: texto }) }}
      </button>
    </div>
    <div v-if="escalationOptions.length" class="flex flex-col gap-1">
      <span class="text-slate-800 dark:text-slate-100">
        {{ t('TICKET_ESCALATE') }}
      </span>
      <div class="flex flex-wrap gap-x-4 gap-y-1">
        <label
          v-for="opcion in escalationOptions"
          :key="opcion.value"
          class="flex items-center gap-1 !m-0 text-xs cursor-pointer"
        >
          <input
            type="checkbox"
            class="!m-0"
            :checked="escalateFrom.includes(opcion.value)"
            :disabled="disabled"
            @change="toggleEscalation(opcion.value)"
          />
          {{ opcion.label }}
        </label>
      </div>
    </div>
    <label class="flex items-center gap-2 !m-0 text-sm">
      {{ t('TICKET_PRIORITY') }}
      <select
        class="!mb-0 !h-8 !py-0 !w-auto text-sm"
        :value="priority"
        :disabled="disabled"
        @change="emit({ priority: $event.target.value })"
      >
        <option v-for="item in priorities" :key="item" :value="item">
          {{ t(item ? `PRIORITY_${item.toUpperCase()}` : 'PRIORITY_DEFAULT') }}
        </option>
      </select>
    </label>
  </div>
</template>
