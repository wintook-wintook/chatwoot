<script>
// feat/bandejas_por_tipo — ORDENAR LOS GRUPOS DE BANDEJAS DEL MENÚ
// ============================================================================
// El agente acomoda el orden de los grupos (WhatsApp, Telegram, Correo, Meta…)
// arrastrando o con ▲▼. Se trabaja sobre una copia y solo «Guardar» la devuelve;
// «Restablecer» vuelve al orden por omisión. Plan: docs/chat_interno_plan.md §10.3
// ============================================================================
import draggable from 'vuedraggable';
import { DEFAULT_INBOX_GROUP_ORDER } from 'dashboard/helper/inboxGroups';

export default {
  components: { Draggable: draggable },
  props: {
    order: { type: Array, required: true },
    // { whatsapp: 3, email: 1 }: cuántas bandejas tiene hoy cada grupo.
    counts: { type: Object, default: () => ({}) },
  },
  emits: ['close', 'save'],
  data() {
    return { draft: [...this.order] };
  },
  methods: {
    groupLabel(key) {
      return this.$t(`SIDEBAR.INBOX_GROUPS.${key.toUpperCase()}`);
    },
    countFor(key) {
      return this.counts[key] || 0;
    },
    move(index, offset) {
      const target = index + offset;
      if (target < 0 || target >= this.draft.length) return;
      const next = [...this.draft];
      [next[index], next[target]] = [next[target], next[index]];
      this.draft = next;
    },
    reset() {
      this.draft = [...DEFAULT_INBOX_GROUP_ORDER];
    },
    save() {
      this.$emit('save', [...this.draft]);
    },
  },
};
</script>

<template>
  <woot-modal show :on-close="() => $emit('close')">
    <div class="flex flex-col h-auto overflow-auto">
      <woot-modal-header
        :header-title="$t('SIDEBAR.INBOX_GROUPS_MODAL.TITLE')"
        :header-content="$t('SIDEBAR.INBOX_GROUPS_MODAL.DESCRIPTION')"
      />
      <div class="flex flex-col gap-4 px-8 pb-6">
        <Draggable
          v-model="draft"
          tag="ol"
          handle=".drag-handle"
          ghost-class="opacity-50"
          class="flex flex-col gap-2 m-0 list-none"
        >
          <li
            v-for="(key, index) in draft"
            :key="key"
            class="flex items-center gap-2 px-3 py-2 border rounded-lg border-slate-100 dark:border-slate-700 bg-white dark:bg-slate-800"
          >
            <span
              class="cursor-move drag-handle text-slate-400 dark:text-slate-500"
              :title="$t('SIDEBAR.INBOX_GROUPS_MODAL.DRAG')"
            >
              <fluent-icon icon="drag" size="16" />
            </span>
            <span class="w-5 text-xs text-right text-slate-400">
              {{ index + 1 }}
            </span>
            <span class="flex-1 text-sm text-slate-700 dark:text-slate-100">
              {{ groupLabel(key) }}
              <span class="text-xs text-slate-400 dark:text-slate-500">
                ({{ countFor(key) }})
              </span>
            </span>
            <woot-button
              size="tiny"
              variant="clear"
              color-scheme="secondary"
              icon="chevron-up"
              :is-disabled="index === 0"
              :title="$t('SIDEBAR.INBOX_GROUPS_MODAL.UP')"
              @click="move(index, -1)"
            />
            <woot-button
              size="tiny"
              variant="clear"
              color-scheme="secondary"
              icon="chevron-down"
              :is-disabled="index === draft.length - 1"
              :title="$t('SIDEBAR.INBOX_GROUPS_MODAL.DOWN')"
              @click="move(index, 1)"
            />
          </li>
        </Draggable>
        <p class="m-0 text-xs text-slate-500 dark:text-slate-400">
          {{ $t('SIDEBAR.INBOX_GROUPS_MODAL.HINT') }}
        </p>
        <div class="flex items-center justify-between gap-2">
          <woot-button variant="clear" color-scheme="secondary" @click="reset">
            {{ $t('SIDEBAR.INBOX_GROUPS_MODAL.RESET') }}
          </woot-button>
          <div class="flex gap-2">
            <woot-button
              variant="clear"
              color-scheme="secondary"
              @click="$emit('close')"
            >
              {{ $t('SIDEBAR.INBOX_GROUPS_MODAL.CANCEL') }}
            </woot-button>
            <woot-button @click="save">
              {{ $t('SIDEBAR.INBOX_GROUPS_MODAL.SAVE') }}
            </woot-button>
          </div>
        </div>
      </div>
    </div>
  </woot-modal>
</template>
