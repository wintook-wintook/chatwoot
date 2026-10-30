<script>
// feat/plantillas_whatsapp_mejoras F10 — la plantilla como la verá el cliente en WhatsApp
// (sale del modal de Index.vue, F6): el archivo real del encabezado, el texto con los
// ejemplos de las variables, el pie y los botones.
import { substituteVariables } from 'dashboard/helper/whatsappTemplateValidator';
import { MEDIA_HEADER_TYPES } from './templateEditor';

const BUTTON_ICONS = {
  URL: 'open',
  PHONE_NUMBER: 'call',
  COPY_CODE: 'copy',
  QUICK_REPLY: 'arrow-reply',
};

export default {
  props: {
    form: {
      type: Object,
      required: true,
    },
  },
  computed: {
    headerText() {
      if (this.form.header_type !== 'text') return '';
      return substituteVariables(
        this.form.header_content,
        this.form.sample_values.header
      );
    },
    isMedia() {
      return MEDIA_HEADER_TYPES.includes(this.form.header_type);
    },
    mediaUrl() {
      if (!this.isMedia) return '';
      return this.form.header_preview_url || this.form.header_media_url || '';
    },
    documentName() {
      if (this.form.header_sample_name) return this.form.header_sample_name;
      const liga = this.form.header_media_url || '';
      return (
        liga.split('?')[0].split('/').pop() ||
        this.$t('WHATSAPP_TEMPLATE_EDITOR.PREVIEW.DOCUMENT')
      );
    },
    mediaPlaceholder() {
      return this.isMedia
        ? this.$t(
            `WHATSAPP_TEMPLATE_EDITOR.HEADER_TYPES.${this.form.header_type.toUpperCase()}`
          )
        : '';
    },
    body() {
      return substituteVariables(
        this.form.body_text,
        this.form.sample_values.body
      );
    },
    buttons() {
      return this.form.buttons.map(boton => ({
        icon: BUTTON_ICONS[boton.type] || 'arrow-reply',
        text:
          boton.type === 'COPY_CODE'
            ? this.$t('WHATSAPP_TEMPLATE_EDITOR.PREVIEW.COPY_CODE')
            : boton.text || this.$t('WHATSAPP_TEMPLATE_EDITOR.PREVIEW.BUTTON'),
      }));
    },
  },
};
</script>

<template>
  <div>
    <div
      class="rounded-lg p-3 text-sm shadow-sm bg-green-50 dark:bg-green-900/30 border border-solid border-green-100 dark:border-green-800 text-slate-800 dark:text-slate-100"
    >
      <div v-if="headerText" class="font-semibold mb-1">{{ headerText }}</div>
      <img
        v-else-if="mediaUrl && form.header_type === 'image'"
        :src="mediaUrl"
        alt=""
        class="mb-2 rounded max-h-48 w-full object-cover"
      />
      <video
        v-else-if="mediaUrl && form.header_type === 'video'"
        :src="mediaUrl"
        controls
        preload="metadata"
        class="mb-2 rounded max-h-48 w-full"
      />
      <div
        v-else-if="mediaUrl && form.header_type === 'document'"
        class="flex items-center gap-2 mb-2 rounded px-3 py-3 bg-black/5 dark:bg-white/10"
      >
        <fluent-icon icon="document" size="24" class="text-red-500" />
        <span class="truncate">{{ documentName }}</span>
      </div>
      <div
        v-else-if="isMedia"
        class="mb-2 rounded px-3 py-6 text-center text-slate-400 bg-black/5 dark:bg-white/10"
      >
        {{ mediaPlaceholder }}
      </div>
      <div class="whitespace-pre-wrap break-words">
        {{ body || $t('WHATSAPP_TEMPLATE_EDITOR.PREVIEW.BODY_EMPTY') }}
      </div>
      <div v-if="form.footer_text" class="text-xs text-slate-400 mt-1">
        {{ form.footer_text }}
      </div>
      <div
        v-if="buttons.length"
        class="mt-2 -mx-3 px-3 pt-1 border-0 border-t border-solid border-green-200 dark:border-green-800"
      >
        <div
          v-for="(boton, i) in buttons"
          :key="i"
          class="flex items-center justify-center gap-1 py-1 text-sky-600 dark:text-sky-400"
        >
          <fluent-icon :icon="boton.icon" size="14" />
          <span>{{ boton.text }}</span>
        </div>
      </div>
    </div>
    <p class="mt-2 text-xs text-center text-slate-400">
      {{ $t('WHATSAPP_TEMPLATE_EDITOR.PREVIEW.CAPTION') }}
    </p>
  </div>
</template>
