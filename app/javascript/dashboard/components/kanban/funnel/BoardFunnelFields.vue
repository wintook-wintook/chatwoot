<script>
// Embudo de contactos — configuración del tablero: movimiento automático, por qué
// bandejas entran solas las conversaciones nuevas, si la IA mueve tarjetas y los
// vencimientos (Frío / Descartar). Trabaja sobre `value` (v-model).
import { mapGetters } from 'vuex';

export default {
  name: 'BoardFunnelFields',
  props: {
    value: { type: Object, required: true },
    // Al crear solo se eligen las bandejas: lo demás ya viene de la plantilla.
    creating: { type: Boolean, default: false },
  },
  computed: {
    ...mapGetters({ inboxes: 'inboxes/getInboxes' }),
    selectedInboxes() {
      return (this.value.entry_inbox_ids || []).map(Number);
    },
    showInboxWarning() {
      return (
        (this.creating || this.value.auto_move) && !this.selectedInboxes.length
      );
    },
  },
  methods: {
    update(patch) {
      this.$emit('input', { ...this.value, ...patch });
    },
    toggleInbox(id) {
      const ids = this.selectedInboxes.includes(id)
        ? this.selectedInboxes.filter(i => i !== id)
        : [...this.selectedInboxes, id];
      this.update({ entry_inbox_ids: ids });
    },
    days(event) {
      const n = parseInt(event.target.value, 10);
      return Number.isNaN(n) || n <= 0 ? null : n;
    },
  },
};
</script>

<template>
  <div class="w-full mb-4 border-t border-slate-200 dark:border-slate-700 pt-4">
    <p class="mb-2 text-sm font-semibold text-slate-700 dark:text-slate-200">
      {{ $t('KANBAN.FUNNEL.BOARD.SECTION') }}
    </p>
    <p v-if="creating" class="mb-3 text-xs text-slate-500 dark:text-slate-400">
      {{ $t('KANBAN.FUNNEL.BOARD.TEMPLATE_HINT') }}
    </p>

    <template v-if="!creating">
      <label
        class="flex items-center gap-2 text-sm text-slate-700 dark:text-slate-200"
      >
        <input
          type="checkbox"
          :checked="value.auto_move"
          @change="update({ auto_move: $event.target.checked })"
        />
        {{ $t('KANBAN.FUNNEL.BOARD.AUTO_MOVE') }}
      </label>
      <p class="mb-3 ml-6 text-xs text-slate-500 dark:text-slate-400">
        {{ $t('KANBAN.FUNNEL.BOARD.AUTO_MOVE_HELP') }}
      </p>
    </template>

    <p class="mb-1 text-sm font-medium text-slate-700 dark:text-slate-200">
      {{ $t('KANBAN.FUNNEL.BOARD.ENTRY_INBOXES') }}
    </p>
    <p class="mb-2 text-xs text-slate-500 dark:text-slate-400">
      {{ $t('KANBAN.FUNNEL.BOARD.ENTRY_INBOXES_HELP') }}
    </p>
    <div class="flex flex-wrap gap-1 mb-1">
      <button
        v-for="inbox in inboxes"
        :key="inbox.id"
        type="button"
        class="px-2 py-0.5 text-xs rounded-full border"
        :class="
          selectedInboxes.includes(inbox.id)
            ? 'bg-woot-500 text-white border-woot-500'
            : 'border-slate-200 dark:border-slate-700 text-slate-500 dark:text-slate-400'
        "
        @click="toggleInbox(inbox.id)"
      >
        {{ inbox.name }}
      </button>
    </div>
    <p
      v-if="showInboxWarning"
      class="mb-3 text-xs text-amber-600 dark:text-amber-400"
    >
      {{ $t('KANBAN.FUNNEL.BOARD.NO_INBOXES_WARNING') }}
    </p>

    <template v-if="!creating">
      <label
        class="flex items-center gap-2 mt-3 text-sm text-slate-700 dark:text-slate-200"
      >
        <input
          type="checkbox"
          :checked="value.ai_move"
          @change="update({ ai_move: $event.target.checked })"
        />
        {{ $t('KANBAN.FUNNEL.BOARD.AI_MOVE') }}
      </label>
      <p class="mb-3 ml-6 text-xs text-slate-500 dark:text-slate-400">
        {{ $t('KANBAN.FUNNEL.BOARD.AI_MOVE_HELP') }}
      </p>

      <div class="grid grid-cols-2 gap-3">
        <label class="text-xs text-slate-600 dark:text-slate-300">
          {{ $t('KANBAN.FUNNEL.BOARD.COLD_AFTER') }}
          <input
            type="number"
            min="1"
            class="mt-1"
            :value="value.cold_after_days"
            :placeholder="$t('KANBAN.FUNNEL.BOARD.DAYS_PLACEHOLDER')"
            @input="update({ cold_after_days: days($event) })"
          />
        </label>
        <label class="text-xs text-slate-600 dark:text-slate-300">
          {{ $t('KANBAN.FUNNEL.BOARD.DISCARD_AFTER') }}
          <input
            type="number"
            min="1"
            class="mt-1"
            :value="value.discard_after_days"
            :placeholder="$t('KANBAN.FUNNEL.BOARD.DAYS_PLACEHOLDER')"
            @input="update({ discard_after_days: days($event) })"
          />
        </label>
      </div>
    </template>
  </div>
</template>
