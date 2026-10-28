<!--
  Plan-Trabajo-Campo R1 — opciones de campo de un tipo de orden de trabajo:
  si se ejecuta en campo, qué pide para terminar (fotos de antes y después,
  conformidad) y si el reporte al cliente se manda solo o se revisa antes.
  El checklist son las tareas por etapa (pestaña Etapas).
-->
<script>
export default {
  name: 'FieldWorkTab',
  props: {
    caseType: { type: Object, required: true },
  },
  computed: {
    settings() {
      return this.caseType.field_settings || {};
    },
    toggles() {
      return ['on_site_default', 'require_photos', 'require_conformity'];
    },
  },
  methods: {
    label(key) {
      return this.$t(`SERVICE_REPORT.TYPE_SETTINGS.${key.toUpperCase()}`);
    },
    async save(changes) {
      try {
        await this.$store.dispatch('caseTickets/updateType', {
          id: this.caseType.id,
          field_settings: { ...this.settings, ...changes },
        });
        this.$emitter.emit('newToastMessage', {
          message: this.$t('CASE_TICKETS.SETTINGS.SAVED'),
        });
      } catch (_e) {
        this.$emitter.emit('newToastMessage', {
          message: this.$t('SERVICE_REPORT.ERROR'),
          type: 'error',
        });
      }
    },
  },
};
</script>

<template>
  <div
    class="flex flex-col gap-3 p-4 m-4 bg-white border rounded-lg dark:bg-slate-800 border-slate-75 dark:border-slate-700"
  >
    <h3 class="m-0 text-base font-semibold text-slate-800 dark:text-slate-100">
      {{ $t('SERVICE_REPORT.TYPE_SETTINGS.TITLE') }}
    </h3>
    <label
      v-for="key in toggles"
      :key="key"
      class="flex items-center gap-2 mb-0 text-sm"
    >
      <input
        type="checkbox"
        class="m-0"
        :checked="settings[key]"
        @change="save({ [key]: $event.target.checked })"
      />
      {{ label(key) }}
    </label>
    <label class="flex items-center gap-2 mb-0 text-sm">
      {{ $t('SERVICE_REPORT.TYPE_SETTINGS.DELIVERY') }}
      <select
        class="!mb-0 w-64"
        :value="settings.report_delivery"
        @change="save({ report_delivery: $event.target.value })"
      >
        <option value="auto">
          {{ $t('SERVICE_REPORT.TYPE_SETTINGS.DELIVERY_AUTO') }}
        </option>
        <option value="review">
          {{ $t('SERVICE_REPORT.TYPE_SETTINGS.DELIVERY_REVIEW') }}
        </option>
      </select>
    </label>
  </div>
</template>
