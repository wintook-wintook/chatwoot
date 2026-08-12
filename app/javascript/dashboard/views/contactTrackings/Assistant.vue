<script>
// ================================================================================
// proyecto@ai_agent_assistant - F1
// ================================================================================
// Vista: Assistant.vue
// Descripción: Página del Asistente de Agentes IA. En F1 es el catálogo navegable
//              de capacidades, resuelto contra el estado real de la cuenta y del
//              canal: qué directiva está disponible, qué le hace a tu prompt y qué
//              modelo usaría el motor. El chat y el probador llegan en F3/F5.
// ================================================================================
import { VeTable } from 'vue-easytable';
import { useAlert } from 'dashboard/composables';
import AiAgentAssistantAPI from '../../api/aiAgentAssistant';

export default {
  components: { VeTable },
  data() {
    return {
      capabilities: [],
      engine: null,
      isLoading: false,
      selectedInboxId: '',
    };
  },
  computed: {
    inboxes() {
      return this.$store.getters['inboxes/getInboxes'] || [];
    },
    engineBudget() {
      if (!this.engine) return [];
      return Object.entries(this.engine.max_tokens).map(
        ([purpose, tokens]) => ({
          purpose,
          tokens,
        })
      );
    },
    columns() {
      return [
        {
          field: 'precedence',
          key: 'precedence',
          title: this.$t('AI_AGENT_ASSISTANT.ORDER'),
          align: 'center',
          width: 60,
          renderBodyCell: ({ row }) => (
            <span class="font-mono text-xs text-slate-400 dark:text-slate-500">
              {row.precedence || '—'}
            </span>
          ),
        },
        {
          field: 'syntax',
          key: 'syntax',
          title: this.$t('AI_AGENT_ASSISTANT.TABLE.CAPABILITY'),
          align: 'left',
          width: 300,
          renderBodyCell: ({ row }) => (
            <div class="min-w-0">
              <p class="m-0 text-sm font-semibold truncate text-slate-800 dark:text-slate-100">
                {this.label(row)}
              </p>
              <code class="block mt-0.5 text-xs truncate text-slate-500 dark:text-slate-400">
                {row.syntax}
              </code>
            </div>
          ),
        },
        {
          field: 'kind',
          key: 'kind',
          title: this.$t('AI_AGENT_ASSISTANT.TABLE.KIND'),
          align: 'left',
          width: 110,
          renderBodyCell: ({ row }) => (
            <span class="text-xs text-slate-600 dark:text-slate-300">
              {this.$t(`AI_AGENT_ASSISTANT.KIND.${row.kind}`)}
            </span>
          ),
        },
        {
          field: 'effect',
          key: 'effect',
          title: this.$t('AI_AGENT_ASSISTANT.TABLE.EFFECT'),
          align: 'left',
          width: 260,
          renderBodyCell: ({ row }) => {
            const effect = this.effect(row);
            return (
              <div class="min-w-0">
                <span
                  class={`inline-block px-2 py-0.5 rounded-full text-xs font-semibold ${effect.classes}`}
                >
                  {this.$t(`AI_AGENT_ASSISTANT.EFFECT.${effect.key}`)}
                </span>
                <p class="m-0 mt-1 text-xs leading-snug text-slate-500 dark:text-slate-400">
                  {this.$t(`AI_AGENT_ASSISTANT.EFFECT.${effect.key}_HINT`)}
                </p>
              </div>
            );
          },
        },
        {
          field: 'what',
          key: 'what',
          title: this.$t('AI_AGENT_ASSISTANT.TABLE.CAPABILITY'),
          align: 'left',
          renderBodyCell: ({ row }) => (
            <div class="min-w-0">
              <p class="m-0 text-xs leading-snug text-slate-600 dark:text-slate-300">
                {this.text(row, 'WHAT')}
              </p>
              <p class="m-0 mt-1 text-xs italic leading-snug text-slate-400 dark:text-slate-500">
                {this.text(row, 'WHEN')}
              </p>
            </div>
          ),
        },
        {
          field: 'available',
          key: 'available',
          title: this.$t('AI_AGENT_ASSISTANT.TABLE.STATUS'),
          align: 'left',
          width: 190,
          renderBodyCell: ({ row }) => (
            <div class="min-w-0">
              <span
                class={`inline-flex items-center gap-1 text-xs font-semibold ${
                  row.available
                    ? 'text-green-600 dark:text-green-400'
                    : 'text-slate-400 dark:text-slate-500'
                }`}
              >
                {row.available
                  ? this.$t('AI_AGENT_ASSISTANT.STATUS.AVAILABLE')
                  : this.$t('AI_AGENT_ASSISTANT.STATUS.UNAVAILABLE')}
              </span>
              <p class="m-0 mt-0.5 text-xs truncate text-slate-500 dark:text-slate-400">
                {this.statusDetail(row)}
              </p>
            </div>
          ),
        },
      ];
    },
  },
  mounted() {
    this.$store.dispatch('inboxes/get');
    this.fetchCapabilities();
  },
  methods: {
    async fetchCapabilities() {
      this.isLoading = true;
      try {
        const { data } = await AiAgentAssistantAPI.getCapabilities({
          inboxId: this.selectedInboxId,
        });
        this.capabilities = data.capabilities;
        this.engine = data.engine;
      } catch (error) {
        useAlert(this.$t('AI_AGENT_ASSISTANT.LOAD_ERROR'));
      } finally {
        this.isLoading = false;
      }
    },
    label(row) {
      return this.text(row, 'LABEL');
    },
    text(row, field) {
      return this.$t(`AI_AGENT_ASSISTANT.CAPABILITIES.${row.key}.${field}`);
    },
    // El efecto sobre el prompt es lo que de verdad hay que decidir antes de elegir
    // una directiva, así que va destacado y no escondido en la descripción.
    effect(row) {
      if (row.swallows_prompt) {
        return {
          key: 'SWALLOWS',
          classes:
            'bg-red-50 text-red-700 dark:bg-red-800/30 dark:text-red-300',
        };
      }
      if (row.renders_prompt) {
        return {
          key: 'RENDERS',
          classes:
            'bg-amber-50 text-amber-700 dark:bg-amber-800/30 dark:text-amber-300',
        };
      }
      if (row.kind === 'source') {
        return {
          key: 'KEEPS',
          classes:
            'bg-green-50 text-green-700 dark:bg-green-800/30 dark:text-green-300',
        };
      }
      return {
        key: 'NEUTRAL',
        classes:
          'bg-slate-100 text-slate-600 dark:bg-slate-700 dark:text-slate-300',
      };
    },
    statusDetail(row) {
      const detail = row.detail || {};
      if (row.key === 'adjunto' && !row.available) {
        return this.$t('AI_AGENT_ASSISTANT.STATUS.NEEDS_TEMPLATE');
      }
      if (detail.names && detail.names.length) {
        return detail.names.join(', ');
      }
      if (typeof detail.count === 'number' && detail.count > 0) {
        return this.$t('AI_AGENT_ASSISTANT.STATUS.COUNT_ITEMS', {
          count: detail.count,
        });
      }
      if (!row.available) {
        return this.text(row, 'REQUIREMENT');
      }
      return '';
    },
  },
};
</script>

<template>
  <div class="flex flex-col flex-1 w-full h-full min-h-0 p-4 overflow-hidden">
    <div class="flex items-start justify-between mb-3 shrink-0">
      <div class="flex items-start gap-2">
        <woot-sidemenu-icon />
        <div>
          <h1 class="text-xl font-bold text-slate-800 dark:text-slate-100">
            {{ $t('AI_AGENT_ASSISTANT.TITLE') }}
          </h1>
          <p class="mt-1 text-sm text-slate-600 dark:text-slate-400">
            {{ $t('AI_AGENT_ASSISTANT.DESCRIPTION') }}
          </p>
        </div>
      </div>
      <div class="flex items-center gap-2">
        <select
          v-model="selectedInboxId"
          class="h-8 py-0 mb-0 text-sm"
          @change="fetchCapabilities"
        >
          <option value="">
            {{ $t('AI_AGENT_ASSISTANT.INBOX_ALL') }}
          </option>
          <option v-for="inbox in inboxes" :key="inbox.id" :value="inbox.id">
            {{ inbox.name }}
          </option>
        </select>
        <woot-button
          variant="clear"
          icon="arrow-clockwise"
          :is-loading="isLoading"
          @click="fetchCapabilities"
        >
          {{ $t('AI_AGENT_ASSISTANT.REFRESH') }}
        </woot-button>
      </div>
    </div>

    <!-- Motor: modelo resuelto y presupuesto de salida -->
    <div
      v-if="engine"
      class="flex flex-wrap items-center gap-x-6 gap-y-2 px-4 py-3 mb-4 border rounded-lg shrink-0 bg-slate-25 dark:bg-slate-800 border-slate-75 dark:border-slate-700"
    >
      <div>
        <p class="m-0 text-xs font-semibold text-slate-500 dark:text-slate-400">
          {{ $t('AI_AGENT_ASSISTANT.ENGINE.MODEL') }}
        </p>
        <code class="text-sm font-bold text-slate-800 dark:text-slate-100">
          {{ engine.model }}
        </code>
      </div>
      <p class="m-0 max-w-md text-xs text-slate-500 dark:text-slate-400">
        {{
          selectedInboxId
            ? $t('AI_AGENT_ASSISTANT.ENGINE.MODEL_HINT')
            : $t('AI_AGENT_ASSISTANT.ENGINE.DEFAULT_HINT')
        }}
      </p>
      <div class="flex flex-wrap items-center gap-3">
        <div v-for="item in engineBudget" :key="item.purpose">
          <p
            class="m-0 text-xs text-slate-500 dark:text-slate-400"
            :title="$t('AI_AGENT_ASSISTANT.ENGINE.BUDGET_HINT')"
          >
            {{ $t(`AI_AGENT_ASSISTANT.ENGINE.PURPOSE.${item.purpose}`) }}
            <span
              class="font-mono font-bold text-slate-700 dark:text-slate-200"
            >
              {{ item.tokens }}
            </span>
          </p>
        </div>
      </div>
    </div>

    <!-- Aviso de exclusividad: es la decisión que hay que tomar antes de elegir -->
    <div
      class="px-4 py-3 mb-4 border rounded-lg shrink-0 bg-amber-50 dark:bg-amber-800/20 border-amber-200 dark:border-amber-800"
    >
      <p class="m-0 text-sm font-semibold text-amber-800 dark:text-amber-200">
        {{ $t('AI_AGENT_ASSISTANT.EXCLUSIVE_NOTE.TITLE') }}
      </p>
      <p
        class="m-0 mt-1 text-xs leading-snug text-amber-700 dark:text-amber-300"
      >
        {{ $t('AI_AGENT_ASSISTANT.EXCLUSIVE_NOTE.BODY') }}
      </p>
    </div>

    <div class="flex-1 min-h-0 assistant-table-wrap">
      <VeTable
        fixed-header
        max-height="100%"
        row-key-field-name="key"
        :columns="columns"
        :table-data="capabilities"
        :border-around="false"
      />
    </div>
  </div>
</template>

<style scoped lang="scss">
.assistant-table-wrap {
  ::v-deep {
    .ve-table {
      height: 100%;
    }

    .ve-table-header-th {
      padding: var(--space-small) var(--space-one) !important;
      font-size: var(--font-size-mini) !important;
    }

    .ve-table-body-td {
      padding: var(--space-small) var(--space-one) !important;
      vertical-align: top;
    }
  }
}
</style>
