<!--
  Agenda › Reportes. Dos preguntas con los mismos filtros: «Reportes», qué se hizo al
  concluir cada tarea; «Llegadas», dónde y cuándo llegó cada quien a una visita.
-->
<script>
import { mapGetters } from 'vuex';
import TaskReportsList from './tasks/TaskReportsList.vue';
import VisitArrivals from './tasks/VisitArrivals.vue';

const TABS = ['reports', 'arrivals'];

export default {
  name: 'TaskReports',
  components: { TaskReportsList, VisitArrivals },
  data() {
    return {
      tab: TABS.includes(this.$route.query.tab)
        ? this.$route.query.tab
        : TABS[0],
      userId: '',
      from: '',
      to: '',
    };
  },
  computed: {
    ...mapGetters({ agents: 'agents/getAgents' }),
    tabs() {
      return TABS;
    },
    tabIndex() {
      return TABS.indexOf(this.tab);
    },
    filters() {
      return {
        user_id: this.userId || undefined,
        from: this.from || undefined,
        to: this.to || undefined,
      };
    },
  },
  mounted() {
    this.$store.dispatch('agents/get');
  },
  methods: {
    onTabChange(index) {
      this.tab = TABS[index];
      this.$router.replace({ query: { tab: this.tab } });
    },
  },
};
</script>

<template>
  <div
    class="flex flex-col flex-1 w-full h-full overflow-hidden bg-slate-25 dark:bg-slate-900"
  >
    <div
      class="flex flex-col flex-shrink-0 gap-3 px-6 py-4 bg-white border-b dark:bg-slate-900 border-slate-50 dark:border-slate-800/50"
    >
      <h1 class="m-0 text-xl font-bold text-slate-800 dark:text-slate-100">
        {{ $t('TASK_REPORT.PAGE_TITLE') }}
      </h1>
      <woot-tabs :index="tabIndex" @change="onTabChange">
        <woot-tabs-item
          v-for="(name, index) in tabs"
          :key="name"
          :index="index"
          :name="$t(`TASK_REPORT.TABS.${name.toUpperCase()}`)"
          :show-badge="false"
        />
      </woot-tabs>
      <div class="flex flex-wrap items-center gap-2">
        <select v-model="userId" class="!mb-0 text-sm w-56">
          <option value="">{{ $t('TASK_REPORT.ALL_PEOPLE') }}</option>
          <option v-for="agent in agents" :key="agent.id" :value="agent.id">
            {{ agent.name }}
          </option>
        </select>
        <input
          v-model="from"
          type="date"
          class="!mb-0 text-sm w-40"
          :aria-label="$t('TASK_REPORT.FROM')"
        />
        <input
          v-model="to"
          type="date"
          class="!mb-0 text-sm w-40"
          :aria-label="$t('TASK_REPORT.TO')"
        />
      </div>
    </div>
    <div class="flex-1 px-6 py-4 overflow-y-auto">
      <TaskReportsList v-if="tab === 'reports'" :filters="filters" />
      <VisitArrivals v-else :filters="filters" />
    </div>
  </div>
</template>
