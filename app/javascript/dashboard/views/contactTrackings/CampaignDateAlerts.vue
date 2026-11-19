<!--
  fix/campanas — Avisos de las fechas de una campaña (ver campaignDates.js).
  Lo usan CampaignForm (al guardar) y CampaignLaunchModal (al poner en curso).
  Props: alerts — lo que regresa campaignDateAlerts().
-->
<script>
import { formatCampaignDate } from './campaignDates';

const LEVEL_CLASS = {
  error: 'text-red-600 dark:text-red-400',
  warning: 'text-amber-800 dark:text-amber-300',
  info: 'text-slate-600 dark:text-slate-300',
};
const LEVEL_ICON = { error: 'error-circle', warning: 'warning', info: 'info' };

export default {
  props: {
    alerts: { type: Array, default: () => [] },
  },
  computed: {
    items() {
      return this.alerts.map(alert => ({
        key: alert.key,
        icon: LEVEL_ICON[alert.level],
        className: LEVEL_CLASS[alert.level],
        text: this.$t(`TRACKING_CAMPAIGNS_VIEW.DATE_ALERTS.${alert.key}`, {
          date: alert.date ? formatCampaignDate(alert.date) : '',
          days: alert.days,
          hours: alert.hours,
        }),
      }));
    },
  },
};
</script>

<template>
  <ul class="flex flex-col gap-1 m-0 p-0 list-none">
    <li
      v-for="item in items"
      :key="item.key"
      class="flex items-start gap-1.5 text-sm"
      :class="item.className"
    >
      <fluent-icon :icon="item.icon" size="16" class="shrink-0 mt-0.5" />
      <span>{{ item.text }}</span>
    </li>
  </ul>
</template>
