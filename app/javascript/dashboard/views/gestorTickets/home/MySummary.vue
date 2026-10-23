<!--
  @tickets_cases — «Mi resumen» (página Inicio): ¿qué tengo que hacer hoy?
  Donde aterriza cada usuario al iniciar sesión (salvo que en su perfil elija otra
  página). Junta lo que ya existe: avisos importantes, lo más urgente de Mi día,
  la agenda de hoy, mis conversaciones que esperan respuesta, mis casos (SLA,
  etapas listas, promesas de pago de la semana) y mis números de la semana. Cada
  bloque lleva a su pantalla y, si no tiene nada, no se muestra. El dueño también
  es usuario: desde aquí entra al Resumen del negocio.
-->
<script>
import { mapGetters } from 'vuex';
import CaseTasksAPI from 'dashboard/api/caseTasks';
import MySummaryAPI from 'dashboard/api/mySummary';
import { localDay, visibleReasons } from 'dashboard/helper/caseTaskPriority';
import { formatDay } from 'dashboard/helper/caseCommercial';
import MyDayNotices from '../tasks/MyDayNotices.vue';

const T = 'CASE_TICKETS.HOME';
const TOP_TASKS = 5;

export default {
  name: 'MySummary',
  components: { MyDayNotices },
  data() {
    return {
      isLoading: true,
      tasks: [],
      agenda: [],
      summary: null,
    };
  },
  computed: {
    ...mapGetters({
      currentUser: 'getCurrentUser',
      canViewBusinessSummary: 'caseTickets/getCanViewBusinessSummary',
      isFeatureEnabledonAccount: 'accounts/isFeatureEnabledonAccount',
      getAccount: 'accounts/getAccount',
    }),
    accountLoaded() {
      return !!this.getAccount(this.accountId)?.features;
    },
    accountId() {
      return this.$route.params.accountId;
    },
    hasCases() {
      return this.isFeatureEnabledonAccount(this.accountId, 'case_management');
    },
    greeting() {
      const h = new Date().getHours();
      let key = 'EVENING';
      if (h < 12) key = 'MORNING';
      else if (h < 19) key = 'AFTERNOON';
      const name = (this.currentUser.name || '').split(' ')[0];
      return this.t(`GREETING.${key}`, { name });
    },
    conversations() {
      return (this.summary && this.summary.conversations) || {};
    },
    cases() {
      return (this.summary && this.summary.cases) || {};
    },
    hasCaseBlock() {
      const c = this.cases;
      return (
        (c.sla || []).length ||
        (c.ready || []).length ||
        (c.promises || []).length
      );
    },
    weekRows() {
      const w = this.summary && this.summary.week;
      if (!w) return [];
      return ['cases_done', 'tasks_done', 'won']
        .map(key => ({
          key,
          now: w.this_week[key] || 0,
          before: w.last_week[key] || 0,
        }))
        .filter(r => r.key !== 'won' || r.now || r.before);
    },
  },
  watch: {
    // Sin el módulo de casos, «Inicio» no tiene sentido: a Conversaciones.
    accountLoaded: {
      immediate: true,
      handler(loaded) {
        if (!loaded) return;
        if (!this.hasCases) this.$router.replace({ name: 'home' });
        else this.load();
      },
    },
  },
  mounted() {
    this.$store.dispatch('caseTickets/fetchSettings');
  },
  methods: {
    t(key, params) {
      return this.$t(`${T}.${key}`, params);
    },
    async load() {
      this.isLoading = true;
      try {
        const [summary, myDay] = await Promise.all([
          MySummaryAPI.get(),
          CaseTasksAPI.getMine({
            mode: 'my_day',
            assignee_id: this.currentUser.id,
            page: 1,
            day: localDay(),
          }),
        ]);
        this.summary = summary.data;
        this.tasks = (myDay.data.case_tasks || [])
          .filter(r => r.item_type === 'task')
          .slice(0, TOP_TASKS);
        this.agenda = (myDay.data.meta && myDay.data.meta.agenda) || [];
      } finally {
        this.isLoading = false;
      }
    },
    reasons(row) {
      return visibleReasons(row.reasons).slice(0, 2);
    },
    reasonLabel(reason) {
      const base = 'CASE_TICKETS.TASKS.MY_DAY.REASONS';
      if (reason.key === 'overdue' && !reason.days) {
        return this.$t(`${base}.overdue_today`);
      }
      return this.$t(`${base}.${reason.key}`, {
        days: reason.days,
        date: reason.date ? formatDay(reason.date) : '',
      });
    },
    hour(value) {
      if (!value) return '';
      return new Date(value).toLocaleTimeString([], {
        hour: '2-digit',
        minute: '2-digit',
      });
    },
    waitingFor(ts) {
      const minutes = Math.max(0, Math.round((Date.now() / 1000 - ts) / 60));
      if (minutes < 60) return this.t('WAITING_MIN', { count: minutes });
      const hours = Math.round(minutes / 60);
      if (hours < 24) return this.t('WAITING_HOURS', { count: hours });
      return this.t('WAITING_DAYS', { count: Math.round(hours / 24) });
    },
    formatDayLabel(day) {
      return formatDay(day);
    },
    money(row) {
      if (row.amount === null || row.amount === undefined) return '';
      return `${Number(row.amount).toLocaleString()} ${row.currency || ''}`;
    },
    delta(row) {
      const diff = row.now - row.before;
      if (!diff) return '';
      return diff > 0 ? `+${diff}` : `${diff}`;
    },
    openCase(id) {
      this.$router.push({ name: 'gestorTickets_detail', params: { id } });
    },
    openConversation(id) {
      this.$router.push(`/app/accounts/${this.accountId}/conversations/${id}`);
    },
    openTask(row) {
      this.$router.push({
        name: 'gestorTickets_detail',
        params: { id: row.case_ticket.id },
        query: { tab: 'tasks' },
      });
    },
    goMyDay() {
      this.$router.push({
        name: 'gestorTickets_tasks',
        query: { tab: 'my_day' },
      });
    },
    goConversations() {
      this.$router.push({ name: 'home' });
    },
    goBusinessSummary() {
      this.$router.push({ name: 'gestorTickets_business_summary' });
    },
  },
};
</script>

<template>
  <div class="flex flex-col flex-1 min-h-0 overflow-auto">
    <div class="flex flex-col w-full max-w-6xl gap-5 px-6 py-5 mx-auto">
      <header class="flex flex-wrap items-center justify-between gap-3">
        <div>
          <h1
            class="m-0 text-2xl font-semibold text-slate-800 dark:text-slate-100"
          >
            {{ greeting }}
          </h1>
          <p class="m-0 text-sm text-slate-500 dark:text-slate-400">
            {{ t('SUBTITLE') }}
          </p>
        </div>
        <woot-button
          v-if="canViewBusinessSummary"
          size="small"
          variant="smooth"
          icon="arrow-trending-lines"
          @click="goBusinessSummary"
        >
          {{ t('BUSINESS_SUMMARY') }}
        </woot-button>
      </header>

      <MyDayNotices />

      <p v-if="isLoading && !summary" class="m-0 text-sm text-slate-400">
        {{ t('LOADING') }}
      </p>

      <div v-else class="grid gap-4 md:grid-cols-2">
        <!-- Mi día: lo más urgente -->
        <section v-if="hasCases" class="home-card">
          <div class="home-card__head">
            <h2>{{ t('MY_DAY') }}</h2>
            <button type="button" class="home-card__link" @click="goMyDay">
              {{ t('SEE_ALL') }}
            </button>
          </div>
          <p v-if="!tasks.length" class="home-card__empty">
            {{ t('MY_DAY_EMPTY') }}
          </p>
          <ul v-else class="home-list">
            <li v-for="row in tasks" :key="row.id" @click="openTask(row)">
              <span class="home-list__title">{{ row.title }}</span>
              <span class="home-list__meta">
                {{ row.case_ticket && row.case_ticket.folio }}
                <span
                  v-for="r in reasons(row)"
                  :key="r.key"
                  class="home-chip"
                  >{{ reasonLabel(r) }}</span
                >
              </span>
            </li>
          </ul>
        </section>

        <!-- Agenda de hoy -->
        <section v-if="agenda.length" class="home-card">
          <div class="home-card__head">
            <h2>{{ t('AGENDA') }}</h2>
          </div>
          <ul class="home-list">
            <li
              v-for="m in agenda"
              :key="`m-${m.id}`"
              @click="m.case_ticket && openCase(m.case_ticket.id)"
            >
              <span class="home-list__title">
                {{ hour(m.starts_at) }} · {{ m.title }}
              </span>
              <span class="home-list__meta">
                {{ m.case_ticket && m.case_ticket.folio }}
              </span>
            </li>
          </ul>
        </section>

        <!-- Mis conversaciones -->
        <section class="home-card">
          <div class="home-card__head">
            <h2>{{ t('CONVERSATIONS') }}</h2>
            <button
              type="button"
              class="home-card__link"
              @click="goConversations"
            >
              {{ t('SEE_ALL') }}
            </button>
          </div>
          <p class="m-0 text-sm text-slate-600 dark:text-slate-300">
            {{
              t('CONVERSATIONS_COUNT', {
                open: conversations.open_count || 0,
                waiting: conversations.waiting_count || 0,
              })
            }}
          </p>
          <ul v-if="(conversations.waiting || []).length" class="home-list">
            <li
              v-for="c in conversations.waiting"
              :key="`c-${c.id}`"
              @click="openConversation(c.id)"
            >
              <span class="home-list__title">
                {{ c.contact || `#${c.id}` }}
              </span>
              <span class="home-list__meta">
                #{{ c.id }} · {{ c.inbox }}
                <span class="home-chip home-chip--warn">{{
                  waitingFor(c.waiting_since)
                }}</span>
              </span>
            </li>
          </ul>
        </section>

        <!-- Mis casos -->
        <section v-if="hasCases && hasCaseBlock" class="home-card">
          <div class="home-card__head">
            <h2>{{ t('CASES') }}</h2>
          </div>
          <template v-if="(cases.sla || []).length">
            <h3 class="home-card__sub">
              {{ t('CASES_SLA', { count: cases.sla_count }) }}
            </h3>
            <ul class="home-list">
              <li
                v-for="c in cases.sla"
                :key="`s-${c.id}`"
                @click="openCase(c.id)"
              >
                <span class="home-list__title">{{ c.title }}</span>
                <span class="home-list__meta">
                  {{ c.folio }}
                  <span class="home-chip home-chip--alert">{{
                    t(`SLA.${c.sla_status}`)
                  }}</span>
                </span>
              </li>
            </ul>
          </template>
          <template v-if="(cases.ready || []).length">
            <h3 class="home-card__sub">{{ t('CASES_READY') }}</h3>
            <ul class="home-list">
              <li
                v-for="c in cases.ready"
                :key="`r-${c.id}`"
                @click="openCase(c.id)"
              >
                <span class="home-list__title">{{ c.title }}</span>
                <span class="home-list__meta">
                  {{ c.folio }} ·
                  {{
                    t(c.needs_doc ? 'READY_DOC' : 'READY_NEXT', {
                      stage: c.stage,
                      next: c.next,
                    })
                  }}
                </span>
              </li>
            </ul>
          </template>
          <template v-if="(cases.promises || []).length">
            <h3 class="home-card__sub">{{ t('CASES_PROMISES') }}</h3>
            <ul class="home-list">
              <li
                v-for="c in cases.promises"
                :key="`p-${c.id}`"
                @click="openCase(c.id)"
              >
                <span class="home-list__title">{{ c.title }}</span>
                <span class="home-list__meta">
                  {{ c.folio }} · {{ money(c) }} · {{ formatDayLabel(c.on) }}
                </span>
              </li>
            </ul>
          </template>
        </section>

        <!-- Mis números de la semana -->
        <section v-if="hasCases && weekRows.length" class="home-card">
          <div class="home-card__head">
            <h2>{{ t('WEEK') }}</h2>
          </div>
          <div class="grid grid-cols-3 gap-3">
            <div v-for="r in weekRows" :key="r.key" class="flex flex-col">
              <span
                class="text-2xl font-semibold text-slate-800 dark:text-slate-100"
                >{{ r.now }}</span
              >
              <span class="text-xs text-slate-500 dark:text-slate-400">
                {{ t(`WEEK_ROWS.${r.key}`) }}
              </span>
              <span class="text-[11px] text-slate-400 dark:text-slate-500">
                {{ t('WEEK_BEFORE', { count: r.before }) }}
                <strong v-if="delta(r)">{{ delta(r) }}</strong>
              </span>
            </div>
          </div>
        </section>
      </div>
    </div>
  </div>
</template>

<style lang="scss" scoped>
.home-card {
  @apply flex flex-col gap-2 p-4 bg-white border rounded-lg border-slate-100 dark:bg-slate-800 dark:border-slate-700;

  h2 {
    @apply m-0 text-sm font-semibold text-slate-800 dark:text-slate-100;
  }
}

.home-card__head {
  @apply flex items-center justify-between;
}

.home-card__link {
  @apply text-xs text-woot-600 hover:underline dark:text-woot-300;
}

.home-card__sub {
  @apply m-0 mt-1 text-xs font-semibold uppercase tracking-wide text-slate-500 dark:text-slate-400;
}

.home-card__empty {
  @apply m-0 text-sm text-slate-400 dark:text-slate-500;
}

.home-list {
  @apply flex flex-col p-0 m-0 list-none;

  li {
    @apply flex flex-col gap-0.5 px-2 py-1.5 -mx-2 rounded cursor-pointer hover:bg-slate-50 dark:hover:bg-slate-700/50;
  }
}

.home-list__title {
  @apply text-sm text-slate-800 truncate dark:text-slate-100;
}

.home-list__meta {
  @apply flex flex-wrap items-center gap-1.5 text-xs text-slate-500 dark:text-slate-400;
}

.home-chip {
  @apply px-1.5 py-0.5 text-[10px] rounded-full bg-slate-100 text-slate-600 dark:bg-slate-700 dark:text-slate-300;
}

.home-chip--warn {
  @apply bg-amber-100 text-amber-800 dark:bg-amber-900/40 dark:text-amber-200;
}

.home-chip--alert {
  @apply bg-red-100 text-red-800 dark:bg-red-900/40 dark:text-red-300;
}
</style>
