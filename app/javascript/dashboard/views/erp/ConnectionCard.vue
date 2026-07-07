<!--
  @query_databases — tarjeta de una conexión ERP (admin). Mismo patrón visual que
  las tarjetas de Fuentes (SourceCard) de la Base de Conocimiento.
-->
<script>
export default {
  name: 'ErpConnectionCard',
  props: {
    connection: { type: Object, required: true },
    testing: { type: Boolean, default: false },
    seeding: { type: Boolean, default: false },
    active: { type: Boolean, default: false },
  },
  emits: ['test', 'queries', 'seed', 'edit', 'delete'],
  computed: {
    erpTypeLabel() {
      return (
        {
          sae: 'Aspel SAE',
          microsip: 'Microsip',
          contpaq: 'CONTPAQi',
          generic: 'Genérico',
        }[this.connection.erp_type] || 'Genérico'
      );
    },
    isSeedable() {
      return this.connection.erp_type && this.connection.erp_type !== 'generic';
    },
  },
};
</script>

<template>
  <div
    class="flex flex-col gap-3 p-4 bg-white border shadow-sm rounded-xl border-slate-100 dark:bg-slate-800 dark:border-slate-700"
    :class="{ 'ring-2 ring-woot-400': active }"
  >
    <!-- Header -->
    <div class="flex items-start justify-between">
      <div class="flex items-center gap-3">
        <div
          class="flex items-center justify-center w-10 h-10 rounded-lg bg-woot-50 dark:bg-woot-800"
        >
          <fluent-icon icon="cloud" size="20" class="text-woot-500" />
        </div>
        <div>
          <p class="text-base font-semibold text-slate-800 dark:text-slate-100">
            {{ connection.name }}
          </p>
          <p class="text-sm text-slate-500 dark:text-slate-400">
            {{ erpTypeLabel }}
          </p>
        </div>
      </div>
      <span
        class="px-2 text-sm font-medium uppercase rounded-full bg-woot-50 text-woot-700 dark:bg-woot-900 dark:text-woot-200"
      >
        {{ connection.engine }}
      </span>
    </div>

    <!-- Host -->
    <div
      class="flex items-center gap-1.5 text-sm font-mono text-slate-400 dark:text-slate-500 truncate"
    >
      <fluent-icon icon="link" size="14" />
      <span class="truncate">{{ connection.host }}:{{ connection.port }}</span>
    </div>

    <!-- Acciones -->
    <div
      class="flex flex-wrap gap-2 pt-2 border-t border-slate-100 dark:border-slate-700"
    >
      <woot-button
        size="small"
        variant="smooth"
        color-scheme="success"
        icon="checkmark"
        :is-loading="testing"
        @click="$emit('test', connection)"
      >
        {{ $t('ERP.CONNECTIONS.TEST') }}
      </woot-button>
      <woot-button
        size="small"
        :variant="active ? 'solid' : 'smooth'"
        color-scheme="secondary"
        icon="code"
        @click="$emit('queries', connection)"
      >
        {{ $t('ERP.CONNECTIONS.QUERIES') }} ({{ connection.queries_count }})
      </woot-button>
      <woot-button
        v-if="isSeedable"
        size="small"
        variant="smooth"
        icon="add"
        :is-loading="seeding"
        @click="$emit('seed', connection)"
      >
        {{ $t('ERP.CONNECTIONS.SEED') }}
      </woot-button>
      <woot-button
        size="small"
        variant="smooth"
        color-scheme="secondary"
        icon="edit"
        @click="$emit('edit', connection)"
      />
      <woot-button
        size="small"
        variant="smooth"
        color-scheme="alert"
        icon="delete"
        @click="$emit('delete', connection)"
      />
    </div>
  </div>
</template>
