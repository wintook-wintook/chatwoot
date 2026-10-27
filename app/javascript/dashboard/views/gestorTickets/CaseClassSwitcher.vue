<!--
  @tickets_cases — Plan-Casos E1 (F6)
  Selector de clase (Comercial | Soporte) en el encabezado de Lista, Tablero y
  Métricas. Cambia de clase SIN cambiar de vista (de la lista de tickets a la de
  oportunidades). El selector YA dice dónde estás, así que reemplaza al título
  de la vista; con una sola clase activa no hay selector y se pinta el `title`.
  En ambos casos recuerda la clase actual (para las rutas neutras del menú) y
  saca de una clase cuyo flag está apagado.

  Menú v2 (Plan-Reacomodo-Menu) — Ventas y Servicio son áreas del menú, así que:
  en Comercial no hay selector de clase (el título es «Oportunidades») y en
  Servicio solo salen sus clases; además se agrega la forma de ver
  [Lista | Tablero | Dashboard], que se recuerda por clase. Con MENU_V2 en
  false se ve como antes.
-->
<script>
import { mapGetters } from 'vuex';
import {
  CLASS_VIEW_ROUTES,
  DEFAULT_CASE_CLASS,
  enabledCaseClasses,
  rememberCaseClass,
  rememberCaseView,
} from 'dashboard/helper/caseClasses';
import { MENU_V2 } from 'dashboard/components/layout/config/menuVersion';

const COMMERCIAL = 'commercial';
const VIEWS = ['list', 'board', 'metrics'];
// Ícono + texto: el selector debe notarse (si no, nadie descubre el Dashboard).
// La opción activa en el color del tema (texto e ícono), sobre blanco: se nota dónde
// estás sin competir con el botón relleno de «+ Nuevo», que es la acción principal.
const ACTIVE_CLASS =
  'bg-white font-semibold text-woot-600 shadow-sm dark:bg-slate-700 dark:text-woot-200';
const IDLE_CLASS =
  'font-medium text-slate-500 hover:text-slate-800 hover:bg-white/60 dark:text-slate-400 dark:hover:text-slate-100 dark:hover:bg-slate-700/50';
const VIEW_ICONS = {
  list: 'list',
  board: 'kanban',
  metrics: 'arrow-trending-lines',
};

export default {
  name: 'CaseClassSwitcher',
  props: {
    caseClass: { type: String, required: true },
    // Título de la vista; solo se ve cuando no hay selector (una sola clase).
    title: { type: String, default: '' },
  },
  data() {
    return {
      menuV2: MENU_V2,
      activeClass: ACTIVE_CLASS,
      idleClass: IDLE_CLASS,
    };
  },
  computed: {
    ...mapGetters({
      accountId: 'getCurrentAccountId',
      getAccount: 'accounts/getAccount',
      isFeatureEnabledonAccount: 'accounts/isFeatureEnabledonAccount',
    }),
    // Los flags llegan con la cuenta; antes de eso no se sabe qué clases hay y
    // no se debe sacar a nadie de la suya (recarga directa en una URL Comercial).
    accountLoaded() {
      return !!this.getAccount(this.accountId)?.features;
    },
    classes() {
      return enabledCaseClasses(flag =>
        this.isFeatureEnabledonAccount(this.accountId, flag)
      );
    },
    isSales() {
      return this.caseClass === COMMERCIAL;
    },
    // Las clases que se ofrecen en el selector: con el menú v2, solo las del área.
    shownClasses() {
      if (!this.menuV2) return this.classes;
      if (this.isSales) return [];
      return this.classes.filter(c => c.key !== COMMERCIAL);
    },
    shownTitle() {
      if (!this.menuV2) return this.title;
      return this.$t(
        this.isSales ? 'SIDEBAR.OPPORTUNITIES' : 'SIDEBAR.SERVICE_CASES'
      );
    },
    currentView() {
      return VIEWS.find(view => CLASS_VIEW_ROUTES[view] === this.$route.name);
    },
    views() {
      return VIEWS.map(key => ({
        key,
        icon: VIEW_ICONS[key],
        label: this.$t(`CASE_TICKETS.CLASSES.${this.viewLabel(key)}`),
      }));
    },
  },
  watch: {
    caseClass: { immediate: true, handler: 'sync' },
    accountLoaded: 'sync',
    currentView: { immediate: true, handler: 'rememberView' },
  },
  methods: {
    sync() {
      if (!this.accountLoaded) return;
      if (!this.classes.some(c => c.key === this.caseClass)) {
        this.go(DEFAULT_CASE_CLASS, true);
        return;
      }
      rememberCaseClass(this.accountId, this.caseClass);
    },
    rememberView(view) {
      if (this.menuV2 && view && this.accountId) {
        rememberCaseView(this.accountId, this.caseClass, view);
      }
    },
    viewLabel(key) {
      if (key === 'board') return 'VIEW_BOARD';
      if (key === 'list') return 'VIEW_LIST';
      return 'VIEW_DASHBOARD';
    },
    go(caseClass, replace = false) {
      if (caseClass === this.caseClass) return;
      const target = {
        name: this.$route.name,
        params: { ...this.$route.params, caseClass },
      };
      if (replace) this.$router.replace(target);
      else this.$router.push(target);
    },
    goView(view) {
      if (view === this.currentView) return;
      this.$router.push({
        name: CLASS_VIEW_ROUTES[view],
        params: {
          accountId: this.$route.params.accountId,
          caseClass: this.caseClass,
        },
      });
    },
  },
};
</script>

<template>
  <div class="flex flex-wrap items-center gap-3">
    <h1
      v-if="shownClasses.length <= 1"
      class="m-0 text-xl font-bold text-slate-800 dark:text-slate-100"
    >
      {{ shownTitle }}
    </h1>
    <div
      v-else
      class="inline-flex flex-shrink-0 p-1 rounded-lg bg-slate-100 dark:bg-slate-800"
      role="tablist"
      :aria-label="$t('CASE_TICKETS.CLASSES.SWITCHER_LABEL')"
    >
      <button
        v-for="c in shownClasses"
        :key="c.key"
        type="button"
        role="tab"
        :aria-selected="c.key === caseClass"
        class="flex items-center gap-1.5 h-8 px-3 text-sm rounded-md transition-colors"
        :class="c.key === caseClass ? activeClass : idleClass"
        @click="go(c.key)"
      >
        <span
          class="inline-block w-2 h-2 rounded-full"
          :style="{ backgroundColor: c.color }"
        />
        {{ $t(`${c.i18n}.NAME`) }}
      </button>
    </div>

    <!-- Menú v2 — forma de ver: Lista | Tablero | Dashboard -->
    <div
      v-if="menuV2 && currentView"
      class="inline-flex flex-shrink-0 p-1 rounded-lg bg-slate-100 dark:bg-slate-800"
      role="group"
      :aria-label="$t('CASE_TICKETS.CLASSES.VIEW_LABEL')"
    >
      <button
        v-for="view in views"
        :key="view.key"
        type="button"
        :aria-pressed="view.key === currentView"
        class="flex items-center gap-2 h-8 px-3.5 text-sm rounded-md transition-colors"
        :class="view.key === currentView ? activeClass : idleClass"
        @click="goView(view.key)"
      >
        <fluent-icon :icon="view.icon" size="18" />
        {{ view.label }}
      </button>
    </div>
  </div>
</template>
