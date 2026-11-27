<!--
  diag/waba F2 — pestaña «Diagnóstico» de una bandeja de WhatsApp Cloud (solo administradores).
  Muestra el último diagnóstico y lo vuelve a correr con un botón (D2). Cada revisión trae su
  estado (ok / warn / fail / unknown), texto, detalle y acción:
    subscribe   → «Suscribir ahora» con confirmación en línea (D4)
    reconnect / update_token → «Cambiar token» (lleva a la pestaña Configuración; F3: Reconectar)
    open_meta   → abre WhatsApp Manager de Meta
-->
<script>
import { format, parseISO } from 'date-fns';
import { useAlert } from 'dashboard/composables';
import { copyTextToClipboard } from 'shared/helpers/clipboard';
import SettingsSection from 'dashboard/components/SettingsSection.vue';
import WhatsappHealthAPI from 'dashboard/api/whatsappHealth';
import WhatsappReauthorize from '../channels/whatsapp/Reauthorize.vue';

const T = 'WHATSAPP_HEALTH';
const GROUPS = ['receive', 'send', 'system'];
const META_URL = 'https://business.facebook.com/wa/manage/home/';
const STATUS_MARK = { ok: '✓', warn: '⚠', fail: '✗', unknown: '?' };
const STATUS_UI = {
  ok: { icon: 'checkmark-circle', color: 'text-green-600 dark:text-green-400' },
  warn: { icon: 'warning', color: 'text-amber-600 dark:text-amber-400' },
  fail: { icon: 'dismiss-circle', color: 'text-ruby-600 dark:text-ruby-400' },
  unknown: { icon: 'info', color: 'text-slate-400' },
};

export default {
  name: 'WhatsappHealthPage',
  components: { SettingsSection, WhatsappReauthorize },
  props: {
    inbox: { type: Object, required: true },
  },
  emits: ['goToTab'],
  data() {
    return {
      result: { checked_at: null, checks: [] },
      loading: true,
      running: false,
      subscribeAsk: false,
      subscribing: false,
      metaUrl: META_URL,
    };
  },
  computed: {
    groups() {
      return GROUPS.map(key => ({
        key,
        title: this.t(`GROUPS.${key.toUpperCase()}`),
        checks: this.result.checks.filter(c => c.group === key),
      })).filter(g => g.checks.length);
    },
    lastRun() {
      if (!this.result.checked_at) return '';
      return this.t('LAST', {
        date: format(parseISO(this.result.checked_at), 'dd/MM/yyyy HH:mm'),
      });
    },
    // F3 — si la app de Meta del sistema está mal, «Reconectar con Meta» no sirve (R0).
    appBroken() {
      return this.result.checks.some(
        c => c.key === 'app' && c.status === 'fail'
      );
    },
    // Pedido del usuario: reconectar siempre se puede; el texto dice si hace falta o no.
    reconnectState() {
      if (!this.result.checks.length) return 'UNKNOWN';
      const failed = key =>
        this.result.checks.some(c => c.key === key && c.status === 'fail');
      return failed('token') || failed('reauthorization')
        ? 'NEEDED'
        : 'NOT_NEEDED';
    },
    reconnectHint() {
      return this.t(`RECONNECT.STATE.${this.reconnectState}`);
    },
    summary() {
      const count = status =>
        this.result.checks.filter(c => c.status === status).length;
      const fail = count('fail');
      const warn = count('warn');
      if (!this.result.checks.length) return '';
      return fail || warn
        ? this.t('SUMMARY_ISSUES', { fail, warn })
        : this.t('SUMMARY_OK');
    },
  },
  mounted() {
    this.loadLast();
  },
  methods: {
    t(key, params) {
      return this.$t(`${T}.${key}`, params);
    },
    ui(status) {
      return STATUS_UI[status] || STATUS_UI.unknown;
    },
    statusLabel(status) {
      return this.t(`STATUS.${(status || 'unknown').toUpperCase()}`);
    },
    async loadLast() {
      this.loading = true;
      try {
        const { data } = await WhatsappHealthAPI.last(this.inbox.id);
        this.result = data;
      } catch {
        this.result = { checked_at: null, checks: [] };
      } finally {
        this.loading = false;
      }
    },
    async run() {
      this.running = true;
      try {
        const { data } = await WhatsappHealthAPI.run(this.inbox.id);
        this.result = data;
      } catch {
        useAlert(this.t('ERROR'));
      } finally {
        this.running = false;
      }
    },
    reconnectNow() {
      this.$refs.reconnect.start();
    },
    // D8 — texto para pegar en el reporte a soporte.
    reportText() {
      const lines = [
        this.t('REPORT.HEADER', {
          name: this.inbox.name || '',
          phone: this.inbox.phone_number || '',
          id: this.inbox.id,
        }),
        this.lastRun,
      ];
      this.groups.forEach(group => {
        lines.push('', group.title.toUpperCase());
        group.checks.forEach(check => {
          lines.push(`${STATUS_MARK[check.status] || '?'} ${check.title}`);
          if (check.detail) lines.push(`   ${check.detail}`);
          (check.lines || []).forEach(line => lines.push(`   · ${line}`));
        });
      });
      return lines.join('\n');
    },
    async copyReport() {
      await copyTextToClipboard(this.reportText());
      useAlert(this.t('REPORT.COPIED'));
    },
    async subscribe() {
      this.subscribing = true;
      try {
        const { data } = await WhatsappHealthAPI.subscribe(this.inbox.id);
        this.result = data;
        this.subscribeAsk = false;
        useAlert(this.t('ACTIONS.SUBSCRIBE_DONE'));
      } catch (error) {
        useAlert(error?.response?.data?.error || this.t('ERROR'));
      } finally {
        this.subscribing = false;
      }
    },
  },
};
</script>

<template>
  <div class="mx-8">
    <SettingsSection :title="t('TITLE')" :sub-title="t('SUBTITLE')">
      <div class="flex flex-wrap items-center gap-3 mb-4">
        <woot-button
          :is-loading="running"
          icon="arrow-clockwise"
          data-test="health-run"
          @click="run"
        >
          {{ running ? t('RUNNING') : t('RUN') }}
        </woot-button>
        <woot-button
          v-if="result.checks.length"
          variant="smooth"
          icon="copy"
          data-test="health-copy"
          @click="copyReport"
        >
          {{ t('REPORT.COPY') }}
        </woot-button>
        <span class="text-sm text-slate-500 dark:text-slate-400">
          {{ lastRun }}
        </span>
        <span
          v-if="summary"
          class="text-sm font-medium text-slate-700 dark:text-slate-200"
          data-test="health-summary"
        >
          {{ summary }}
        </span>
      </div>

      <p
        v-if="!loading && !result.checks.length && !running"
        class="text-sm text-slate-500 dark:text-slate-400"
      >
        {{ t('NEVER') }}
      </p>

      <div
        v-for="group in groups"
        :key="group.key"
        class="mb-5"
        :data-test="'health-group-' + group.key"
      >
        <h3
          class="mb-2 text-xs font-semibold tracking-wide uppercase text-slate-500 dark:text-slate-400"
        >
          {{ group.title }}
        </h3>
        <ul
          class="p-0 m-0 list-none border rounded-lg border-slate-100 dark:border-slate-700"
        >
          <li
            v-for="check in group.checks"
            :key="check.key"
            class="flex gap-3 px-3 py-2.5 border-b last:border-b-0 border-slate-100 dark:border-slate-700"
            :data-test="'health-check-' + check.key"
          >
            <fluent-icon
              :icon="ui(check.status).icon"
              size="18"
              class="flex-shrink-0 mt-0.5"
              :class="ui(check.status).color"
              :title="statusLabel(check.status)"
            />
            <div class="flex-1 min-w-0">
              <p class="m-0 text-sm text-slate-800 dark:text-slate-100">
                {{ check.title }}
              </p>
              <p
                v-if="check.detail"
                class="m-0 mt-0.5 text-xs text-slate-500 dark:text-slate-400"
              >
                {{ check.detail }}
              </p>
              <ul
                v-if="check.lines && check.lines.length"
                class="pl-4 m-0 mt-1 text-xs list-disc text-slate-600 dark:text-slate-300"
              >
                <li v-for="line in check.lines" :key="line">{{ line }}</li>
              </ul>

              <!-- D4 — confirmación en línea -->
              <div
                v-if="check.action === 'subscribe' && subscribeAsk"
                class="flex flex-col gap-2 p-2 mt-2 text-sm border rounded-md border-slate-200 dark:border-slate-600"
              >
                <p class="m-0 text-slate-700 dark:text-slate-200">
                  {{ t('ACTIONS.SUBSCRIBE_CONFIRM') }}
                </p>
                <div class="flex gap-2">
                  <woot-button
                    size="small"
                    :is-loading="subscribing"
                    data-test="health-subscribe-yes"
                    @click="subscribe"
                  >
                    {{ t('ACTIONS.SUBSCRIBE_YES') }}
                  </woot-button>
                  <woot-button
                    size="small"
                    variant="clear"
                    @click="subscribeAsk = false"
                  >
                    {{ t('ACTIONS.CANCEL') }}
                  </woot-button>
                </div>
              </div>
            </div>
            <div class="flex-shrink-0">
              <woot-button
                v-if="check.action === 'subscribe' && !subscribeAsk"
                size="small"
                variant="smooth"
                data-test="health-subscribe"
                @click="subscribeAsk = true"
              >
                {{ t('ACTIONS.SUBSCRIBE') }}
              </woot-button>
              <div
                v-else-if="
                  check.action === 'reconnect' ||
                  check.action === 'update_token'
                "
                class="flex flex-col items-end gap-1"
              >
                <!-- F3 — abre la sección de reconexión (una sola instancia de la ventana de Meta) -->
                <woot-button
                  v-if="check.action === 'reconnect'"
                  size="small"
                  variant="smooth"
                  data-test="health-reconnect"
                  @click="reconnectNow"
                >
                  {{ t('RECONNECT.BUTTON') }}
                </woot-button>
                <woot-button
                  size="small"
                  variant="clear"
                  data-test="health-update-token"
                  @click="$emit('goToTab', 'configuration')"
                >
                  {{ t('ACTIONS.UPDATE_TOKEN') }}
                </woot-button>
              </div>
              <a
                v-else-if="check.action === 'open_meta'"
                :href="metaUrl"
                target="_blank"
                rel="noopener noreferrer"
                class="inline-flex items-center gap-1 text-sm text-woot-600 hover:underline"
                data-test="health-open-meta"
              >
                {{ t('ACTIONS.OPEN_META') }}
                <fluent-icon icon="open" size="12" />
              </a>
            </div>
          </li>
        </ul>
      </div>
    </SettingsSection>

    <!-- Pedido del usuario: reconectar siempre disponible, con mensaje si no hace falta -->
    <SettingsSection
      :title="t('RECONNECT.SECTION_TITLE')"
      :sub-title="reconnectHint"
    >
      <div
        class="flex flex-wrap items-start gap-3"
        :data-test="'health-reconnect-' + reconnectState.toLowerCase()"
      >
        <WhatsappReauthorize
          ref="reconnect"
          :inbox="inbox"
          :app-broken="appBroken"
          @reconnected="run"
        />
        <woot-button
          size="small"
          variant="clear"
          @click="$emit('goToTab', 'configuration')"
        >
          {{ t('ACTIONS.UPDATE_TOKEN') }}
        </woot-button>
      </div>
    </SettingsSection>
  </div>
</template>
