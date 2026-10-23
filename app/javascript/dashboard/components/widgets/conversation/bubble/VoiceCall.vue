<script>
// diag/llamadas_whatsapp (F5) — LA BURBUJA DE UNA LLAMADA DE WHATSAPP
// Lee content_attributes.data del mensaje voice_call (Voice::CallMessageBuilder):
// call_direction · status · duration_seconds · accepted_by.
const STATUS_COLOR = {
  completed: 'text-green-700 dark:text-green-400',
  'in-progress': 'text-woot-600 dark:text-woot-400',
  ringing: 'text-woot-600 dark:text-woot-400',
  'no-answer': 'text-red-600 dark:text-red-400',
  rejected: 'text-red-600 dark:text-red-400',
  failed: 'text-red-600 dark:text-red-400',
};

export default {
  props: {
    data: { type: Object, default: () => ({}) },
  },
  computed: {
    isInbound() {
      return this.data.call_direction !== 'outbound';
    },
    status() {
      return this.data.status || 'ringing';
    },
    // Una entrante que terminó sin contestar es «perdida».
    statusKey() {
      if (this.isInbound && this.status === 'no-answer') return 'MISSED';
      return this.status.toUpperCase().replace('-', '_');
    },
    statusClass() {
      return STATUS_COLOR[this.status] || 'text-slate-600 dark:text-slate-300';
    },
    // Solo existe el ícono `call`: la dirección la dice una flecha (hacia adentro/afuera).
    arrowIcon() {
      return this.isInbound ? 'arrow-right-import' : 'arrow-up-right';
    },
    duration() {
      const segundos = Number(this.data.duration_seconds || 0);
      if (!segundos) return '';
      const m = String(Math.floor(segundos / 60)).padStart(2, '0');
      return `${m}:${String(segundos % 60).padStart(2, '0')}`;
    },
    agentName() {
      return (this.data.accepted_by && this.data.accepted_by.name) || '';
    },
  },
  methods: {
    t(key, args) {
      return this.$t(`WHATSAPP_CALLS.BUBBLE.${key}`, args);
    },
  },
};
</script>

<template>
  <div class="flex items-center gap-3 min-w-[12rem] py-1">
    <span
      class="flex items-center justify-center w-9 h-9 rounded-full bg-slate-100 dark:bg-slate-700 shrink-0"
      :class="statusClass"
    >
      <fluent-icon icon="call" size="18" />
    </span>
    <div class="flex flex-col">
      <span class="inline-flex items-center gap-1 text-sm font-medium">
        <fluent-icon :icon="arrowIcon" size="12" />
        {{ isInbound ? t('INBOUND') : t('OUTBOUND') }}
      </span>
      <span class="text-xs" :class="statusClass">
        {{ t(`STATUS.${statusKey}`) }}
        <template v-if="duration"> · {{ duration }}</template>
      </span>
      <span v-if="agentName" class="text-xs opacity-80">
        {{ t('HANDLED_BY', { name: agentName }) }}
      </span>
    </div>
  </div>
</template>
