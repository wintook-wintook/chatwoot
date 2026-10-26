<!--
  Plan-Trabajo-Campo R5 — en el reporte de servicio: el portal del cliente
  (enlace, si confirmó la visita o pidió otra fecha, y su calificación) y el
  técnico externo (enlace sin usuario que sirve hasta terminar la visita).
-->
<script>
import { useAlert } from 'dashboard/composables';
import ServiceReportsAPI from 'dashboard/api/serviceReports';
import { copyTextToClipboard } from 'shared/helpers/clipboard';

export default {
  name: 'FieldPortalCard',
  props: {
    ticket: { type: Object, required: true },
    report: { type: Object, required: true },
    frozen: { type: Boolean, default: false },
  },
  emits: ['report'],
  data() {
    return { showForm: false, name: '', phone: '', busy: false };
  },
  computed: {
    response() {
      return this.report.visit_response;
    },
    external() {
      return this.report.external;
    },
    stars() {
      const n = this.report.csat?.rating || 0;
      return '★'.repeat(n) + '☆'.repeat(5 - n);
    },
    whatsappUrl() {
      if (!this.external?.url) return '';
      const text = this.$t('FIELD.EXTERNAL.WHATSAPP', {
        name: this.external.name,
        folio: this.ticket.folio,
        title: this.ticket.title,
        url: this.external.url,
      });
      const phone = (this.external.phone || '').replace(/\D/g, '');
      return `https://wa.me/${phone}?text=${encodeURIComponent(text)}`;
    },
  },
  methods: {
    async copy(url) {
      await copyTextToClipboard(url);
      useAlert(this.$t('FIELD.PORTAL.COPIED'));
    },
    open(url) {
      window.open(url, '_blank', 'noopener');
    },
    async run(request) {
      this.busy = true;
      try {
        const { data } = await request();
        this.$emit('report', data.service_report);
        return true;
      } catch (error) {
        useAlert(
          error?.response?.data?.error || this.$t('SERVICE_REPORT.ERROR')
        );
        return false;
      } finally {
        this.busy = false;
      }
    },
    async issue() {
      const ok = await this.run(() =>
        ServiceReportsAPI.externalLink(this.ticket.id, {
          name: this.name,
          phone: this.phone,
        })
      );
      if (ok) this.showForm = false;
    },
    revoke() {
      return this.run(() =>
        ServiceReportsAPI.revokeExternalLink(this.ticket.id)
      );
    },
    date(value) {
      return new Date(value).toLocaleString(undefined, {
        day: 'numeric',
        month: 'short',
        hour: '2-digit',
        minute: '2-digit',
      });
    },
  },
};
</script>

<template>
  <section
    class="grid gap-4 p-4 text-sm bg-white border rounded-lg md:grid-cols-2 dark:bg-slate-800 border-slate-75 dark:border-slate-700"
  >
    <!-- Portal del cliente -->
    <div class="flex flex-col gap-2">
      <div class="flex items-center justify-between gap-2">
        <h3
          class="m-0 text-sm font-semibold text-slate-700 dark:text-slate-200"
        >
          {{ $t('FIELD.PORTAL.TITLE') }}
        </h3>
        <div class="flex gap-1">
          <woot-button
            size="tiny"
            variant="smooth"
            color-scheme="secondary"
            icon="copy"
            @click="copy(report.portal_url)"
          >
            {{ $t('FIELD.PORTAL.COPY') }}
          </woot-button>
          <woot-button
            size="tiny"
            variant="smooth"
            color-scheme="secondary"
            icon="open"
            @click="open(report.portal_url)"
          />
        </div>
      </div>
      <p class="m-0 text-xs text-slate-500">{{ $t('FIELD.PORTAL.HELP') }}</p>
      <p
        v-if="response && response.status === 'confirmed'"
        class="px-2 py-1 m-0 text-green-800 rounded bg-green-50 dark:bg-green-900/30 dark:text-green-200"
      >
        {{ $t('FIELD.PORTAL.CONFIRMED', { date: date(response.at) }) }}
      </p>
      <p
        v-else-if="response && response.status === 'reschedule'"
        class="px-2 py-1 m-0 text-yellow-900 rounded bg-yellow-50 dark:bg-yellow-900/30 dark:text-yellow-200"
      >
        {{
          $t('FIELD.PORTAL.RESCHEDULE', {
            preferred: response.preferred || '—',
          })
        }}
        <span v-if="response.note" class="block text-xs">{{
          response.note
        }}</span>
      </p>
      <p v-if="report.csat" class="m-0">
        <span class="text-amber-500">{{ stars }}</span>
        <span v-if="report.csat.comment" class="ml-1 text-slate-600">
          {{ report.csat.comment }}
        </span>
      </p>
    </div>

    <!-- Técnico externo -->
    <div class="flex flex-col gap-2">
      <div class="flex items-center justify-between gap-2">
        <h3
          class="m-0 text-sm font-semibold text-slate-700 dark:text-slate-200"
        >
          {{ $t('FIELD.EXTERNAL.TITLE') }}
        </h3>
        <woot-button
          v-if="!showForm && !(external && external.active)"
          size="tiny"
          variant="smooth"
          icon="person"
          :disabled="frozen || busy"
          @click="showForm = true"
        >
          {{ $t('FIELD.EXTERNAL.NEW') }}
        </woot-button>
      </div>
      <p class="m-0 text-xs text-slate-500">{{ $t('FIELD.EXTERNAL.HELP') }}</p>
      <form
        v-if="showForm"
        class="grid grid-cols-2 gap-2"
        @submit.prevent="issue"
      >
        <input
          v-model="name"
          type="text"
          class="!mb-0"
          required
          :placeholder="$t('FIELD.EXTERNAL.NAME')"
        />
        <input
          v-model="phone"
          type="tel"
          class="!mb-0"
          :placeholder="$t('FIELD.EXTERNAL.PHONE')"
        />
        <div class="flex justify-end col-span-2 gap-2">
          <button
            type="button"
            class="button clear small"
            @click="showForm = false"
          >
            {{ $t('MAINTENANCE.CANCEL') }}
          </button>
          <woot-button size="small" :is-loading="busy">
            {{ $t('FIELD.EXTERNAL.CREATE') }}
          </woot-button>
        </div>
      </form>
      <div v-else-if="external && external.active" class="flex flex-col gap-1">
        <p class="m-0 text-slate-700 dark:text-slate-200">
          {{ external.name }}
          <span v-if="external.phone" class="text-slate-500">
            · {{ external.phone }}
          </span>
        </p>
        <p class="m-0 text-xs text-slate-500">
          {{
            $t('FIELD.EXTERNAL.EXPIRES', { date: date(external.expires_at) })
          }}
        </p>
        <div class="flex flex-wrap gap-1">
          <woot-button
            size="tiny"
            variant="smooth"
            color-scheme="secondary"
            icon="copy"
            @click="copy(external.url)"
          >
            {{ $t('FIELD.PORTAL.COPY') }}
          </woot-button>
          <woot-button
            v-if="external.phone"
            size="tiny"
            variant="smooth"
            icon="whatsapp"
            @click="open(whatsappUrl)"
          >
            {{ $t('FIELD.EXTERNAL.SEND_WHATSAPP') }}
          </woot-button>
          <woot-button
            size="tiny"
            variant="clear"
            color-scheme="alert"
            :disabled="busy"
            @click="revoke"
          >
            {{ $t('FIELD.EXTERNAL.REVOKE') }}
          </woot-button>
        </div>
      </div>
      <p v-else-if="external" class="m-0 text-xs text-slate-500">
        {{ $t('FIELD.EXTERNAL.USED', { name: external.name }) }}
      </p>
    </div>
  </section>
</template>
