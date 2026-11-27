<!--
  Campaña con Vendedor IA (Motor 2.0) — el tablero de una campaña: embudo hasta lo ganado, lo que hizo el vendedor
  (relevo, citas, no le interesa), resultados por tipo (invitación, encuesta), «Qué dicen los contactos» con IA y
  acciones: ver los de cada grupo, armar otra campaña con ellos, pausar/reanudar, duplicar y modificar.
  Ruta: tracking-dashboard/campaigns2/:campaignId.
-->
<script>
import { useAlert } from 'dashboard/composables';
import Motor2CampaignsAPI from 'dashboard/api/motor2Campaigns';
import TrackingCampaignsAPI from 'dashboard/api/trackingCampaigns';

const REFRESH_MS = 60000;
const OUTCOME_KEYS = [
  'relayed',
  'discarded',
  'handed_off',
  'objective_met',
  'opted_out',
  'campaign_ended',
  'campaign_finished',
  'Cita',
  'Encuesta contestada',
  'later',
];
// Las salidas que se pueden abrir para ver sus contactos (Motor2Results::GROUPS).
const EXIT_GROUPS = [
  'not_interested',
  'no_reply',
  'auto_replied',
  'in_progress',
  'failed',
  'bounced',
];

const FOLLOW_GROUPS = [
  'not_read',
  'no_reply',
  'clicked',
  'interested',
  'not_interested',
];

export default {
  name: 'CampaignResults',
  data() {
    return {
      EXIT_GROUPS,
      timer: null,
      data: null,
      loading: true,
      group: null,
      groupContacts: [],
      groupLoading: false,
      insights: null,
      insightsLoading: false,
      busy: false,
      confirmFinish: false,
    };
  },
  computed: {
    id() {
      return Number(this.$route.params.campaignId);
    },
    campaign() {
      return this.data?.campaign || {};
    },
    funnel() {
      return this.data?.funnel || {};
    },
    isWhatsapp() {
      return this.data?.channel === 'whatsapp';
    },
    // El embudo, con el % sobre lo enviado.
    steps() {
      const f = this.funnel;
      const rows = [
        ['enrolled', f.enrolled, null],
        ['sent', f.sent, null],
        ['delivered', f.delivered, null],
        this.isWhatsapp
          ? ['read', f.read, 'not_read']
          : ['clicked', f.clicked, 'clicked'],
        ['replied', f.replied, 'replied'],
        ['interested', f.interested, 'interested'],
        ['relayed', f.relayed, 'relayed'],
        ['appointment', f.appointment, 'appointment'],
        ['quotes', f.quotes, null],
        ['won', f.won, null],
      ];
      const base = f.sent || 0;
      return rows.map(([key, value, group]) => ({
        key,
        value: value || 0,
        group,
        pct:
          base && !['enrolled', 'sent'].includes(key)
            ? Math.round(((value || 0) * 100) / base)
            : null,
      }));
    },
    exits() {
      return this.data?.exits || {};
    },
    // El objetivo (TrackingCampaigns::CampaignKit): lo lograron, no esta vez, aceptan la próxima, no quieren.
    goalCards() {
      const g = this.data?.goal;
      if (!g) return [];
      const labels = g.labels || {};
      return [
        {
          key: 'achieved',
          value: g.achieved,
          group: 'achieved',
          label: labels.achieved,
        },
        { key: 'not_now', value: g.not_now, group: 'not_now' },
        {
          key: 'future_yes',
          value: g.future_yes,
          group: 'future_yes',
          label: labels.future_yes,
        },
        {
          key: 'opt_out',
          value: g.opt_out,
          group: 'not_interested',
          label: labels.opt_out,
        },
      ];
    },
    exitKeys() {
      const keys = [
        'not_interested',
        'no_reply',
        'in_progress',
        'handed_off',
        'opted_out',
      ];
      if (!this.isWhatsapp) keys.push('bounced');
      // Solo llegó la respuesta automática de su WhatsApp (no cuenta como que contestó).
      if (this.isWhatsapp) keys.push('auto_replied');
      return [...keys, 'failed'];
    },
    touchRows() {
      return this.data?.touches || [];
    },
    kindData() {
      return this.data?.kind || {};
    },
    kind() {
      return this.campaign.brief?.kind || 'offer';
    },
    money() {
      return this.data?.money || {};
    },
    followGroups() {
      return FOLLOW_GROUPS.filter(
        g => g !== (this.isWhatsapp ? 'clicked' : 'not_read')
      );
    },
    savedInsights() {
      return this.insights || this.campaign.brief?.insights?.points || [];
    },
  },
  mounted() {
    this.load();
  },
  beforeDestroy() {
    clearTimeout(this.timer);
  },
  methods: {
    t(key, params) {
      return this.$t(`CAMPAIGNS2.RESULTS.${key}`, params);
    },
    // En curso: se actualiza sola cada REFRESH_MS.
    async load() {
      clearTimeout(this.timer);
      this.loading = !this.data;
      try {
        const { data } = await Motor2CampaignsAPI.results(this.id);
        this.data = data;
      } catch (e) {
        useAlert(this.t('LOAD_ERROR'));
      } finally {
        this.loading = false;
      }
      if (this.data?.campaign?.status === 'running') {
        this.timer = setTimeout(this.load, REFRESH_MS);
      }
    },
    outcomeText(outcome) {
      if (!outcome) return '';
      // «relayed: Atención a prospectos», «Cita viernes 10:00»… → por cómo empieza.
      const text = String(outcome);
      const key = OUTCOME_KEYS.find(k => text.startsWith(k));
      return key ? this.$t(`CAMPAIGNS2.RESULTS.OUTCOMES.${key}`) : text;
    },
    money$(value) {
      return new Intl.NumberFormat('es-MX', {
        style: 'currency',
        currency: this.money.currency || 'MXN',
        maximumFractionDigits: 0,
      }).format(value || 0);
    },
    async openGroup(group) {
      if (!group) return;
      this.group = group;
      this.groupLoading = true;
      try {
        const { data } = await Motor2CampaignsAPI.contacts(this.id, group);
        this.groupContacts = data.contacts || [];
      } catch (e) {
        this.groupContacts = [];
        useAlert(this.t('LOAD_ERROR'));
      } finally {
        this.groupLoading = false;
        this.$nextTick(() =>
          this.$refs.groupBox?.scrollIntoView({ behavior: 'smooth' })
        );
      }
    },
    async followUp(group) {
      this.busy = true;
      try {
        const { data } = await Motor2CampaignsAPI.followUp(this.id, group);
        useAlert(this.t('FOLLOW_CREATED'));
        this.$router.push({
          name: 'campaigns2_edit',
          params: { campaignId: data.id },
        });
      } catch (e) {
        useAlert(e.response?.data?.error || this.t('ACTION_ERROR'));
      } finally {
        this.busy = false;
      }
    },
    async duplicate() {
      this.busy = true;
      try {
        const { data } = await Motor2CampaignsAPI.duplicate(this.id);
        this.$router.push({
          name: 'campaigns2_edit',
          params: { campaignId: data.id },
        });
      } finally {
        this.busy = false;
      }
    },
    async pauseOrResume() {
      this.busy = true;
      try {
        if (this.campaign.status === 'paused')
          await TrackingCampaignsAPI.resume(this.id);
        else await TrackingCampaignsAPI.pause(this.id);
        await this.load();
      } catch (e) {
        useAlert(e.response?.data?.error || this.t('ACTION_ERROR'));
      } finally {
        this.busy = false;
      }
    },
    // Terminar a mano: Terminada sin vuelta; lo que faltaba por salir se cancela; los Resultados se quedan.
    async finish() {
      this.confirmFinish = false;
      this.busy = true;
      try {
        const { data } = await TrackingCampaignsAPI.finish(this.id);
        useAlert(
          this.$t('TRACKING_CAMPAIGNS_VIEW.FINISH_SUCCESS', {
            count: data.cancelled,
          })
        );
        await this.load();
      } catch (e) {
        useAlert(e.response?.data?.error || this.t('ACTION_ERROR'));
      } finally {
        this.busy = false;
      }
    },
    async loadInsights() {
      this.insightsLoading = true;
      try {
        const { data } = await Motor2CampaignsAPI.insights(this.id);
        if (data.error) useAlert(data.error);
        this.insights = data.points || [];
      } finally {
        this.insightsLoading = false;
      }
    },
    openConversation(row) {
      if (!row.conversation_id) return;
      this.$router.push({
        name: 'inbox_conversation',
        params: { conversation_id: row.conversation_id },
      });
    },
  },
};
</script>

<template>
  <div class="flex flex-col w-full h-full min-h-0 p-4 overflow-y-auto">
    <div class="flex flex-wrap items-start justify-between gap-3 mb-4">
      <div class="flex items-start gap-2">
        <woot-sidemenu-icon />
        <div>
          <h1 class="m-0 text-xl font-bold text-slate-800 dark:text-slate-100">
            {{ campaign.name || t('TITLE') }}
          </h1>
          <p class="m-0 mt-1 text-sm text-slate-600 dark:text-slate-400">
            {{
              t('SUBTITLE', {
                status: $t(`CAMPAIGNS2.STATUS.${campaign.status || 'saved'}`),
                seller: campaign.seller_name || '—',
                channel: campaign.inbox_name || '—',
              })
            }}
          </p>
        </div>
      </div>
      <div class="flex flex-wrap gap-2">
        <woot-button
          variant="smooth"
          color-scheme="secondary"
          icon="chevron-left"
          @click="$router.push({ name: 'contact_trackings_campaigns' })"
        >
          {{ t('BACK') }}
        </woot-button>
        <woot-button
          v-if="campaign.status === 'saved'"
          icon="edit"
          @click="
            $router.push({
              name: 'campaigns2_edit',
              params: { campaignId: id },
            })
          "
        >
          {{ t('EDIT') }}
        </woot-button>
        <woot-button
          v-if="['running', 'draft', 'paused'].includes(campaign.status)"
          variant="smooth"
          :icon="campaign.status === 'paused' ? 'play' : 'pause'"
          :is-loading="busy"
          @click="pauseOrResume"
        >
          {{ campaign.status === 'paused' ? t('RESUME') : t('PAUSE') }}
        </woot-button>
        <woot-button
          v-if="
            ['saved', 'running', 'draft', 'paused'].includes(campaign.status)
          "
          variant="smooth"
          color-scheme="alert"
          icon="dismiss-circle"
          :is-loading="busy"
          @click="confirmFinish = true"
        >
          {{ t('FINISH') }}
        </woot-button>
        <woot-button
          variant="smooth"
          icon="copy"
          :is-loading="busy"
          @click="duplicate"
        >
          {{ t('DUPLICATE') }}
        </woot-button>
        <woot-button variant="clear" icon="arrow-clockwise" @click="load">
          {{ t('REFRESH') }}
        </woot-button>
      </div>
    </div>

    <p v-if="loading" class="text-sm text-slate-500">{{ t('LOADING') }}</p>
    <template v-else-if="data">
      <p
        v-if="campaign.paused_reason"
        class="p-3 mb-3 text-sm rounded-md text-amber-800 bg-amber-50 dark:bg-amber-900/20"
      >
        {{ t('PAUSED_REASON', { reason: campaign.paused_reason }) }}
      </p>

      <!-- Embudo -->
      <section class="mb-4">
        <h2
          class="m-0 mb-2 text-sm font-semibold text-slate-700 dark:text-slate-200"
        >
          {{ t('FUNNEL') }}
        </h2>
        <div class="grid grid-cols-2 gap-2 sm:grid-cols-5">
          <button
            v-for="s in steps"
            :key="s.key"
            type="button"
            class="p-3 text-left border rounded-lg border-slate-100 dark:border-slate-700"
            :class="{
              'hover:border-woot-300 cursor-pointer': s.group,
              'cursor-default': !s.group,
            }"
            @click="openGroup(s.group)"
          >
            <p
              class="m-0 text-2xl font-semibold text-slate-800 dark:text-slate-100"
            >
              {{ s.value }}
            </p>
            <p class="m-0 text-xs text-slate-500">
              {{ t(`STEPS.${s.key}`) }}
              <span v-if="s.pct !== null" class="text-woot-600">
                {{ t('PCT', { pct: s.pct }) }}
              </span>
            </p>
          </button>
        </div>
      </section>

      <!-- El objetivo: cómo terminaron y con qué etiqueta -->
      <section v-if="goalCards.length" class="mb-4">
        <h2
          class="m-0 mb-2 text-sm font-semibold text-slate-700 dark:text-slate-200"
        >
          {{ t('GOAL.TITLE') }}
        </h2>
        <div class="grid grid-cols-2 gap-2 sm:grid-cols-4">
          <button
            v-for="c in goalCards"
            :key="c.key"
            type="button"
            class="p-3 text-left border rounded-lg border-slate-100 dark:border-slate-700 hover:border-woot-300"
            @click="openGroup(c.group)"
          >
            <p
              class="m-0 text-2xl font-semibold text-slate-800 dark:text-slate-100"
            >
              {{ c.value || 0 }}
            </p>
            <p class="m-0 text-xs text-slate-500">{{ t(`GOAL.${c.key}`) }}</p>
            <p v-if="c.label" class="m-0 text-[11px] text-woot-600">
              {{ t('GOAL.LABEL', { label: c.label }) }}
            </p>
          </button>
        </div>
      </section>

      <!-- Por toque: a cuántos les salió cada toque y cuántos contestaron después de ese -->
      <section
        v-if="touchRows.length > 1"
        class="p-3 mb-4 border rounded-lg border-slate-100 dark:border-slate-700"
      >
        <h2 class="m-0 mb-2 text-sm font-semibold">{{ t('TOUCHES.TITLE') }}</h2>
        <table class="w-full text-sm">
          <thead>
            <tr class="text-xs text-left text-slate-500">
              <th class="py-1 font-normal">{{ t('TOUCHES.TOUCH') }}</th>
              <th class="py-1 font-normal">{{ t('TOUCHES.SENT') }}</th>
              <th class="py-1 font-normal">{{ t('TOUCHES.REPLIED') }}</th>
            </tr>
          </thead>
          <tbody>
            <tr
              v-for="row in touchRows"
              :key="row.n"
              class="border-t border-slate-50 dark:border-slate-700"
            >
              <td class="py-1">
                {{
                  row.n === 1
                    ? t('TOUCHES.OPENER')
                    : t('TOUCHES.N', { n: row.n - 1 })
                }}
              </td>
              <td class="py-1">{{ row.sent }}</td>
              <td class="py-1">
                {{ row.replied }}
                <span v-if="row.sent" class="text-xs text-slate-500">
                  ({{ Math.round((row.replied * 100) / row.sent) }}%)
                </span>
              </td>
            </tr>
          </tbody>
        </table>
        <p class="m-0 mt-1 text-xs text-slate-500">{{ t('TOUCHES.HINT') }}</p>
      </section>

      <div class="grid grid-cols-1 gap-4 lg:grid-cols-3">
        <!-- Lo ganado -->
        <section
          class="p-3 border rounded-lg border-slate-100 dark:border-slate-700"
        >
          <h2 class="m-0 mb-2 text-sm font-semibold">{{ t('MONEY') }}</h2>
          <p class="m-0 text-sm">
            {{
              t('QUOTED', {
                total: money$(money.quoted_total),
                n: funnel.quotes || 0,
              })
            }}
          </p>
          <p class="m-0 text-sm font-semibold text-green-700">
            {{
              t('WON', { total: money$(money.won_total), n: funnel.won || 0 })
            }}
          </p>
        </section>

        <!-- Salidas -->
        <section
          class="p-3 border rounded-lg border-slate-100 dark:border-slate-700"
        >
          <h2 class="m-0 mb-2 text-sm font-semibold">{{ t('EXITS') }}</h2>
          <component
            :is="EXIT_GROUPS.includes(key) ? 'button' : 'p'"
            v-for="key in exitKeys"
            :key="key"
            :type="EXIT_GROUPS.includes(key) ? 'button' : null"
            class="flex justify-between w-full m-0 text-sm text-left"
            :class="EXIT_GROUPS.includes(key) ? 'hover:text-woot-600' : ''"
            @click="EXIT_GROUPS.includes(key) && openGroup(key)"
          >
            <span>{{ t(`EXIT.${key}`) }}</span>
            <span class="font-medium">{{ exits[key] || 0 }}</span>
          </component>
          <p
            v-for="(count, reason) in exits.skipped || {}"
            :key="reason"
            class="flex justify-between m-0 text-xs text-slate-500"
          >
            <span>{{ t(`SKIPPED.${reason}`) }}</span>
            <span>{{ count }}</span>
          </p>
        </section>

        <!-- Por tipo -->
        <section
          class="p-3 border rounded-lg border-slate-100 dark:border-slate-700"
        >
          <h2 class="m-0 mb-2 text-sm font-semibold">
            {{ $t(`CAMPAIGNS2.KINDS.${kind}.TITLE`) }}
          </h2>
          <template v-if="kind === 'invite'">
            <p class="m-0 text-sm">{{ kindData.event_name }}</p>
            <button
              type="button"
              class="block text-sm"
              @click="openGroup('confirmed')"
            >
              {{
                t('CONFIRMED', {
                  n: kindData.confirmed || 0,
                  capacity: kindData.capacity || '—',
                })
              }}
            </button>
            <button
              type="button"
              class="block text-sm"
              @click="openGroup('declined')"
            >
              {{ t('DECLINED', { n: kindData.declined || 0 }) }}
            </button>
          </template>
          <template v-else-if="kind === 'survey'">
            <p class="m-0 text-sm">
              {{ t('ANSWERED', { n: kindData.answered || 0 }) }}
            </p>
            <p class="m-0 text-sm">
              {{
                t('AVERAGE', {
                  avg:
                    kindData.average === null || kindData.average === undefined
                      ? '—'
                      : kindData.average,
                })
              }}
            </p>
            <button
              type="button"
              class="block text-sm text-red-600"
              @click="openGroup('low_score')"
            >
              {{
                t('LOW', { n: kindData.low || 0, cases: kindData.cases || 0 })
              }}
            </button>
            <!-- NPS de la pregunta de 0 a 10 y comentarios de las abiertas (TrackingCampaigns::SurveyResults) -->
            <p v-if="kindData.nps" class="m-0 text-sm">
              {{
                t('NPS', {
                  score: kindData.nps.score,
                  promoters: kindData.nps.promoters,
                  passives: kindData.nps.passives,
                  detractors: kindData.nps.detractors,
                })
              }}
            </p>
            <details v-if="(kindData.comments || []).length" class="text-sm">
              <summary class="cursor-pointer text-woot-600">
                {{ t('COMMENTS', { n: kindData.comments.length }) }}
              </summary>
              <ul class="flex flex-col gap-1 pl-4 m-0 mt-1 list-disc">
                <li v-for="(c, i) in kindData.comments" :key="i">
                  <span class="font-medium">{{ c.contact || '—' }}:</span>
                  {{ c.answer }}
                  <span class="text-xs text-slate-500">({{ c.question }})</span>
                </li>
              </ul>
            </details>
          </template>
          <!-- Ofrecer y Reactivar: cada número abre su lista -->
          <template v-else-if="['offer', 'reactivate'].includes(kind)">
            <p v-if="kindData.what" class="m-0 text-sm text-slate-600">
              {{ kindData.what }}
            </p>
            <button
              v-for="key in [
                'interested',
                'relayed',
                'appointment',
                'achieved',
              ]"
              v-show="kindData[key]"
              :key="key"
              type="button"
              class="block text-sm"
              @click="openGroup(key)"
            >
              {{
                t('KIND_COUNT', { label: t(`GROUPS.${key}`), n: kindData[key] })
              }}
            </button>
            <p v-if="kindData.won" class="m-0 text-sm">
              {{
                t('KIND_WON', {
                  n: kindData.won,
                  total: money$(kindData.won_total),
                })
              }}
            </p>
          </template>
          <!-- Recordar: pagaron, sin pagar y lo que falta por cobrar -->
          <template v-else-if="kind === 'renew'">
            <button
              type="button"
              class="block text-sm"
              @click="openGroup('achieved')"
            >
              {{ t('KIND_PAID', { n: kindData.paid || 0 }) }}
            </button>
            <button
              type="button"
              class="block text-sm"
              @click="openGroup('unpaid')"
            >
              {{
                t('KIND_UNPAID', {
                  n: kindData.unpaid || 0,
                  total: money$(kindData.to_collect),
                })
              }}
            </button>
          </template>
          <p v-else class="m-0 text-sm text-slate-600">
            {{ campaign.brief && campaign.brief.offer_what }}
          </p>
        </section>
      </div>

      <!-- Lista fría de correos: limpieza, cuarentena y cuántos ya son contactos -->
      <section
        v-if="data.list"
        class="p-3 mt-4 border rounded-lg border-slate-100 dark:border-slate-700"
      >
        <h2 class="m-0 mb-1 text-sm font-semibold">
          {{ t('LIST_TITLE', { name: data.list.name }) }}
        </h2>
        <p class="m-0 text-sm">
          {{
            t('LIST_STATS', {
              rows: data.list.rows,
              valid: data.list.valid,
              existing: data.list.existing,
            })
          }}
        </p>
        <p
          v-for="(n, reason) in data.list.discarded"
          :key="reason"
          class="m-0 text-xs text-slate-500"
        >
          {{ $t(`CAMPAIGNS2.LIST.DISCARDED.${reason}`, { n }) }}
        </p>
        <p class="m-0 mt-1 text-sm text-green-700">
          {{ t('LIST_PROMOTED', { n: data.list.promoted }) }}
        </p>
        <p class="m-0 text-xs text-slate-500">
          {{
            data.list.cleaned_at
              ? t('LIST_CLEANED', { n: data.list.removed })
              : t('LIST_QUARANTINE', {
                  n: data.list.quarantined,
                  days: data.list.cleanup_days,
                })
          }}
        </p>
      </section>

      <!-- Qué dicen los contactos -->
      <section
        class="p-3 mt-4 border rounded-lg border-slate-100 dark:border-slate-700"
      >
        <div class="flex items-center justify-between gap-2">
          <h2 class="m-0 text-sm font-semibold">{{ t('INSIGHTS') }}</h2>
          <woot-button
            size="small"
            variant="smooth"
            icon="wand"
            :is-loading="insightsLoading"
            @click="loadInsights"
          >
            {{
              savedInsights.length ? t('INSIGHTS_REFRESH') : t('INSIGHTS_RUN')
            }}
          </woot-button>
        </div>
        <ul v-if="savedInsights.length" class="pl-5 m-0 mt-2 text-sm">
          <li v-for="(p, i) in savedInsights" :key="i">{{ p }}</li>
        </ul>
        <p v-else class="m-0 mt-2 text-xs text-slate-500">
          {{ t('INSIGHTS_EMPTY') }}
        </p>
        <template v-if="(data.reasons || []).length">
          <p class="m-0 mt-3 text-xs font-medium text-slate-600">
            {{ t('REASONS') }}
          </p>
          <ul class="pl-5 m-0 text-xs text-slate-600">
            <li v-for="(r, i) in data.reasons" :key="i">{{ r }}</li>
          </ul>
        </template>
      </section>

      <!-- Siguiente campaña con un grupo -->
      <section
        class="p-3 mt-4 border rounded-lg border-slate-100 dark:border-slate-700"
      >
        <h2 class="m-0 mb-2 text-sm font-semibold">{{ t('NEXT_CAMPAIGN') }}</h2>
        <div class="flex flex-wrap gap-2">
          <woot-button
            v-for="g in followGroups"
            :key="g"
            size="small"
            variant="smooth"
            color-scheme="secondary"
            :is-loading="busy"
            @click="followUp(g)"
          >
            {{ t(`FOLLOW.${g}`) }}
          </woot-button>
        </div>
      </section>

      <!-- Los de un grupo -->
      <section
        v-if="group"
        ref="groupBox"
        class="p-3 mt-4 border rounded-lg border-slate-100 dark:border-slate-700"
      >
        <div class="flex items-center justify-between gap-2 mb-2">
          <h2 class="m-0 text-sm font-semibold">
            {{
              t('GROUP_TITLE', {
                group: t(`GROUPS.${group}`),
                n: groupContacts.length,
              })
            }}
          </h2>
          <button
            type="button"
            class="text-xs text-woot-600"
            @click="group = null"
          >
            {{ t('CLOSE') }}
          </button>
        </div>
        <p v-if="groupLoading" class="m-0 text-xs text-slate-500">
          {{ t('LOADING') }}
        </p>
        <table v-else class="w-full text-sm">
          <tbody>
            <tr
              v-for="row in groupContacts"
              :key="row.contact_id"
              class="border-b cursor-pointer border-slate-50 dark:border-slate-700 hover:bg-slate-25"
              @click="openConversation(row)"
            >
              <td class="py-1">{{ row.name }}</td>
              <td class="py-1 text-xs text-slate-500">
                {{ isWhatsapp ? row.phone_number : row.email }}
              </td>
              <td class="py-1 text-xs text-slate-500">
                {{ outcomeText(row.outcome) }}
              </td>
            </tr>
          </tbody>
        </table>
      </section>
    </template>
    <woot-delete-modal
      :show="confirmFinish"
      :on-close="() => (confirmFinish = false)"
      :on-confirm="finish"
      :title="$t('TRACKING_CAMPAIGNS_VIEW.FINISH')"
      :message="$t('TRACKING_CAMPAIGNS_VIEW.FINISH_CONFIRM')"
      :message-value="campaign ? ` «${campaign.name}»?` : ''"
      :confirm-text="$t('TRACKING_CAMPAIGNS_VIEW.FINISH_YES')"
      :reject-text="$t('TRACKING_CAMPAIGNS_VIEW.DELETE_NO')"
    />
  </div>
</template>
