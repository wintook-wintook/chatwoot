<!--
  Campaña con Vendedor IA — cómo se ve la plantilla de WhatsApp en el teléfono del contacto (con las variables
  llenas de ejemplo: {{1}} → el nombre…). template: { header, body, footer, buttons }.
-->
<script>
export default {
  name: 'PhonePreview',
  props: {
    template: { type: Object, default: null },
    sample: { type: String, default: 'Mario' },
  },
  computed: {
    body() {
      return this.fill(this.template?.body);
    },
    header() {
      return this.fill(this.template?.header);
    },
  },
  methods: {
    fill(text) {
      return (text || '').replace(/\{\{\s*(\w+)\s*\}\}/g, (_m, key) =>
        key === '1' || key === 'name' || key === 'nombre'
          ? this.sample
          : `[${key}]`
      );
    },
  },
};
</script>

<template>
  <div
    class="w-full max-w-xs p-3 mx-auto rounded-2xl bg-[#efeae2] dark:bg-slate-700"
  >
    <div
      v-if="template"
      class="max-w-[90%] p-2 text-sm bg-white rounded-lg shadow-sm dark:bg-slate-800 text-slate-800 dark:text-slate-100"
    >
      <p v-if="header" class="m-0 mb-1 font-semibold">{{ header }}</p>
      <p class="m-0 whitespace-pre-line">{{ body }}</p>
      <p v-if="template.footer" class="m-0 mt-1 text-xs text-slate-500">
        {{ template.footer }}
      </p>
      <div
        v-for="button in template.buttons || []"
        :key="button"
        class="py-1 mt-1 text-xs text-center border-t text-woot-600 border-slate-100 dark:border-slate-700"
      >
        {{ button }}
      </div>
    </div>
    <p v-else class="m-0 text-xs text-center text-slate-500">
      {{ $t('CAMPAIGNS2.MESSAGES.NO_TEMPLATE_PREVIEW') }}
    </p>
  </div>
</template>
