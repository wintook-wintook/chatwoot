<!--
  @tickets_cases — Configuración → «Resumen del negocio · Quién puede verlo».
  Los administradores siempre lo ven (casilla marcada y fija); a los demás
  agentes se les da acceso con una casilla. Se guarda en
  case_settings.business_summary_user_ids; el backend vuelve a revisar el
  permiso en cada consulta (no basta con ocultar el menú). Solo administradores.
-->
<script>
import { mapGetters } from 'vuex';

export default {
  name: 'BusinessSummaryAccess',
  data() {
    return { selected: [], isSaving: false };
  },
  computed: {
    ...mapGetters({
      settings: 'caseTickets/getCaseSettings',
      agents: 'agents/getAgents',
    }),
    saved() {
      return (this.settings && this.settings.business_summary_user_ids) || [];
    },
    // Administradores primero (siempre lo ven), luego el resto por nombre.
    people() {
      const list = [...(this.agents || [])];
      return list.sort(
        (a, b) =>
          Number(this.isAdmin(b)) - Number(this.isAdmin(a)) ||
          (a.name || '').localeCompare(b.name || '')
      );
    },
    dirty() {
      const a = [...this.selected].sort((x, y) => x - y).join(',');
      const b = [...this.saved].sort((x, y) => x - y).join(',');
      return a !== b;
    },
  },
  watch: {
    saved: {
      immediate: true,
      handler(ids) {
        this.selected = [...ids];
      },
    },
  },
  mounted() {
    this.$store.dispatch('caseTickets/fetchSettings');
    this.$store.dispatch('agents/get');
  },
  methods: {
    isAdmin(agent) {
      return agent.role === 'administrator';
    },
    isChecked(agent) {
      return this.isAdmin(agent) || this.selected.includes(agent.id);
    },
    toggle(agent, on) {
      this.selected = on
        ? [...new Set([...this.selected, agent.id])]
        : this.selected.filter(id => id !== agent.id);
    },
    async save() {
      if (this.isSaving) return;
      this.isSaving = true;
      try {
        await this.$store.dispatch('caseTickets/updateSettings', {
          business_summary_user_ids: this.selected,
        });
        this.$emitter.emit('newToastMessage', {
          message: this.$t('CASE_TICKETS.BUSINESS_SUMMARY.ACCESS.SAVED'),
        });
      } catch (_e) {
        this.$emitter.emit('newToastMessage', {
          message: this.$t('CASE_TICKETS.BUSINESS_SUMMARY.ACCESS.SAVE_ERROR'),
          type: 'error',
        });
      } finally {
        this.isSaving = false;
      }
    },
  },
};
</script>

<template>
  <div
    class="flex flex-col flex-1 w-full h-full overflow-hidden bg-slate-25 dark:bg-slate-900"
  >
    <div
      class="flex flex-wrap items-center flex-shrink-0 gap-3 px-6 py-4 bg-white border-b dark:bg-slate-900 border-slate-50 dark:border-slate-800/50"
    >
      <h1 class="m-0 text-xl font-bold text-slate-800 dark:text-slate-100">
        {{ $t('CASE_TICKETS.BUSINESS_SUMMARY.ACCESS.TITLE') }}
      </h1>
      <woot-button
        class="ml-auto"
        size="small"
        :is-loading="isSaving"
        :disabled="!dirty"
        @click="save"
      >
        {{ $t('CASE_TICKETS.BUSINESS_SUMMARY.ACCESS.SAVE') }}
      </woot-button>
    </div>

    <div class="flex flex-col flex-1 gap-4 px-6 py-4 overflow-y-auto">
      <p class="max-w-2xl m-0 text-sm text-slate-600 dark:text-slate-300">
        {{ $t('CASE_TICKETS.BUSINESS_SUMMARY.ACCESS.INTRO') }}
      </p>
      <ul
        class="max-w-2xl p-0 m-0 list-none bg-white border divide-y rounded-lg dark:bg-slate-800 border-slate-100 dark:border-slate-700 divide-slate-100 dark:divide-slate-700"
      >
        <li v-for="agent in people" :key="agent.id">
          <label
            class="flex items-center gap-3 px-4 py-2.5"
            :class="isAdmin(agent) ? 'cursor-default' : 'cursor-pointer'"
          >
            <input
              type="checkbox"
              class="!mb-0"
              :checked="isChecked(agent)"
              :disabled="isAdmin(agent)"
              @change="toggle(agent, $event.target.checked)"
            />
            <span class="flex flex-col min-w-0">
              <span
                class="text-sm font-medium truncate text-slate-800 dark:text-slate-100"
              >
                {{ agent.name }}
              </span>
              <span class="text-xs truncate text-slate-500 dark:text-slate-400">
                {{ agent.email }}
              </span>
            </span>
            <span
              v-if="isAdmin(agent)"
              class="ml-auto px-2 py-0.5 text-[11px] rounded-full bg-slate-100 text-slate-600 dark:bg-slate-700 dark:text-slate-300"
            >
              {{ $t('CASE_TICKETS.BUSINESS_SUMMARY.ACCESS.ALWAYS') }}
            </span>
          </label>
        </li>
      </ul>
    </div>
  </div>
</template>
