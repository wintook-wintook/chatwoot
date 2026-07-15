<!--
  @query_databases — tarjeta de un bot cobrador (admin). Mismo patrón visual que
  las tarjetas de Fuentes / Conexiones de la Base de Conocimiento.
-->
<script>
export default {
  name: 'ErpBotCard',
  props: {
    bot: { type: Object, required: true },
    connectionName: { type: String, default: '' },
    inboxName: { type: String, default: '' },
  },
  emits: ['edit', 'delete'],
  computed: {
    statusClass() {
      return this.bot.active
        ? 'bg-green-50 text-green-700 dark:bg-green-900 dark:text-green-200'
        : 'bg-slate-100 text-slate-500 dark:bg-slate-700 dark:text-slate-300';
    },
  },
};
</script>

<template>
  <div
    class="flex flex-col gap-3 p-4 bg-white border shadow-sm rounded-xl border-slate-100 dark:bg-slate-800 dark:border-slate-700"
  >
    <!-- Header -->
    <div class="flex items-start justify-between">
      <div class="flex items-center gap-3">
        <div
          class="flex items-center justify-center w-10 h-10 rounded-lg bg-woot-50 dark:bg-woot-800"
        >
          <fluent-icon icon="megaphone" size="20" class="text-woot-500" />
        </div>
        <div>
          <p class="text-base font-semibold text-slate-800 dark:text-slate-100">
            {{ bot.name }}
          </p>
          <p class="text-sm text-slate-500 dark:text-slate-400">
            {{ connectionName || '—' }}
          </p>
        </div>
      </div>
      <span
        class="px-2 text-sm font-medium rounded-full whitespace-nowrap"
        :class="statusClass"
      >
        {{ bot.active ? $t('ERP.BOTS.ACTIVE') : $t('ERP.BOTS.INACTIVE') }}
      </span>
    </div>

    <!-- Info -->
    <div
      class="flex flex-col gap-1.5 text-sm text-slate-400 dark:text-slate-500"
    >
      <div class="flex items-center gap-1.5">
        <fluent-icon icon="clock" size="14" />
        <span>{{ `${bot.run_hour}:00` }}</span>
      </div>
      <div v-if="inboxName" class="flex items-center gap-1.5">
        <fluent-icon icon="send" size="14" />
        <span class="truncate">{{ inboxName }}</span>
      </div>
      <div v-if="bot.mode_b_enabled" class="flex items-center gap-1.5">
        <fluent-icon icon="chat-multiple" size="14" class="text-green-500" />
        <span class="text-green-600 dark:text-green-400">
          {{ $t('ERP.BOTS.MODE_B_BADGE') }}
        </span>
      </div>
    </div>

    <!-- Acciones -->
    <div
      class="flex gap-2 pt-2 border-t border-slate-100 dark:border-slate-700"
    >
      <woot-button
        size="small"
        variant="smooth"
        color-scheme="secondary"
        icon="edit"
        @click="$emit('edit', bot)"
      >
        {{ $t('ERP.CONNECTIONS.EDIT') }}
      </woot-button>
      <woot-button
        size="small"
        variant="smooth"
        color-scheme="alert"
        icon="delete"
        @click="$emit('delete', bot)"
      />
    </div>
  </div>
</template>
