<script>
// feat/plantillas_whatsapp_mejoras F3 — EL ARCHIVO DEL ENCABEZADO DE UNA PLANTILLA
// ============================================================================
// Plan: docs/plantillas_whatsapp_mejoras_plan.md §4 (F3). Una plantilla con imagen, video
// o documento le llega al cliente con el archivo, pero el mensaje del agente solo guarda
// el texto del cuerpo: la burbuja no mostraba qué se mandó. El archivo ya viaja en
// additional_attributes.template_params.processed_params.header (F2), así que se pinta de
// ahí, sin migración.
//
// NO es un adjunto del mensaje (a propósito: un attachment normal se cruzaría con la ruta
// de envío de adjuntos), por eso no se usa BubbleImageAudioVideo: abre la galería de los
// adjuntos reales de la conversación, donde este archivo no está.
// ============================================================================
import BubbleFile from './File.vue';

export default {
  components: { BubbleFile },
  props: {
    // { media_url, media_type: 'image' | 'video' | 'document', media_name }
    header: {
      type: Object,
      required: true,
    },
  },
  emits: ['error'],
  computed: {
    url() {
      return this.header.media_url;
    },
    type() {
      return this.header.media_type;
    },
  },
};
</script>

<template>
  <div class="template-header">
    <a
      v-if="type === 'image'"
      :href="url"
      target="_blank"
      rel="noreferrer noopener nofollow"
    >
      <img
        :src="url"
        :alt="header.media_name || ''"
        class="max-w-full rounded-lg max-h-64"
        @error="$emit('error')"
      />
    </a>
    <video
      v-else-if="type === 'video'"
      :src="url"
      controls
      preload="metadata"
      class="max-w-full rounded-lg max-h-64"
      @error="$emit('error')"
    />
    <BubbleFile v-else :url="url" :name="header.media_name || ''" />
  </div>
</template>

<style scoped>
.template-header {
  margin-bottom: 0.5rem;
}
</style>
