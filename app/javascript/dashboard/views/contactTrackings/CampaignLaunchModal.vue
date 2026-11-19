<!--
  ================================================================================
  fix/campanas — Confirmar «Poner en curso» una campaña Guardada
  ================================================================================
  Antes de ponerla en curso enseña su ventana (empieza / termina) y los avisos de
  sus fechas (campaignDates.js): inicio que ya pasó, ventana corta, fin cercano…
  Si la ventana ya terminó no deja confirmar (TrackingCampaigns::Launch la rechazaría).
  Lo usan la tabla de campañas (Campaigns.vue) y el detalle (CampaignDetail.vue).

  Props:  campaign (la Guardada a confirmar; null = cerrado)
  Emits:  close · confirm
  ================================================================================
-->
<script>
import CampaignDateAlerts from './CampaignDateAlerts.vue';
import {
  campaignDateAlerts,
  formatCampaignDate,
  hasDateError,
} from './campaignDates';

export default {
  components: { CampaignDateAlerts },
  props: {
    campaign: { type: Object, default: null },
  },
  emits: ['close', 'confirm'],
  computed: {
    show() {
      return !!this.campaign;
    },
    alerts() {
      if (!this.campaign) return [];
      return campaignDateAlerts({
        scheduledFor: this.campaign.scheduled_for,
        endsAt: this.campaign.ends_at,
      });
    },
    blocked() {
      return hasDateError(this.alerts);
    },
    message() {
      if (!this.campaign) return '';
      return `${this.$t('TRACKING_CAMPAIGNS_VIEW.LAUNCH_CONFIRM')} «${
        this.campaign.name
      }»?`;
    },
    windowText() {
      if (!this.campaign) return '';
      const { scheduled_for: start, ends_at: end } = this.campaign;
      const startsInFuture = start && new Date(start) > new Date();
      return this.$t('TRACKING_CAMPAIGNS_VIEW.LAUNCH_WINDOW', {
        from: startsInFuture
          ? formatCampaignDate(start)
          : this.$t('TRACKING_CAMPAIGNS_VIEW.LAUNCH_NOW'),
        to: end
          ? formatCampaignDate(end)
          : this.$t('TRACKING_CAMPAIGNS_VIEW.NO_END'),
      });
    },
  },
};
</script>

<template>
  <woot-modal :show="show" :on-close="() => $emit('close')">
    <div class="flex flex-col h-auto overflow-auto">
      <woot-modal-header
        :header-title="$t('TRACKING_CAMPAIGNS_VIEW.LAUNCH')"
        :header-content="message"
      />
      <div class="flex flex-col gap-3 px-8 pt-4">
        <p class="m-0 text-sm font-medium text-slate-700 dark:text-slate-200">
          {{ windowText }}
        </p>
        <CampaignDateAlerts :alerts="alerts" />
      </div>
      <div class="flex items-center justify-end gap-2 p-8">
        <woot-button variant="clear" @click="$emit('close')">
          {{ $t('TRACKING_CAMPAIGNS_VIEW.DELETE_NO') }}
        </woot-button>
        <woot-button
          icon="send"
          :is-disabled="blocked"
          @click="$emit('confirm')"
        >
          {{ $t('TRACKING_CAMPAIGNS_VIEW.LAUNCH_YES') }}
        </woot-button>
      </div>
    </div>
  </woot-modal>
</template>
