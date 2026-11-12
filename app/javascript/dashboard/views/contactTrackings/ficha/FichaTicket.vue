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
// 10/11/2026: los motivos se escriben en una caja de 2 renglones (uno por renglón o con
// coma) y TODOS (sugeridos, los de ✨ y los escritos) se ven como chips: marcado = en
// color y cuenta; sin marcar = gris y NO se toma en cuenta.
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
    // offered: motivos que se muestran sin ser fijos (los de ✨ y los escritos), para que
    // al desmarcarlos no desaparezcan.
    return {
      draft: '',
      priorities: PRIORITIES,
      suggesting: false,
      offered: [],
      max: MAX_REASONS,
    };
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
    // Todos los chips: los sugeridos fijos, los de ✨/escritos y los ya guardados.
    chips() {
      return [
        ...new Set([
          ...SUGGESTED.map(key => this.t(key)),
          ...this.offered,
          ...this.reasons,
        ]),
      ];
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
    clean(texto) {
      return (texto || '')
        .replace(/[()]/g, ' ')
        .replace(/\s+/g, ' ')
        .trim()
        .slice(0, 80);
    },
    // Lo escrito: uno por renglón o separados por coma; quedan marcados.
    addDraft() {
      const nuevos = (this.draft || '')
        .split(/[\n,]/)
        .map(texto => this.clean(texto))
        .filter(texto => texto && !this.reasons.includes(texto));
      this.draft = '';
      if (!nuevos.length) return;
      this.offered = [...new Set([...this.offered, ...nuevos])];
      this.emit({
        reasons: [...new Set([...this.reasons, ...nuevos])].slice(
          0,
          MAX_REASONS
        ),
      });
    },
    isOn(motivo) {
      return this.reasons.includes(motivo);
    },
    toggle(motivo) {
      if (this.isOn(motivo)) {
        this.emit({ reasons: this.reasons.filter(item => item !== motivo) });
        return;
      }
      if (this.full) return;
      this.emit({ reasons: [...this.reasons, motivo] });
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
        // Los de ✨ se muestran SIN marcar: la persona elige cuáles usar.
        const nuevos = (data.reasons || [])
          .map(m => this.clean(m))
          .filter(m => m && !this.chips.includes(m));
        this.offered = [...this.offered, ...nuevos];
      } catch (error) {
        const datos = error && error.response && error.response.data;
        useAlert((datos && datos.error) || this.t('SUGGEST_ERROR'));
      } finally {
        this.suggesting = false;
      }
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
    <p class="!m-0 text-xs text-slate-500">{{ t('TICKET_REASONS_HINT') }}</p>
    <div class="flex flex-wrap gap-1.5">
      <button
        v-for="motivo in chips"
        :key="motivo"
        type="button"
        class="flex items-center gap-1 px-2.5 py-1 text-xs border rounded-full transition-colors"
        :class="
          isOn(motivo)
            ? 'border-woot-500 bg-woot-500 text-white'
            : 'border-slate-200 text-slate-500 hover:border-woot-400 dark:border-slate-700 dark:text-slate-400'
        "
        :disabled="disabled || (!isOn(motivo) && full)"
        :aria-pressed="isOn(motivo) ? 'true' : 'false'"
        @click="toggle(motivo)"
      >
        <fluent-icon :icon="isOn(motivo) ? 'checkmark' : 'add'" size="10" />
        {{ motivo }}
      </button>
    </div>
    <span class="text-xs text-slate-500">
      {{ t('TICKET_COUNT', { on: reasons.length, max }) }}
    </span>
    <p v-if="!reasons.length" class="!m-0 text-xs text-amber-700">
      {{ t('TICKET_NO_REASONS') }}
    </p>
    <div v-if="!full" class="flex items-start gap-2">
      <textarea
        v-model="draft"
        rows="2"
        maxlength="400"
        class="flex-1 !mb-0 text-sm"
        :placeholder="t('TICKET_ADD_PLACEHOLDER')"
        :disabled="disabled"
        @keydown.enter.exact.prevent="addDraft"
      />
      <woot-button
        size="small"
        variant="smooth"
        icon="add"
        :is-disabled="disabled || !draft.trim()"
        @click="addDraft"
      >
        {{ t('TICKET_ADD') }}
      </woot-button>
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
