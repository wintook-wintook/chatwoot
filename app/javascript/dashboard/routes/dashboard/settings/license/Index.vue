<script>
// feat/licencias (F5) — LA LICENCIA DE ESTA CUENTA (solo lectura)
// ============================================================================
// El administrador de la cuenta ve su plan, cuántos agentes usa contra el tope, cuándo vence
// y el periodo que sigue si ya está pagado. No puede cambiar nada: eso lo hace Wintook (§8).
// Los datos vienen con la cuenta (license en accounts/show): sin pedir nada aparte.
// Plan: docs/licencias_plan_v1.md §8 y §10 (F5)
// ============================================================================
import { mapGetters } from 'vuex';
import BaseSettingsHeader from '../components/BaseSettingsHeader.vue';

const SOON_DAYS = 10;

export default {
  components: { BaseSettingsHeader },
  computed: {
    ...mapGetters({
      accountId: 'getCurrentAccountId',
      getAccount: 'accounts/getAccount',
    }),
    license() {
      const account = this.getAccount(this.accountId);
      return (account && account.license) || null;
    },
    current() {
      return this.license && this.license.current;
    },
    next() {
      return this.license && this.license.next;
    },
    stateScheme() {
      if (!this.current) return 'alert';
      if (
        this.current.days_left !== null &&
        this.current.days_left <= SOON_DAYS
      )
        return 'warning';
      return this.current.license_type === 'demo' ? 'primary' : 'success';
    },
    stateLabel() {
      if (!this.current) return this.t('STATE_EXPIRED');
      return this.current.license_type === 'demo'
        ? this.t('STATE_DEMO')
        : this.t('STATE_ACTIVE');
    },
    agentsPercent() {
      if (!this.current || !this.current.max_agents) return 0;
      return Math.min(
        100,
        Math.round((this.license.agents_count / this.current.max_agents) * 100)
      );
    },
  },
  methods: {
    t(key, args) {
      return this.$t(`LICENSES.ACCOUNT_VIEW.${key}`, args);
    },
    date(value) {
      return value
        ? new Date(value).toLocaleDateString(this.$i18n.locale)
        : '—';
    },
  },
};
</script>

<template>
  <div class="flex flex-col w-full max-w-3xl gap-6">
    <BaseSettingsHeader :title="t('TITLE')" :description="t('DESCRIPTION')" />

    <p v-if="!license" class="text-sm text-slate-600 dark:text-slate-300">
      {{ t('NONE') }}
    </p>
    <template v-else>
      <section
        class="p-5 border rounded-lg border-slate-100 dark:border-slate-700"
      >
        <div class="flex flex-wrap items-center gap-2 mb-4">
          <h3
            class="m-0 text-lg font-semibold text-slate-800 dark:text-slate-100"
          >
            {{ current ? current.name : t('NO_CURRENT') }}
          </h3>
          <woot-label
            small
            class="!mb-0"
            :color-scheme="stateScheme"
            :title="stateLabel"
          />
        </div>

        <dl v-if="current" class="grid grid-cols-1 gap-4 m-0 sm:grid-cols-3">
          <div>
            <dt class="text-xs text-slate-500 dark:text-slate-400">
              {{ t('AGENTS') }}
            </dt>
            <dd
              class="m-0 text-xl font-medium text-slate-800 dark:text-slate-100"
            >
              {{ license.agents_count }} / {{ current.max_agents }}
            </dd>
            <div
              class="h-1.5 mt-2 overflow-hidden rounded-full bg-slate-100 dark:bg-slate-700"
              role="meter"
              :aria-valuenow="license.agents_count"
              aria-valuemin="0"
              :aria-valuemax="current.max_agents"
            >
              <div
                class="h-full rounded-full bg-woot-600"
                :style="{ width: `${agentsPercent}%` }"
              />
            </div>
          </div>
          <div>
            <dt class="text-xs text-slate-500 dark:text-slate-400">
              {{ t('STARTED') }}
            </dt>
            <dd
              class="m-0 text-xl font-medium text-slate-800 dark:text-slate-100"
            >
              {{ date(current.starts_at) }}
            </dd>
          </div>
          <div>
            <dt class="text-xs text-slate-500 dark:text-slate-400">
              {{ t('EXPIRES') }}
            </dt>
            <dd
              class="m-0 text-xl font-medium text-slate-800 dark:text-slate-100"
            >
              {{ date(current.expires_at) }}
            </dd>
            <span
              v-if="current.days_left !== null"
              class="text-xs text-slate-500 dark:text-slate-400"
            >
              {{ t('DAYS_LEFT', { count: current.days_left }) }}
            </span>
          </div>
        </dl>
        <p v-else class="m-0 text-sm text-slate-600 dark:text-slate-300">
          {{ t('EXPIRED_HINT') }}
        </p>
      </section>

      <section
        v-if="next"
        class="p-5 border rounded-lg border-slate-100 dark:border-slate-700"
      >
        <h3
          class="mt-0 mb-1 text-sm font-semibold text-slate-800 dark:text-slate-100"
        >
          {{ t('NEXT_TITLE') }}
        </h3>
        <p class="m-0 text-sm text-slate-600 dark:text-slate-300">
          {{
            t('NEXT_TEXT', {
              name: next.name,
              from: date(next.starts_at),
              to: date(next.expires_at),
              agents: next.max_agents,
            })
          }}
        </p>
      </section>

      <p class="m-0 text-xs text-slate-500 dark:text-slate-400">
        {{ t('READ_ONLY') }}
      </p>
    </template>
  </div>
</template>
