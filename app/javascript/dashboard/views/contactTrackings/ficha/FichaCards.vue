<script>
// feat/ficha_agente_ia — LAS TARJETAS DE LA FICHA
// ============================================================================
// Plan: docs/ficha_agente_ia_plan.md §4.1. Una tarjeta con casilla por recurso: marcar =
// el agente lo usa. Cada una dice qué tiene y si está lista; nada de directivas a la
// vista. En las predefinidas se eligen los grupos (todos si no se elige ninguno).
//
// v-model: [{ key: 'google_sheet:12' }, { key: 'canned_response', parts: ['PATITAS'] }]
// ============================================================================
const GROUPS = [
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
const ICONS = {
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

export default {
  model: { prop: 'value', event: 'input' },
  props: {
    cards: { type: Array, default: () => [] },
    value: { type: Array, default: () => [] },
    disabled: { type: Boolean, default: false },
    // Agente nuevo: los archivos se suben cuando ya existe.
    showFilesHint: { type: Boolean, default: false },
  },
  emits: ['input'],
  computed: {
    groups() {
      return GROUPS.map(group => ({
        ...group,
        cards: this.cards.filter(card => group.kinds.includes(card.kind)),
      })).filter(group => group.cards.length || group.id === 'files');
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
      const lista = this.isOn(card)
        ? this.value.filter(item => item.key !== card.key)
        : [...this.value, { key: card.key }];
      this.$emit('input', lista);
    },
    // Marcar de un jalón las que están listas de un grupo.
    selectReady(group) {
      const listas = group.cards
        .filter(card => card.status === 'ready' && !this.isOn(card))
        .map(card => ({ key: card.key }));
      this.$emit('input', [...this.value, ...listas]);
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
  },
};
</script>

<template>
  <div class="flex flex-col gap-6">
    <section
      v-for="group in groups"
      :key="group.id"
      class="flex flex-col gap-2"
    >
      <div class="flex items-center justify-between gap-2">
        <h3
          class="!m-0 text-sm font-semibold text-slate-800 dark:text-slate-100"
        >
          {{ $t(`TRACKING_TEMPLATES.FICHA.GROUP_${group.id.toUpperCase()}`) }}
          <span class="ml-1 text-xs font-normal text-slate-500">
            {{ $t(`TRACKING_TEMPLATES.FICHA.HINT_${group.id.toUpperCase()}`) }}
          </span>
        </h3>
        <woot-button
          v-if="group.cards.length > 1 && !disabled"
          size="tiny"
          variant="clear"
          icon="checkmark"
          @click="selectReady(group)"
        >
          {{ $t('TRACKING_TEMPLATES.FICHA.SELECT_READY') }}
        </woot-button>
      </div>

      <p
        v-if="!group.cards.length"
        class="!m-0 px-3 py-2 text-xs border border-dashed rounded-lg text-slate-500 border-slate-200 dark:border-slate-700"
      >
        {{
          showFilesHint
            ? $t('TRACKING_TEMPLATES.FICHA.FILES_AFTER')
            : $t('TRACKING_TEMPLATES.FICHA.FILES_EMPTY')
        }}
      </p>

      <div class="grid gap-2 sm:grid-cols-2 xl:grid-cols-3">
        <div
          v-for="card in group.cards"
          :key="card.key"
          class="flex flex-col gap-2 p-3 transition-colors border rounded-lg"
          :class="
            isOn(card)
              ? 'border-woot-500 bg-woot-25 dark:bg-woot-900/20'
              : 'border-slate-200 dark:border-slate-700'
          "
        >
          <label
            class="flex items-start gap-2 !m-0 cursor-pointer"
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

          <!-- Grupos de predefinidas -->
          <div
            v-if="isOn(card) && card.parts && card.parts.length"
            class="flex flex-wrap gap-1 pl-6"
          >
            <label
              v-for="part in card.parts"
              :key="part.key"
              class="flex items-center gap-1 !m-0 px-2 py-0.5 text-xs border rounded-full cursor-pointer"
              :class="
                isPartOn(card, part)
                  ? 'border-woot-500 text-woot-700 dark:text-woot-200'
                  : 'border-slate-200 text-slate-500 dark:border-slate-700'
              "
            >
              <input
                type="checkbox"
                class="!m-0"
                :checked="isPartOn(card, part)"
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
    </section>
  </div>
</template>
