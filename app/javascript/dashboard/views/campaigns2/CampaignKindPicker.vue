<!--
  Campaña con IA — elegir el tipo antes de entrar al asistente (Ofrecer, Invitar, Reactivar, Recordar o renovar,
  Encuesta): tarjetas con su descripción; un clic y listo (emite pick). Lo usan el cuadro de «Nueva campaña»
  (Campaigns.vue, después de elegir Motor 2.0) y el asistente si llega sin tipo. El tipo ya no se cambia adentro.
-->
<script>
export const CAMPAIGN_KINDS = [
  'offer',
  'invite',
  'reactivate',
  'renew',
  'survey',
];

export default {
  name: 'CampaignKindPicker',
  emits: ['pick'],
  data() {
    return { kinds: CAMPAIGN_KINDS };
  },
};
</script>

<template>
  <div class="grid grid-cols-1 gap-3 sm:grid-cols-2">
    <button
      v-for="k in kinds"
      :key="k"
      type="button"
      class="flex flex-col gap-1 p-4 text-left border rounded-lg border-slate-100 dark:border-slate-700 hover:border-woot-400 hover:bg-woot-25 dark:hover:bg-woot-900/20"
      @click="$emit('pick', k)"
    >
      <span class="text-sm font-semibold text-slate-800 dark:text-slate-100">
        {{ $t(`CAMPAIGNS2.KINDS.${k}.TITLE`) }}
      </span>
      <span class="text-xs text-slate-600 dark:text-slate-300">
        {{ $t(`CAMPAIGNS2.KINDS.${k}.ABOUT`) }}
      </span>
    </button>
  </div>
</template>
