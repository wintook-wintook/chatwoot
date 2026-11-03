<script>
// feat/licencias F6.1 — LA FICHA DE UNA CUENTA
// ============================================================================
// Plan: docs/licencias_plan_v1.md, F6. Todo lo de una cuenta en una página (como la captura
// de planes): encabezado con «‹ Cuentas» y «Asignar licencia» (página aparte, IssueForm),
// cuatro tarjetas (agentes,
// licencia, funciones, bandejas) y pestañas Resumen · Agentes · Licencias. La pestaña viaja
// en la dirección (?tab=), así «Historial» de la tabla abre directo Licencias. Licencias
// sustituye al modal de historial: cancelar una programada se hace aquí.
// F6.2: «Agregar agentes» abre un recuadro aquí mismo (sin modal) que solo sube el tope de la
// licencia vigente; queda en el registro con el motivo.
// F6.3: pestaña Funciones con interruptores, como el super admin (solo «Gestionar»). Los cambios
// se juntan y se guardan con «Guardar cambios» (o se descartan): un clic por error no apaga
// un canal al momento. Cada una dice si viene o no en el plan de su licencia; el plan no las
// aplica solo (D6b, pregunta 14.1). Salir con cambios sin guardar lo pregunta (confirmLeave).
// F6.4: pestaña Registro de cambios (Licenses::AccountChangeLog), con filtros por tipo y fechas
// y «Cargar más»; las frases las arma changeLog.js.
// ============================================================================
import { useAlert } from 'dashboard/composables';
import LicensesAPI from 'dashboard/api/licenses';
import BaseSettingsHeader from 'dashboard/routes/dashboard/settings/components/BaseSettingsHeader.vue';
import { changeText, featureLabel, KINDS, KIND_ICONS } from './changeLog';

export const TABS = ['summary', 'agents', 'features', 'licenses', 'changes'];
const FEATURE_FILTERS = ['all', 'on', 'off', 'outside'];
const SOON_DAYS = 7;

export default {
  components: { BaseSettingsHeader },
  props: {
    licensedAccountId: { type: Number, required: true },
    canManage: { type: Boolean, default: false },
    // Todos los nombres de config/features.yml (GET licenses/plans).
    availableFeatures: { type: Array, default: () => [] },
  },
  data() {
    return {
      account: null,
      loading: true,
      notFound: false,
      cancelling: null,
      // F6.2: el recuadro de «Agregar agentes»
      addingAgents: false,
      agentsToAdd: 1,
      addReason: '',
      savingAgents: false,
      tabs: TABS,
      // F6.3: { nombre: true|false } aún sin guardar
      pendingFeatures: {},
      featureFilter: 'all',
      featureFilters: FEATURE_FILTERS,
      featureQuery: '',
      savingFeatures: false,
      // F6.4: el registro de cambios
      changes: [],
      changesNext: null,
      changesLoading: false,
      changesLoaded: false,
      changesKind: '',
      changesFrom: '',
      changesTo: '',
      changeKinds: KINDS,
    };
  },
  computed: {
    tab() {
      const pedido = this.$route.query.tab;
      return TABS.includes(pedido) ? pedido : 'summary';
    },
    tabIndex() {
      return TABS.indexOf(this.tab);
    },
    license() {
      return (this.account && this.account.license) || null;
    },
    scheduled() {
      return ((this.account && this.account.licenses) || []).filter(
        l => l.status === 'scheduled'
      );
    },
    rowState() {
      if (!this.account) return 'sin_licencia';
      const lic = this.license;
      if (lic && lic.days_left !== null && lic.days_left <= SOON_DAYS)
        return 'por_vencer';
      return this.account.license_state;
    },
    stateScheme() {
      return {
        sin_licencia: 'secondary',
        demo: 'primary',
        paid: 'success',
        por_vencer: 'warning',
        vencida: 'alert',
      }[this.rowState];
    },
    planFeatures() {
      return (this.account && this.account.plan_features) || null;
    },
    pendingCount() {
      return Object.keys(this.pendingFeatures).length;
    },
    // Cada función con su estado (con lo pendiente aplicado) y si viene en el plan.
    featureRows() {
      const encendidas = new Set(
        (this.account && this.account.enabled_features) || []
      );
      return this.availableFeatures.map(name => {
        const pendiente = name in this.pendingFeatures;
        const on = pendiente
          ? this.pendingFeatures[name]
          : encendidas.has(name);
        const inPlan = this.planFeatures
          ? this.planFeatures.includes(name)
          : null;
        return {
          name,
          on,
          pending: pendiente,
          channel: name.startsWith('channel_'),
          outside: inPlan === false && on,
          missing: inPlan === true && !on,
        };
      });
    },
    outsidePlanCount() {
      if (!this.planFeatures || !this.account) return 0;
      return (this.account.enabled_features || []).filter(
        name => !this.planFeatures.includes(name)
      ).length;
    },
    visibleFeatures() {
      const texto = this.featureQuery.trim().toLowerCase();
      return this.featureRows.filter(row => {
        if (texto && !this.featureLabel(row.name).includes(texto)) return false;
        if (this.featureFilter === 'on') return row.on;
        if (this.featureFilter === 'off') return !row.on;
        if (this.featureFilter === 'outside') return row.outside || row.missing;
        return true;
      });
    },
    featureGroups() {
      return [
        { key: 'CHANNELS', items: this.visibleFeatures.filter(r => r.channel) },
        {
          key: 'FUNCTIONS',
          items: this.visibleFeatures.filter(r => !r.channel),
        },
      ].filter(group => group.items.length);
    },
    canAddAgents() {
      return this.canManage && Boolean(this.license && this.license.id);
    },
    newAgentsTotal() {
      const extra = Number(this.agentsToAdd);
      return this.license && extra > 0 ? this.license.max_agents + extra : null;
    },
    freeSeats() {
      if (!this.license) return null;
      return Math.max(0, this.license.max_agents - this.account.agents_count);
    },
    cards() {
      const a = this.account;
      return [
        {
          key: 'AGENTS',
          value: this.license
            ? this.t('DETAIL.CARD_AGENTS_OF', {
                used: a.agents_count,
                max: this.license.max_agents,
              })
            : a.agents_count,
          hint:
            this.freeSeats === null
              ? this.t('DETAIL.NO_LIMIT')
              : this.t('DETAIL.FREE_SEATS', { count: this.freeSeats }),
        },
        {
          key: 'LICENSE',
          value: this.license ? this.license.name : '—',
          hint: this.scheduled.length
            ? this.t('ACCOUNTS.QUEUED', { count: this.scheduled.length })
            : this.t('DETAIL.NO_QUEUE'),
        },
        {
          key: 'FEATURES',
          value: (a.enabled_features || []).length,
          hint: this.outsidePlanCount
            ? this.t('DETAIL.FEATURES_OUTSIDE', {
                count: this.outsidePlanCount,
              })
            : this.t('DETAIL.FEATURES_HINT'),
        },
        { key: 'INBOXES', value: a.inboxes_count, hint: '' },
      ];
    },
    generalRows() {
      const a = this.account;
      return [
        {
          key: 'STATUS',
          value:
            a.status === 'suspended'
              ? this.t('ACCOUNTS.SUSPENDED')
              : this.t('DETAIL.ACTIVE'),
        },
        {
          key: 'INTERNAL',
          value: a.wintook_internal
            ? this.t('DETAIL.YES')
            : this.t('DETAIL.NO'),
        },
        { key: 'CREATED', value: this.dateTime(a.created_at) },
        { key: 'UPDATED', value: this.dateTime(a.updated_at) },
        {
          key: 'PERIOD',
          value: this.license
            ? this.t('HISTORY.FROM_TO', {
                from: this.date(this.license.starts_at),
                to: this.date(this.license.expires_at),
              })
            : '—',
        },
        { key: 'EXPIRES_IN', value: this.expiresHint() || '—' },
      ];
    },
  },
  watch: {
    licensedAccountId() {
      this.changesLoaded = false;
      this.fetch();
    },
    tab(nueva) {
      if (nueva === 'changes' && !this.changesLoaded) this.fetchChanges();
    },
    changesKind() {
      this.fetchChanges();
    },
    changesFrom() {
      this.fetchChanges();
    },
    changesTo() {
      this.fetchChanges();
    },
  },
  mounted() {
    this.fetch();
    if (this.tab === 'changes') this.fetchChanges();
  },
  methods: {
    t(key, args) {
      return this.$t(`LICENSES.${key}`, args);
    },
    async fetch() {
      this.loading = true;
      this.notFound = false;
      try {
        const { data } = await LicensesAPI.getAccount(this.licensedAccountId);
        this.account = data;
      } catch (error) {
        this.notFound = true;
      } finally {
        this.loading = false;
      }
    },
    goToList() {
      this.$router.push({ name: 'licenses_accounts' });
    },
    selectTab(index) {
      this.$router.replace({
        query: { ...this.$route.query, tab: TABS[index] },
      });
    },
    date(value) {
      return value
        ? new Date(value).toLocaleDateString(this.$i18n.locale)
        : '—';
    },
    dateTime(value) {
      if (!value) return '—';
      return new Date(value).toLocaleString(this.$i18n.locale || 'es', {
        day: '2-digit',
        month: 'short',
        year: 'numeric',
        hour: '2-digit',
        minute: '2-digit',
      });
    },
    expiresHint() {
      if (!this.license || this.license.days_left === null) return '';
      const dias = this.license.days_left;
      return dias >= 0
        ? this.t('ACCOUNTS.DAYS_LEFT', { count: dias })
        : this.t('ACCOUNTS.EXPIRED_AGO', { count: -dias });
    },
    statusScheme(status) {
      return {
        active: 'success',
        scheduled: 'primary',
        expired: 'alert',
        cancelled: 'secondary',
      }[status];
    },
    roleLabel(role) {
      return this.t(`DETAIL.ROLES.${String(role).toUpperCase()}`);
    },
    featureLabel,
    changeLine(evento) {
      return changeText(evento, this.t);
    },
    kindIcon(kind) {
      return KIND_ICONS[kind] || 'list';
    },
    async fetchChanges(reset = true) {
      if (this.changesLoading) return;
      this.changesLoading = true;
      try {
        const { data } = await LicensesAPI.getChanges(this.licensedAccountId, {
          kind: this.changesKind || undefined,
          from: this.changesFrom || undefined,
          to: this.changesTo || undefined,
          before: reset ? undefined : this.changesNext || undefined,
        });
        this.changes = reset
          ? data.events || []
          : [...this.changes, ...(data.events || [])];
        this.changesNext = data.next_before || null;
        this.changesLoaded = true;
      } catch (error) {
        useAlert(this.t('LOAD_ERROR'));
      } finally {
        this.changesLoading = false;
      }
    },
    clearChangeFilters() {
      this.changesKind = '';
      this.changesFrom = '';
      this.changesTo = '';
    },
    toggleFeature(row) {
      if (!this.canManage) return;
      const encendida = (this.account.enabled_features || []).includes(
        row.name
      );
      const siguiente = !row.on;
      const pendientes = { ...this.pendingFeatures };
      // Regresar al estado guardado ya no es un cambio.
      if (siguiente === encendida) delete pendientes[row.name];
      else pendientes[row.name] = siguiente;
      this.pendingFeatures = pendientes;
    },
    discardFeatures() {
      this.pendingFeatures = {};
    },
    async saveFeatures() {
      if (!this.pendingCount || this.savingFeatures) return;
      this.savingFeatures = true;
      try {
        const { data } = await LicensesAPI.updateFeatures(
          this.licensedAccountId,
          this.pendingFeatures
        );
        this.account = {
          ...this.account,
          enabled_features: data.enabled_features,
        };
        useAlert(this.t('DETAIL.FEATURES_SAVED', { count: this.pendingCount }));
        this.pendingFeatures = {};
      } catch (error) {
        const data = error && error.response && error.response.data;
        useAlert((data && data.message) || this.t('DETAIL.FEATURES_ERROR'));
      } finally {
        this.savingFeatures = false;
      }
    },
    // Para Index.vue (guardas de ruta): true si se puede salir.
    async confirmLeave() {
      if (!this.pendingCount) return true;
      return this.$refs.leaveDialog.showConfirmation();
    },
    openAddAgents() {
      this.agentsToAdd = 1;
      this.addReason = '';
      this.addingAgents = true;
    },
    async saveAgents() {
      if (!this.newAgentsTotal || this.savingAgents) return;
      this.savingAgents = true;
      try {
        await LicensesAPI.addAgents(this.license.id, {
          add: Number(this.agentsToAdd),
          reason: this.addReason.trim(),
        });
        useAlert(
          this.t('DETAIL.ADD_AGENTS.DONE', { total: this.newAgentsTotal })
        );
        this.addingAgents = false;
        await this.fetch();
      } catch (error) {
        const data = error && error.response && error.response.data;
        useAlert((data && data.message) || this.t('DETAIL.ADD_AGENTS.ERROR'));
      } finally {
        this.savingAgents = false;
      }
    },
    openIssue() {
      this.$router.push({
        name: 'licenses_accounts_issue',
        params: { licensedAccountId: this.licensedAccountId },
      });
    },
    async cancel(license) {
      this.cancelling = license.id;
      try {
        await LicensesAPI.cancel(license.id);
        useAlert(this.t('HISTORY.CANCELLED'));
        await this.fetch();
      } catch (error) {
        const data = error && error.response && error.response.data;
        useAlert((data && data.message) || this.t('HISTORY.CANCEL_ERROR'));
      } finally {
        this.cancelling = null;
      }
    },
  },
};
</script>

<template>
  <div class="flex flex-col flex-1 min-h-0">
    <p v-if="loading && !account" class="text-sm text-slate-500">
      {{ t('DETAIL.LOADING') }}
    </p>
    <div v-else-if="notFound" class="flex flex-col items-start gap-3">
      <p class="m-0 text-sm text-slate-600 dark:text-slate-300">
        {{ t('DETAIL.NOT_FOUND') }}
      </p>
      <woot-button variant="clear" icon="chevron-left" @click="goToList">
        {{ t('TABS.ACCOUNTS') }}
      </woot-button>
    </div>
    <template v-else-if="account">
      <div class="shrink-0">
        <BaseSettingsHeader :title="account.name">
          <template #description>
            <span class="inline-flex flex-wrap items-center gap-2">
              <span class="text-slate-400">#{{ account.id }}</span>
              <woot-label
                small
                class="!mb-0"
                :color-scheme="stateScheme"
                :title="t(`STATE.${rowState.toUpperCase()}`)"
              />
              <woot-label
                v-if="account.status === 'suspended'"
                small
                color-scheme="alert"
                class="!mb-0"
                :title="t('ACCOUNTS.SUSPENDED')"
              />
              <span v-if="license">
                {{ license.name }} ·
                {{ t('DETAIL.EXPIRES_ON', { date: date(license.expires_at) }) }}
                <template v-if="expiresHint()">({{ expiresHint() }})</template>
              </span>
            </span>
          </template>
          <template #actions>
            <woot-button variant="clear" icon="chevron-left" @click="goToList">
              {{ t('TABS.ACCOUNTS') }}
            </woot-button>
            <woot-button
              v-if="canAddAgents"
              variant="hollow"
              icon="people-team-add"
              @click="openAddAgents"
            >
              {{ t('DETAIL.ADD_AGENTS.BUTTON') }}
            </woot-button>
            <woot-button v-if="canManage" icon="add-circle" @click="openIssue">
              {{ t('ACCOUNTS.ASSIGN') }}
            </woot-button>
          </template>
        </BaseSettingsHeader>

        <!-- F6.2: agregar agentes, aquí mismo -->
        <form
          v-if="addingAgents && license"
          class="flex flex-wrap items-end gap-3 p-4 mt-6 border border-solid rounded-lg bg-white dark:bg-slate-800 border-woot-100 dark:border-slate-700"
          @submit.prevent="saveAgents"
        >
          <p class="w-full m-0 text-sm text-slate-700 dark:text-slate-200">
            {{
              t('DETAIL.ADD_AGENTS.INTRO', {
                name: license.name,
                max: license.max_agents,
              })
            }}
          </p>
          <label class="!mb-0">
            {{ t('DETAIL.ADD_AGENTS.HOW_MANY') }}
            <input
              v-model.number="agentsToAdd"
              type="number"
              min="1"
              max="1000"
              class="!w-28 !mb-0"
            />
          </label>
          <label class="flex-1 min-w-[16rem] !mb-0">
            {{ t('DETAIL.ADD_AGENTS.REASON') }}
            <input
              v-model="addReason"
              type="text"
              maxlength="255"
              class="!mb-0"
              :placeholder="t('DETAIL.ADD_AGENTS.REASON_PLACEHOLDER')"
            />
          </label>
          <p
            class="m-0 text-sm font-medium text-slate-700 dark:text-slate-200 whitespace-nowrap"
          >
            {{
              newAgentsTotal
                ? t('DETAIL.ADD_AGENTS.RESULT', {
                    from: license.max_agents,
                    to: newAgentsTotal,
                  })
                : '—'
            }}
          </p>
          <div class="flex gap-2">
            <woot-button
              variant="clear"
              color-scheme="secondary"
              @click.prevent="addingAgents = false"
            >
              {{ t('DETAIL.ADD_AGENTS.CANCEL') }}
            </woot-button>
            <woot-button
              :is-disabled="!newAgentsTotal"
              :is-loading="savingAgents"
            >
              {{ t('DETAIL.ADD_AGENTS.SAVE') }}
            </woot-button>
          </div>
          <p class="w-full m-0 text-xs text-slate-500 dark:text-slate-400">
            {{ t('DETAIL.ADD_AGENTS.HINT') }}
          </p>
        </form>

        <div class="grid grid-cols-2 gap-3 mt-6 lg:grid-cols-4">
          <div
            v-for="card in cards"
            :key="card.key"
            class="p-4 border border-solid rounded-lg bg-white dark:bg-slate-800 border-slate-100 dark:border-slate-700"
          >
            <p class="m-0 text-xs text-slate-500 dark:text-slate-400">
              {{ t(`DETAIL.CARDS.${card.key}`) }}
            </p>
            <p
              class="m-0 mt-1 text-xl font-semibold truncate text-slate-800 dark:text-slate-100"
            >
              {{ card.value }}
            </p>
            <p
              v-if="card.hint"
              class="m-0 mt-1 text-xs text-slate-500 dark:text-slate-400"
            >
              {{ card.hint }}
            </p>
          </div>
        </div>

        <woot-tabs class="mt-4" :index="tabIndex" @change="selectTab">
          <woot-tabs-item
            v-for="(item, position) in tabs"
            :key="item"
            :index="position"
            :name="t(`DETAIL.TABS.${item.toUpperCase()}`)"
            :show-badge="false"
          />
        </woot-tabs>
      </div>

      <div class="flex-1 min-h-0 pt-4 overflow-y-auto">
        <!-- Resumen -->
        <dl
          v-if="tab === 'summary'"
          class="grid grid-cols-1 m-0 md:grid-cols-2 gap-x-8"
        >
          <div
            v-for="row in generalRows"
            :key="row.key"
            class="flex justify-between gap-4 py-3 border-0 border-b border-solid border-slate-50 dark:border-slate-800"
          >
            <dt class="text-sm text-slate-500 dark:text-slate-400">
              {{ t(`DETAIL.GENERAL.${row.key}`) }}
            </dt>
            <dd
              class="m-0 text-sm font-medium text-right text-slate-800 dark:text-slate-100"
            >
              {{ row.value }}
            </dd>
          </div>
        </dl>

        <!-- Funciones (F6.3) -->
        <template v-else-if="tab === 'features'">
          <div
            class="flex flex-wrap items-center gap-2 p-3 mb-4 border border-solid rounded-lg bg-white dark:bg-slate-800 border-slate-100 dark:border-slate-700"
          >
            <div class="relative w-56">
              <input
                v-model="featureQuery"
                type="text"
                :placeholder="t('DETAIL.FEATURES_SEARCH')"
                class="reset-base box-border w-full h-9 m-0 text-sm rounded-md border border-solid border-slate-200 dark:border-slate-600 bg-white dark:bg-slate-900 text-slate-900 dark:text-slate-100 pl-8 pr-2 outline-none focus:border-woot-500 dark:focus:border-woot-600"
              />
              <fluent-icon
                icon="search"
                size="16"
                class="absolute -translate-y-1/2 left-2 top-1/2 text-slate-400"
              />
            </div>
            <select v-model="featureFilter" class="w-auto h-9 !mb-0 text-sm">
              <option
                v-for="filtro in featureFilters"
                :key="filtro"
                :value="filtro"
                :disabled="filtro === 'outside' && !planFeatures"
              >
                {{ t(`DETAIL.FEATURE_FILTERS.${filtro.toUpperCase()}`) }}
              </option>
            </select>
            <span class="flex-1" />
            <template v-if="pendingCount">
              <span class="text-sm text-amber-700 dark:text-amber-400">
                {{ t('DETAIL.FEATURES_PENDING', { count: pendingCount }) }}
              </span>
              <woot-button
                variant="clear"
                color-scheme="secondary"
                size="small"
                @click="discardFeatures"
              >
                {{ t('DETAIL.FEATURES_DISCARD') }}
              </woot-button>
              <woot-button
                size="small"
                :is-loading="savingFeatures"
                @click="saveFeatures"
              >
                {{ t('DETAIL.FEATURES_SAVE') }}
              </woot-button>
            </template>
          </div>
          <p class="mt-0 mb-4 text-xs text-slate-500 dark:text-slate-400">
            {{
              canManage
                ? t('DETAIL.FEATURES_INTRO')
                : t('DETAIL.FEATURES_READ_ONLY')
            }}
            <template v-if="!planFeatures">
              {{ t('DETAIL.FEATURES_NO_PLAN') }}
            </template>
          </p>
          <div
            v-if="!featureGroups.length"
            class="py-16 text-center border border-dashed rounded-lg text-slate-400 border-slate-200 dark:border-slate-700"
          >
            {{ t('LIST.EMPTY_FILTERED') }}
          </div>
          <section v-for="group in featureGroups" :key="group.key" class="mb-6">
            <h3
              class="mt-0 mb-2 text-sm font-semibold text-slate-700 dark:text-slate-200"
            >
              {{ t(`PLAN_FORM.${group.key}`) }}
            </h3>
            <div class="grid grid-cols-1 gap-x-6 md:grid-cols-2 xl:grid-cols-3">
              <div
                v-for="row in group.items"
                :key="row.name"
                class="flex items-center gap-3 py-2 border-0 border-b border-solid border-slate-50 dark:border-slate-800"
              >
                <woot-switch
                  :value="row.on"
                  size="small"
                  :class="{ 'pointer-events-none opacity-60': !canManage }"
                  :aria-label="featureLabel(row.name)"
                  @input="toggleFeature(row)"
                />
                <span
                  class="flex-1 text-sm capitalize text-slate-700 dark:text-slate-200"
                  :class="{ 'font-semibold': row.pending }"
                >
                  {{ featureLabel(row.name) }}
                </span>
                <woot-label
                  v-if="row.pending"
                  small
                  color-scheme="warning"
                  class="!mb-0"
                  :title="t('DETAIL.FEATURE_PENDING')"
                />
                <woot-label
                  v-else-if="row.outside"
                  small
                  color-scheme="secondary"
                  class="!mb-0"
                  :title="t('DETAIL.FEATURE_OUTSIDE')"
                />
                <woot-label
                  v-else-if="row.missing"
                  small
                  color-scheme="primary"
                  class="!mb-0"
                  :title="t('DETAIL.FEATURE_MISSING')"
                />
              </div>
            </div>
          </section>
        </template>

        <!-- Registro de cambios (F6.4) -->
        <template v-else-if="tab === 'changes'">
          <div
            class="flex flex-wrap items-center gap-2 p-3 mb-2 border border-solid rounded-lg bg-white dark:bg-slate-800 border-slate-100 dark:border-slate-700"
          >
            <select v-model="changesKind" class="w-auto h-9 !mb-0 text-sm">
              <option value="">{{ t('CHANGES.ALL_KINDS') }}</option>
              <option v-for="kind in changeKinds" :key="kind" :value="kind">
                {{ t(`CHANGES.KINDS.${kind.toUpperCase()}`) }}
              </option>
            </select>
            <label
              class="flex items-center gap-2 !mb-0 text-sm text-slate-600 dark:text-slate-300"
            >
              {{ t('CHANGES.SINCE') }}
              <input
                v-model="changesFrom"
                type="date"
                class="h-9 !mb-0 !w-auto"
              />
            </label>
            <label
              class="flex items-center gap-2 !mb-0 text-sm text-slate-600 dark:text-slate-300"
            >
              {{ t('CHANGES.UNTIL') }}
              <input
                v-model="changesTo"
                type="date"
                class="h-9 !mb-0 !w-auto"
              />
            </label>
            <woot-button
              v-if="changesKind || changesFrom || changesTo"
              variant="clear"
              size="small"
              @click="clearChangeFilters"
            >
              {{ t('LIST.CLEAR') }}
            </woot-button>
          </div>
          <p class="mt-0 mb-4 text-xs text-slate-500 dark:text-slate-400">
            {{ t('CHANGES.HINT') }}
          </p>
          <div
            v-if="changesLoaded && !changes.length"
            class="py-16 text-center border border-dashed rounded-lg text-slate-400 border-slate-200 dark:border-slate-700"
          >
            {{ t('CHANGES.EMPTY') }}
          </div>
          <ol v-else class="p-0 m-0 list-none">
            <li
              v-for="evento in changes"
              :key="evento.id"
              class="flex items-start gap-3 py-3 border-0 border-b border-solid border-slate-50 dark:border-slate-800"
            >
              <span
                class="w-36 text-xs shrink-0 text-slate-500 whitespace-nowrap"
              >
                {{ dateTime(evento.at) }}
              </span>
              <span
                class="w-36 text-sm font-medium truncate shrink-0 text-slate-700 dark:text-slate-200"
                :title="evento.user || t('CHANGES.SYSTEM')"
              >
                {{ evento.user || t('CHANGES.SYSTEM') }}
              </span>
              <fluent-icon
                :icon="kindIcon(evento.kind)"
                size="16"
                class="mt-0.5 shrink-0 text-slate-400"
              />
              <span class="flex-1 text-sm text-slate-700 dark:text-slate-200">
                {{ changeLine(evento) }}
                <span
                  v-if="evento.comment"
                  class="block text-xs italic text-slate-500 dark:text-slate-400"
                >
                  {{ t('CHANGES.COMMENT', { comment: evento.comment }) }}
                </span>
              </span>
            </li>
          </ol>
          <div v-if="changesNext" class="flex justify-center py-4">
            <woot-button
              variant="smooth"
              color-scheme="secondary"
              :is-loading="changesLoading"
              @click="fetchChanges(false)"
            >
              {{ t('CHANGES.LOAD_MORE') }}
            </woot-button>
          </div>
        </template>

        <!-- Agentes -->
        <template v-else-if="tab === 'agents'">
          <div
            v-if="!account.agents.length"
            class="py-16 text-center border border-dashed rounded-lg text-slate-400 border-slate-200 dark:border-slate-700"
          >
            {{ t('DETAIL.NO_AGENTS') }}
          </div>
          <table v-else class="w-full text-sm">
            <thead
              class="sticky top-0 z-10 text-left bg-white border-b text-slate-400 border-slate-100 dark:border-slate-700 dark:bg-slate-900"
            >
              <tr>
                <th
                  v-for="col in ['NAME', 'EMAIL', 'ROLE', 'JOINED']"
                  :key="col"
                  class="py-2 pr-3 font-medium whitespace-nowrap"
                >
                  {{ t(`DETAIL.AGENTS_TABLE.${col}`) }}
                </th>
              </tr>
            </thead>
            <tbody>
              <tr
                v-for="agente in account.agents"
                :key="agente.id"
                class="border-b border-slate-50 dark:border-slate-800"
              >
                <td
                  class="py-2 pr-3 font-medium text-slate-700 dark:text-slate-200"
                >
                  {{ agente.name }}
                </td>
                <td class="py-2 pr-3 text-slate-500">{{ agente.email }}</td>
                <td class="py-2 pr-3 text-slate-500">
                  {{ roleLabel(agente.role) }}
                </td>
                <td class="py-2 pr-3 text-xs text-slate-500 whitespace-nowrap">
                  {{ dateTime(agente.joined_at) }}
                </td>
              </tr>
            </tbody>
          </table>
        </template>

        <!-- Licencias (antes el modal de historial) -->
        <template v-else>
          <div
            v-if="!account.licenses.length"
            class="py-16 text-center border border-dashed rounded-lg text-slate-400 border-slate-200 dark:border-slate-700"
          >
            {{ t('HISTORY.EMPTY') }}
          </div>
          <table v-else class="w-full text-sm">
            <thead
              class="sticky top-0 z-10 text-left bg-white border-b text-slate-400 border-slate-100 dark:border-slate-700 dark:bg-slate-900"
            >
              <tr>
                <th
                  v-for="col in [
                    'LICENSE',
                    'ACTIONS',
                    'STATUS',
                    'TYPE',
                    'AGENTS',
                    'PERIOD',
                    'BY',
                  ]"
                  :key="col"
                  class="py-2 pr-3 font-medium whitespace-nowrap"
                >
                  {{ t(`DETAIL.LICENSES_TABLE.${col}`) }}
                </th>
              </tr>
            </thead>
            <tbody>
              <tr
                v-for="licencia in account.licenses"
                :key="licencia.id"
                class="border-b border-slate-50 dark:border-slate-800"
              >
                <td class="py-2 pr-3">
                  <span class="font-medium text-slate-700 dark:text-slate-200">
                    {{ licencia.name }}
                  </span>
                  <div
                    v-if="licencia.notes"
                    class="text-xs text-slate-400 truncate max-w-[18rem]"
                    :title="licencia.notes"
                  >
                    {{ licencia.notes }}
                  </div>
                </td>
                <td class="py-2 pr-3">
                  <woot-button
                    v-if="canManage && licencia.status === 'scheduled'"
                    variant="smooth"
                    color-scheme="alert"
                    size="small"
                    icon="dismiss-circle"
                    :title="t('HISTORY.CANCEL')"
                    :is-loading="cancelling === licencia.id"
                    @click="cancel(licencia)"
                  />
                  <span v-else class="text-slate-300">—</span>
                </td>
                <td class="py-2 pr-3 whitespace-nowrap">
                  <woot-label
                    small
                    class="!mb-0"
                    :color-scheme="statusScheme(licencia.status)"
                    :title="t(`STATUS.${licencia.status.toUpperCase()}`)"
                  />
                </td>
                <td class="py-2 pr-3 text-slate-500">
                  {{ t(`TYPE.${licencia.license_type.toUpperCase()}`) }}
                </td>
                <td class="py-2 pr-3 text-slate-500">
                  {{ licencia.max_agents }}
                </td>
                <td class="py-2 pr-3 text-xs text-slate-500 whitespace-nowrap">
                  {{
                    t('HISTORY.FROM_TO', {
                      from: date(licencia.starts_at),
                      to: date(licencia.expires_at),
                    })
                  }}
                </td>
                <td class="py-2 pr-3 text-xs text-slate-500">
                  {{ licencia.created_by || '—' }}
                </td>
              </tr>
            </tbody>
          </table>
        </template>
      </div>
    </template>
    <woot-confirm-modal
      ref="leaveDialog"
      :title="t('PLAN_FORM.LEAVE.TITLE')"
      :description="t('DETAIL.FEATURES_LEAVE')"
      :confirm-label="t('PLAN_FORM.LEAVE.CONFIRM')"
      :cancel-label="t('PLAN_FORM.LEAVE.CANCEL')"
    />
  </div>
</template>
