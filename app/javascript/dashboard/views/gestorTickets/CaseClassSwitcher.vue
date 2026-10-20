<!--
  @tickets_cases — Plan-Casos E1 (F6)
  Selector de clase (Comercial | Soporte) en el encabezado de Lista, Tablero y
  Métricas. Cambia de clase SIN cambiar de vista (de la lista de tickets a la de
  oportunidades). El selector YA dice dónde estás, así que reemplaza al título
  de la vista; con una sola clase activa no hay selector y se pinta el `title`.
  En ambos casos recuerda la clase actual (para las rutas neutras del menú) y
  saca de una clase cuyo flag está apagado.
-->
<script>
import { mapGetters } from 'vuex';
import {
  DEFAULT_CASE_CLASS,
  enabledCaseClasses,
  rememberCaseClass,
} from 'dashboard/helper/caseClasses';

export default {
  name: 'CaseClassSwitcher',
  props: {
    caseClass: { type: String, required: true },
    // Título de la vista; solo se ve cuando no hay selector (una sola clase).
    title: { type: String, default: '' },
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
  },
  watch: {
    caseClass: { immediate: true, handler: 'sync' },
    accountLoaded: 'sync',
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
    go(caseClass, replace = false) {
      if (caseClass === this.caseClass) return;
      const target = {
        name: this.$route.name,
        params: { ...this.$route.params, caseClass },
      };
      if (replace) this.$router.replace(target);
      else this.$router.push(target);
    },
  },
};
</script>

<template>
  <h1
    v-if="classes.length <= 1"
    class="m-0 text-xl font-bold text-slate-800 dark:text-slate-100"
  >
    {{ title }}
  </h1>
  <div
    v-else
    class="inline-flex p-0.5 rounded-lg bg-slate-100 dark:bg-slate-800"
    role="tablist"
    :aria-label="$t('CASE_TICKETS.CLASSES.SWITCHER_LABEL')"
  >
    <button
      v-for="c in classes"
      :key="c.key"
      type="button"
      role="tab"
      :aria-selected="c.key === caseClass"
      class="flex items-center gap-1.5 px-3 py-1 text-sm font-medium rounded-md"
      :class="
        c.key === caseClass
          ? 'bg-white text-slate-800 shadow-sm dark:bg-slate-700 dark:text-slate-100'
          : 'text-slate-500 hover:text-slate-700 dark:text-slate-400 dark:hover:text-slate-200'
      "
      @click="go(c.key)"
    >
      <span
        class="inline-block w-2 h-2 rounded-full"
        :style="{ backgroundColor: c.color }"
      />
      {{ $t(`${c.i18n}.NAME`) }}
    </button>
  </div>
</template>
