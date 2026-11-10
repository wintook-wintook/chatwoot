<script>
// feat/ficha_agente_ia — LAS TARJETAS DE LA FICHA
// ============================================================================
// Plan: docs/ficha_agente_ia_plan.md §4.1. Una tarjeta con casilla por recurso: marcar =
// el agente lo usa. Cada una dice qué tiene, si está lista y, al abrirla, el detalle
// (columnas y filas de ejemplo, temas). Nada de directivas a la vista. En las
// predefinidas se eligen los grupos (todos si no se elige ninguno).
//
// v-model: [{ key: 'google_sheet:12' }, { key: 'canned_response', parts: ['PATITAS'] }]
// only:    los grupos a mostrar (el menú de Recursos muestra uno a la vez)
// query / kind: buscador y filtro por tipo
// ============================================================================
export const GROUPS = [
  {
    id: 'sources',
    kinds: [
      'sheet',
      'doc',
      'articles',
      'canned',
      'forum',
      'contpaq',
      'discourse',
      'erp',
    ],
  },
  { id: 'calendar', kinds: ['calendar'] },
  { id: 'tickets', kinds: ['case_type'] },
  { id: 'files', kinds: ['file'] },
];
export const ICONS = {
  sheet: 'library',
  doc: 'document',
  articles: 'book',
  canned: 'chat-multiple',
  forum: 'globe',
  contpaq: 'book-contacts',
  discourse: 'globe',
  erp: 'code',
  calendar: 'calendar',
  case_type: 'folder',
  file: 'attach',
};

import FichaSheet from './FichaSheet.vue';
import FichaTicket from './FichaTicket.vue';
import FichaModal from './FichaModal.vue';

// Tarjetas que se abren para decir qué hace el agente con ellas.
const CONFIGURABLE = ['sheet', 'case_type'];

const normalize = text =>
  (text || '').toString().normalize('NFD').replace(/[̀-ͯ]/g, '').toLowerCase();

export default {
  components: { FichaSheet, FichaTicket, FichaModal },
  model: { prop: 'value', event: 'input' },
  props: {
    cards: { type: Array, default: () => [] },
    value: { type: Array, default: () => [] },
    disabled: { type: Boolean, default: false },
    only: { type: Array, default: null },
    query: { type: String, default: '' },
    kind: { type: String, default: '' },
    showHeaders: { type: Boolean, default: true },
    // Tickets: rutas de fuente que pueden escalar a ese ticket ([{ value, label }]).
    escalationOptions: { type: Array, default: () => [] },
    // Lo capturado (para ✨ en hojas y tickets): { name, items }.
    suggestContext: { type: Object, default: () => ({}) },
  },
  emits: ['input'],
  data() {
    // modalKey: la hoja o el ticket que se está configurando (modal amplio).
    return { open: [], modalKey: null };
  },
  computed: {
    visibleCards() {
      const texto = normalize(this.query.trim());
      return this.cards.filter(card => {
        if (this.kind && card.kind !== this.kind) return false;
        if (!texto) return true;
        const partes = (card.parts || []).map(part => part.label).join(' ');
        return normalize(`${card.name} ${card.summary} ${partes}`).includes(
          texto
        );
      });
    },
    groups() {
      return GROUPS.filter(group => !this.only || this.only.includes(group.id))
        .map(group => ({
          ...group,
          cards: this.visibleCards.filter(card =>
            group.kinds.includes(card.kind)
          ),
        }))
        .filter(group => group.cards.length);
    },
    modalCard() {
      return this.cards.find(card => card.key === this.modalKey) || null;
    },
    modalTitle() {
      if (!this.modalCard) return '';
      return this.$t(
        `TRACKING_TEMPLATES.FICHA.MODAL_${this.modalCard.kind.toUpperCase()}`,
        { name: this.modalCard.name }
      );
    },
    selectedKeys() {
      return this.value.map(item => item.key);
    },
  },
  methods: {
    icon(card) {
      return ICONS[card.kind] || 'document';
    },
    isOn(card) {
      return this.selectedKeys.includes(card.key);
    },
    toggle(card) {
      if (this.disabled) return;
      const marcar = !this.isOn(card);
      const lista = marcar
        ? [...this.value, { key: card.key }]
        : this.value.filter(item => item.key !== card.key);
      this.$emit('input', lista);
      // Una hoja o un ticket recién marcados abren su configuración (modal amplio).
      if (marcar && CONFIGURABLE.includes(card.kind)) this.modalKey = card.key;
    },
    sheetOf(card) {
      const item = this.value.find(entry => entry.key === card.key);
      return (item && item.sheet) || null;
    },
    setSheet(card, config) {
      this.$emit(
        'input',
        this.value.map(item =>
          item.key === card.key ? { ...item, sheet: config } : item
        )
      );
    },
    configurable(card) {
      return CONFIGURABLE.includes(card.kind) && this.isOn(card);
    },
    // Lo que ya se dijo de la hoja o del ticket, en una línea (en la tarjeta).
    configSummary(card) {
      if (card.kind === 'sheet') {
        const hoja = this.sheetOf(card);
        return (hoja && hoja.purpose) || '';
      }
      const ticket = this.ticketOf(card);
      return ticket && ticket.reasons ? ticket.reasons.join(' · ') : '';
    },
    ticketOf(card) {
      const item = this.value.find(entry => entry.key === card.key);
      return (item && item.ticket) || null;
    },
    setTicket(card, config) {
      this.$emit(
        'input',
        this.value.map(item =>
          item.key === card.key ? { ...item, ticket: config } : item
        )
      );
    },
    // Marcar de un jalón las que están listas de un grupo.
    selectReady(group) {
      const listas = group.cards
        .filter(card => card.status === 'ready' && !this.isOn(card))
        .map(card => ({ key: card.key }));
      this.$emit('input', [...this.value, ...listas]);
    },
    clearGroup(group) {
      const llaves = group.cards.map(card => card.key);
      this.$emit(
        'input',
        this.value.filter(item => !llaves.includes(item.key))
      );
    },
    countOn(group) {
      return group.cards.filter(card => this.isOn(card)).length;
    },
    isOpen(card) {
      return this.open.includes(card.key);
    },
    toggleOpen(card) {
      this.open = this.isOpen(card)
        ? this.open.filter(key => key !== card.key)
        : [...this.open, card.key];
    },
    hasDetail(card) {
      return (
        (card.examples && card.examples.length) ||
        (card.parts && card.parts.length)
      );
    },
    partsOf(card) {
      const item = this.value.find(entry => entry.key === card.key);
      return (item && item.parts) || [];
    },
    // Sin grupos elegidos = todos.
    isPartOn(card, part) {
      const elegidos = this.partsOf(card);
      return !elegidos.length || elegidos.includes(part.key);
    },
    togglePart(card, part) {
      if (!this.isOn(card)) {
        this.$emit('input', [
          ...this.value,
          { key: card.key, parts: [part.key] },
        ]);
        return;
      }
      const todas = (card.parts || []).map(p => p.key);
      let elegidos = this.partsOf(card);
      if (!elegidos.length) elegidos = todas;
      elegidos = elegidos.includes(part.key)
        ? elegidos.filter(key => key !== part.key)
        : [...elegidos, part.key];
      const parts = elegidos.length === todas.length ? undefined : elegidos;
      if (parts && !parts.length) {
        this.$emit(
          'input',
          this.value.filter(item => item.key !== card.key)
        );
        return;
      }
      this.$emit(
        'input',
        this.value.map(item =>
          item.key === card.key ? { key: card.key, parts } : item
        )
      );
    },
    statusClass(card) {
      return card.status === 'ready'
        ? 'bg-green-50 text-green-700 dark:bg-green-900/30 dark:text-green-300'
        : 'bg-amber-50 text-amber-800 dark:bg-amber-900/30 dark:text-amber-300';
    },
    examplesOf(card) {
      return (card.examples || []).slice(0, 4);
    },
  },
};
</script>

<template>
  <div class="flex flex-col gap-6">
    <p
      v-if="!groups.length"
      class="!m-0 px-3 py-4 text-sm text-center border border-dashed rounded-lg text-slate-500 border-slate-200 dark:border-slate-700"
    >
      {{
        query || kind
          ? $t('TRACKING_TEMPLATES.FICHA.NO_MATCH')
          : $t('TRACKING_TEMPLATES.FICHA.NOTHING_HERE')
      }}
    </p>
    <section
      v-for="group in groups"
      :key="group.id"
      class="flex flex-col gap-2"
    >
      <div class="flex items-center justify-between gap-2">
        <h3
          v-if="showHeaders"
          class="!m-0 text-sm font-semibold text-slate-800 dark:text-slate-100"
        >
          {{ $t(`TRACKING_TEMPLATES.FICHA.GROUP_${group.id.toUpperCase()}`) }}
          <span class="ml-1 text-xs font-normal text-slate-500">
            {{ $t(`TRACKING_TEMPLATES.FICHA.HINT_${group.id.toUpperCase()}`) }}
          </span>
        </h3>
        <span v-else class="text-xs text-slate-500">
          {{
            $t('TRACKING_TEMPLATES.FICHA.COUNT_ON', {
              on: countOn(group),
              total: group.cards.length,
            })
          }}
        </span>
        <div v-if="!disabled" class="flex items-center gap-1">
          <woot-button
            v-if="group.cards.length > 1"
            size="tiny"
            variant="clear"
            icon="checkmark"
            @click="selectReady(group)"
          >
            {{ $t('TRACKING_TEMPLATES.FICHA.SELECT_READY') }}
          </woot-button>
          <woot-button
            v-if="countOn(group)"
            size="tiny"
            variant="clear"
            color-scheme="secondary"
            icon="dismiss"
            @click="clearGroup(group)"
          >
            {{ $t('TRACKING_TEMPLATES.FICHA.CLEAR') }}
          </woot-button>
        </div>
      </div>

      <div class="grid gap-2 sm:grid-cols-2 2xl:grid-cols-3">
        <div
          v-for="card in group.cards"
          :key="card.key"
          class="flex flex-col gap-2 p-3 transition-colors border rounded-lg"
          :class="[
            isOn(card)
              ? 'border-woot-500 bg-woot-25 dark:bg-woot-900/20 shadow-sm'
              : 'border-slate-200 dark:border-slate-700 hover:border-slate-300',
          ]"
        >
          <div class="flex items-start gap-2">
            <label
              class="flex items-start flex-1 min-w-0 gap-2 !m-0 cursor-pointer"
              :data-key="card.key"
            >
              <input
                type="checkbox"
                class="!m-0 mt-0.5 shrink-0"
                :checked="isOn(card)"
                :disabled="disabled"
                @change="toggle(card)"
              />
              <fluent-icon
                :icon="icon(card)"
                size="16"
                class="mt-0.5 shrink-0 text-slate-500"
              />
              <span class="flex flex-col min-w-0 gap-0.5">
                <span
                  class="text-sm font-medium truncate text-slate-800 dark:text-slate-100"
                  :title="card.name"
                >
                  {{ card.name }}
                </span>
                <span
                  class="text-xs text-slate-500 dark:text-slate-400 line-clamp-2"
                >
                  {{ card.summary }}
                </span>
              </span>
            </label>
            <woot-button
              v-if="hasDetail(card)"
              v-tooltip.top="$t('TRACKING_TEMPLATES.FICHA.DETAIL')"
              size="tiny"
              variant="clear"
              color-scheme="secondary"
              :icon="isOpen(card) ? 'chevron-up' : 'chevron-down'"
              @click="toggleOpen(card)"
            />
          </div>

          <div class="flex flex-wrap items-center gap-1 pl-6">
            <span
              class="px-1.5 py-0.5 text-xs rounded"
              :class="statusClass(card)"
            >
              {{
                card.status === 'ready'
                  ? $t('TRACKING_TEMPLATES.FICHA.READY')
                  : card.warning
              }}
            </span>
          </div>

          <!-- Detalle: filas de ejemplo / títulos -->
          <!-- Hoja o ticket marcados: qué hace el agente con ellos (modal amplio). -->
          <div v-if="configurable(card)" class="flex flex-col gap-1 pl-6">
            <span
              v-if="configSummary(card)"
              class="text-xs line-clamp-2 text-slate-600 dark:text-slate-300"
            >
              {{ configSummary(card) }}
            </span>
            <span v-else class="text-xs text-amber-700">
              {{
                $t(
                  `TRACKING_TEMPLATES.FICHA.CONFIG_MISSING_${card.kind.toUpperCase()}`
                )
              }}
            </span>
            <woot-button
              size="tiny"
              variant="smooth"
              icon="settings"
              class="self-start"
              :is-disabled="disabled"
              @click="modalKey = card.key"
            >
              {{ $t('TRACKING_TEMPLATES.FICHA.CONFIGURE') }}
            </woot-button>
          </div>
          <ul
            v-if="isOpen(card) && examplesOf(card).length"
            class="!m-0 !p-2 pl-6 list-none text-xs rounded bg-white/70 dark:bg-slate-800 text-slate-600 dark:text-slate-300"
          >
            <li
              v-for="(ejemplo, index) in examplesOf(card)"
              :key="index"
              class="truncate"
              :title="String(ejemplo)"
            >
              {{ ejemplo }}
            </li>
          </ul>

          <!-- Grupos de predefinidas -->
          <div
            v-if="
              card.parts && card.parts.length && (isOn(card) || isOpen(card))
            "
            class="flex flex-col gap-1 pl-6"
          >
            <span class="text-xs text-slate-500">
              {{ $t('TRACKING_TEMPLATES.FICHA.PARTS_HINT') }}
            </span>
            <div class="flex flex-wrap gap-1">
              <label
                v-for="part in card.parts"
                :key="part.key"
                v-tooltip.top="(part.topics || []).join(', ')"
                class="flex items-center gap-1 !m-0 px-2 py-0.5 text-xs border rounded-full cursor-pointer"
                :class="
                  isOn(card) && isPartOn(card, part)
                    ? 'border-woot-500 text-woot-700 dark:text-woot-200'
                    : 'border-slate-200 text-slate-500 dark:border-slate-700'
                "
              >
                <input
                  type="checkbox"
                  class="!m-0"
                  :checked="isOn(card) && isPartOn(card, part)"
                  :disabled="disabled"
                  @change="togglePart(card, part)"
                />
                {{ part.label }} ({{ part.count }})
                <span
                  v-if="part.not_ready"
                  class="flex items-center gap-0.5 text-amber-700"
                  :title="$t('TRACKING_TEMPLATES.FICHA.NOT_VECTORIZED')"
                >
                  <fluent-icon icon="warning" size="12" />
                  {{ part.not_ready }}
                </span>
              </label>
            </div>
          </div>
        </div>
      </div>
    </section>
    <FichaModal
      :show="!!modalCard"
      :title="modalTitle"
      :subtitle="modalCard ? modalCard.summary : ''"
      @close="modalKey = null"
    >
      <template v-if="modalCard">
        <FichaSheet
          v-if="modalCard.kind === 'sheet'"
          :card="modalCard"
          :value="sheetOf(modalCard)"
          :disabled="disabled"
          :suggest-context="suggestContext"
          @input="setSheet(modalCard, $event)"
        />
        <FichaTicket
          v-else
          :card="modalCard"
          :value="ticketOf(modalCard)"
          :disabled="disabled"
          :escalation-options="escalationOptions"
          :suggest-context="suggestContext"
          @input="setTicket(modalCard, $event)"
        />
      </template>
    </FichaModal>
  </div>
</template>
