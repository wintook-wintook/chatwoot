<!--
  Campaña con Vendedor IA — «Prueba real»: la campaña de verdad, solo a los contactos de prueba (tú o tu equipo), con
  los toques cada pocos minutos. Se ve en vivo qué salió, qué contestó y qué pasó (relevo, cita, no le interesa…).
  No cuenta en los resultados ni aparece en el listado. GET/POST/DELETE motor2_campaigns/:id/test_run.
-->
<script>
import { useAlert } from 'dashboard/composables';
import Motor2CampaignsAPI from 'dashboard/api/motor2Campaigns';

const POLL_MS = 10000;
const MAX_RECIPIENTS = 5;

export default {
  name: 'CampaignTestRun',
  props: {
    campaignId: { type: [Number, String], default: null },
    save: { type: Function, required: true },
    isWhatsapp: { type: Boolean, default: false },
    disabled: { type: Boolean, default: false },
  },
  data() {
    return {
      recipients: [''],
      everyMinutes: 3,
      state: { run: null, contacts: [] },
      busy: false,
      timer: null,
    };
  },
  computed: {
    running() {
      return this.state.run?.status === 'running';
    },
    canAdd() {
      return this.recipients.length < MAX_RECIPIENTS;
    },
  },
  watch: {
    campaignId: {
      immediate: true,
      handler(id) {
        if (id) this.refresh();
      },
    },
  },
  beforeDestroy() {
    clearTimeout(this.timer);
  },
  methods: {
    t(key, params) {
      return this.$t(`CAMPAIGNS2.TEST_RUN.${key}`, params);
    },
    async refresh() {
      clearTimeout(this.timer);
      if (!this.campaignId) return;
      try {
        const { data } = await Motor2CampaignsAPI.testRun(this.campaignId);
        this.state = data;
      } catch (e) {
        // sin prueba todavía
      }
      if (this.running) this.timer = setTimeout(this.refresh, POLL_MS);
    },
    // Un correo o un teléfono por renglón (según el canal de la campaña).
    recipientList() {
      return this.recipients
        .map(r => r.trim())
        .filter(Boolean)
        .map(r => (this.isWhatsapp ? { phone: r } : { email: r }));
    },
    async start() {
      const list = this.recipientList();
      if (!list.length) {
        useAlert(this.t('NEED_RECIPIENT'));
        return;
      }
      this.busy = true;
      try {
        if (!(await this.save())) return;
        const { data } = await Motor2CampaignsAPI.startTestRun(
          this.campaignId,
          list,
          this.everyMinutes
        );
        this.state = data;
        useAlert(this.t('STARTED'));
        this.refresh();
      } catch (e) {
        useAlert(e.response?.data?.error || this.t('ERROR'));
      } finally {
        this.busy = false;
      }
    },
    async stop() {
      this.busy = true;
      try {
        const { data } = await Motor2CampaignsAPI.stopTestRun(this.campaignId);
        this.state = data;
      } finally {
        this.busy = false;
      }
    },
    time(value) {
      return value
        ? new Date(value).toLocaleTimeString([], {
            hour: '2-digit',
            minute: '2-digit',
          })
        : '';
    },
    statusText(c) {
      if (c.status === 'skipped') {
        const key = `TRACKING_CAMPAIGN_DETAIL.ENTRIES.REASON.${c.reason}`;
        return this.t('SKIPPED', {
          reason: this.$te(key) ? this.$t(key) : c.reason,
        });
      }
      const tr = c.tracking;
      if (!tr) return '';
      const base = this.t(`STATUS.${tr.status}`, {
        n: tr.attempt,
        total: tr.attempts,
      });
      const next = tr.next_at
        ? this.t('NEXT', { at: this.time(tr.next_at) })
        : '';
      return [base, next].filter(Boolean).join(' · ');
    },
    conversationPath(c) {
      const id = c.tracking?.conversation_id;
      return id
        ? `/app/accounts/${this.$route.params.accountId}/conversations/${id}`
        : null;
    },
  },
};
</script>

<template>
  <div class="flex flex-col gap-3">
    <p class="m-0 text-xs text-slate-600 dark:text-slate-300">
      {{ t('INTRO') }}
    </p>

    <div v-if="!running" class="flex flex-col gap-2">
      <label class="text-xs font-medium">
        {{ isWhatsapp ? t('PHONES') : t('EMAILS') }}
      </label>
      <div
        v-for="(r, i) in recipients"
        :key="i"
        class="flex items-center gap-2"
      >
        <input
          v-model="recipients[i]"
          :type="isWhatsapp ? 'tel' : 'email'"
          class="flex-1 !mb-0"
          :placeholder="
            isWhatsapp ? t('PHONE_PLACEHOLDER') : t('EMAIL_PLACEHOLDER')
          "
        />
        <button
          v-if="recipients.length > 1"
          type="button"
          class="text-xs text-slate-500 hover:text-red-600"
          :aria-label="t('REMOVE')"
          @click="recipients.splice(i, 1)"
        >
          <fluent-icon icon="dismiss" size="14" />
        </button>
      </div>
      <button
        v-if="canAdd"
        type="button"
        class="self-start text-xs text-woot-600 hover:underline"
        @click="recipients.push('')"
      >
        {{ t('ADD') }}
      </button>
      <label class="flex items-center gap-2 text-xs">
        {{ t('EVERY') }}
        <input
          v-model.number="everyMinutes"
          type="number"
          min="1"
          max="60"
          class="w-16 !mb-0"
        />
        {{ t('MINUTES') }}
      </label>
      <p class="m-0 text-[11px] text-slate-500">{{ t('NOTE') }}</p>
      <woot-button
        size="small"
        class="self-start"
        :is-loading="busy"
        :disabled="disabled"
        @click="start"
      >
        {{ state.run ? t('START_AGAIN') : t('START') }}
      </woot-button>
    </div>

    <div v-if="state.run" class="flex flex-col gap-2">
      <div class="flex items-center justify-between gap-2">
        <span class="text-xs font-medium">
          {{
            running
              ? t('RUNNING', {
                  at: time(state.run.started_at),
                  n: state.run.every_minutes,
                })
              : t('FINISHED', { at: time(state.run.started_at) })
          }}
        </span>
        <span class="flex gap-2">
          <button
            type="button"
            class="text-xs text-woot-600 hover:underline"
            @click="refresh"
          >
            {{ t('REFRESH') }}
          </button>
          <button
            v-if="running"
            type="button"
            class="text-xs text-red-600 hover:underline"
            :disabled="busy"
            @click="stop"
          >
            {{ t('STOP') }}
          </button>
        </span>
      </div>

      <div
        v-for="c in state.contacts"
        :key="c.contact_id"
        class="flex flex-col gap-1 p-2 border rounded-md border-slate-100 dark:border-slate-700"
      >
        <div class="flex items-center justify-between gap-2">
          <span class="text-sm font-medium">
            {{ c.name }}
            <span class="text-xs font-normal text-slate-500">
              {{ c.address }}
            </span>
          </span>
          <router-link
            v-if="conversationPath(c)"
            :to="conversationPath(c)"
            class="text-xs text-woot-600 hover:underline"
          >
            {{ t('OPEN') }}
          </router-link>
        </div>
        <p class="m-0 text-xs text-slate-600 dark:text-slate-300">
          {{ statusText(c) }}
        </p>
        <p
          v-if="c.tracking && c.tracking.error"
          class="m-0 text-xs text-red-600"
        >
          {{ c.tracking.error }}
        </p>
        <div
          v-for="m in c.messages"
          :key="m.id"
          class="max-w-[90%] px-2 py-1 text-xs rounded-md whitespace-pre-line"
          :class="{
            'self-start bg-slate-50 dark:bg-slate-700': m.kind === 'outgoing',
            'self-end bg-woot-50 dark:bg-woot-800': m.kind === 'incoming',
            'self-stretch max-w-none bg-amber-50 dark:bg-amber-900/30 text-amber-800 dark:text-amber-200':
              m.kind === 'note',
          }"
        >
          <span class="block text-[10px] text-slate-500">
            {{ t(`KIND.${m.kind}`) }} · {{ time(m.at) }}
          </span>
          {{ m.content }}
        </div>
      </div>
    </div>
  </div>
</template>
