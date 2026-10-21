<!--
  @tickets_cases — Plan-Casos E1.1
  Tipo de caso junto al selector de clase (siguiente nivel: Comercial → «Oportunidad
  Big»). Solo ofrece los tipos de la clase. Recuerda el tipo por clase para que
  Lista, Tablero y Métricas abran en el mismo. `allowAll: false` = el tablero
  Comercial, que necesita un tipo para pintar sus columnas.
-->
<script>
import { mapGetters } from 'vuex';
import {
  rememberCaseType,
  lastCaseType,
  typesOfClass,
} from 'dashboard/helper/caseClasses';

export default {
  name: 'CaseTypeSelect',
  props: {
    caseClass: { type: String, required: true },
    value: { type: [String, Number], default: '' },
    allowAll: { type: Boolean, default: true },
  },
  emits: ['input'],
  data() {
    return { restoredFor: null };
  },
  computed: {
    ...mapGetters({
      types: 'caseTickets/getTypes',
      accountId: 'getCurrentAccountId',
    }),
    options() {
      return typesOfClass(this.types, this.caseClass);
    },
  },
  watch: {
    // Al cambiar de clase o al llegar los tipos, se elige el tipo recordado de
    // esa clase (o ninguno / el primero si el tablero exige uno).
    caseClass: { immediate: true, handler: 'restore' },
    options: 'restore',
  },
  methods: {
    restore() {
      if (!this.options.length) return;
      let next = this.value;
      // Una vez por clase: el tipo que el agente usó la última vez en ella.
      if (this.restoredFor !== this.caseClass) {
        const remembered = lastCaseType(this.accountId, this.caseClass);
        if (remembered !== '' && this.isValid(remembered)) next = remembered;
        this.restoredFor = this.caseClass;
      }
      if (!this.isValid(next)) next = this.allowAll ? '' : this.options[0].id;
      if (String(next) !== String(this.value)) this.$emit('input', next);
    },
    isSelected(id) {
      const current =
        this.value === null || this.value === undefined ? '' : this.value;
      return String(current) === String(id);
    },
    isValid(id) {
      if (id === '' || id === null || id === undefined) return this.allowAll;
      return this.options.some(t => String(t.id) === String(id));
    },
    onChange(event) {
      const raw = event.target.value;
      const id = raw === '' ? '' : Number(raw);
      rememberCaseType(this.accountId, this.caseClass, id);
      this.$emit('input', id);
    },
  },
};
</script>

<!-- La opción elegida se marca en cada <option> (`selected`), no con :value en
     el <select>: si las opciones llegan después del valor (los tipos cargan
     tarde), el <select> se quedaba mostrando «Todos los tipos» con un tipo
     aplicado. -->
<template>
  <select
    class="!mb-0 text-sm w-48"
    :aria-label="$t('CASE_TICKETS.FILTERS.TYPE')"
    @change="onChange"
  >
    <option v-if="allowAll" value="" :selected="isSelected('')">
      {{ $t('CASE_TICKETS.FILTERS.ALL_TYPES') }}
    </option>
    <option
      v-for="t in options"
      :key="t.id"
      :value="t.id"
      :selected="isSelected(t.id)"
    >
      {{ t.name }}
    </option>
  </select>
</template>
