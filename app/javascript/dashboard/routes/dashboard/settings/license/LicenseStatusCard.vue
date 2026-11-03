<script>
// feat/licencias (F5) — EL ESTADO DE LA LICENCIA DE ESTA CUENTA (solo lectura)
// ============================================================================
// La licencia vigente (plan, estado, agentes usados contra el tope, inicio y vencimiento) y
// la fila de las que siguen, en el orden en que se activan. La usan Configuración › Licencia
// y Configuración › General (`compact`: sin el aviso de solo lectura, con «Ver licencia»).
// `license` es el de accounts/show (Account#license_summary).
// ============================================================================
const SOON_DAYS = 10;

export default {
  props: {
    license: { type: Object, required: true },
    compact: { type: Boolean, default: false },
  },
  computed: {
    current() {
      return this.license.current;
    },
    // Las cuentas anteriores a la fila completa solo mandaban `next`.
    queue() {
      if (Array.isArray(this.license.queue)) return this.license.queue;
      return this.license.next ? [this.license.next] : [];
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
  <div class="flex flex-col gap-4">
    <section
      class="p-5 border border-solid rounded-lg border-slate-100 dark:border-slate-700"
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
        <span class="flex-1" />
        <router-link
          v-if="compact"
          :to="{ name: 'account_license_index' }"
          class="text-sm text-woot-600 hover:underline"
        >
          {{ t('SEE_LICENSE') }}
        </router-link>
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
      class="p-5 border border-solid rounded-lg border-slate-100 dark:border-slate-700"
    >
      <h3
        class="mt-0 mb-1 text-sm font-semibold text-slate-800 dark:text-slate-100"
      >
        {{ t('QUEUE_TITLE') }}
      </h3>
      <p
        v-if="!queue.length"
        class="m-0 text-sm text-slate-500 dark:text-slate-400"
      >
        {{ t('QUEUE_EMPTY') }}
      </p>
      <template v-else>
        <p class="mt-0 mb-3 text-xs text-slate-500 dark:text-slate-400">
          {{ t('QUEUE_HINT') }}
        </p>
        <ol class="flex flex-col gap-2 p-0 m-0 list-none">
          <li
            v-for="(periodo, posicion) in queue"
            :key="`${periodo.name}-${periodo.starts_at}-${posicion}`"
            class="flex flex-wrap items-center gap-x-3 gap-y-1 py-2 border-0 border-t border-solid first:border-t-0 border-slate-50 dark:border-slate-800"
          >
            <woot-label
              small
              color-scheme="secondary"
              class="!mb-0"
              :title="t('QUEUE_POSITION', { position: posicion + 1 })"
            />
            <span class="font-medium text-slate-800 dark:text-slate-100">
              {{ periodo.name }}
            </span>
            <span class="text-sm text-slate-600 dark:text-slate-300">
              {{
                t('QUEUE_PERIOD', {
                  from: date(periodo.starts_at),
                  to: date(periodo.expires_at),
                })
              }}
            </span>
            <span class="text-sm text-slate-500 dark:text-slate-400">
              {{ t('QUEUE_AGENTS', { count: periodo.max_agents }) }}
            </span>
          </li>
        </ol>
      </template>
    </section>

    <p v-if="!compact" class="m-0 text-xs text-slate-500 dark:text-slate-400">
      {{ t('READ_ONLY') }}
    </p>
  </div>
</template>
