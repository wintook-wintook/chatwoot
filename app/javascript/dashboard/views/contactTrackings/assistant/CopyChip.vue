<script>
// proyecto@asistente_agentes_ia — UNA PIEZA COPIABLE DEL INVENTARIO
// ============================================================================
// Cada fuente, grupo, tipo de caso y etiqueta de la cuenta se muestra como la
// CADENA EXACTA que hay que escribir en el Entrenamiento, y tocarla la copia.
//
// POR QUÉ IMPORTA QUE SEA COPIABLE:
//   El motor reconoce estas cadenas con patrones exactos y falla en silencio si
//   no coinciden. Antes la pestaña las mostraba como texto: había que
//   retipearlas, y una @ruta con la fuente mal escrita parsea perfecto y no
//   consulta nada. Copiar en vez de retipear elimina una clase entera de error
//   —justo la que este módulo vino a cazar— en lugar de avisarla después.
//
// El aviso de copiado usa useAlert, el mismo del resto del dashboard.
// ============================================================================
import { useAlert } from 'dashboard/composables';

export default {
  props: {
    text: { type: String, required: true },
    // Lo que va al lado, en gris: el nombre de la fuente, cuántas respuestas
    // tiene el grupo. Contexto, no parte de lo que se copia.
    note: { type: String, default: '' },
  },
  methods: {
    async copy() {
      try {
        await navigator.clipboard.writeText(this.text);
        useAlert(
          this.$t('TRACKING_ASSISTANT_VIEW.COPIED', { text: this.text })
        );
      } catch (error) {
        // Sin permiso de portapapeles (o sin HTTPS) no se puede copiar. No es
        // motivo para romper nada: la cadena sigue a la vista para copiarla a
        // mano, que es exactamente lo que se hacía antes.
        useAlert(this.$t('TRACKING_ASSISTANT_VIEW.COPY_FAILED'));
      }
    },
  },
};
</script>

<template>
  <button
    class="inline-flex items-center gap-1.5 max-w-full px-2 py-1 font-mono text-xs text-left rounded cursor-pointer bg-slate-50 dark:bg-slate-900 text-slate-800 dark:text-slate-100 hover:bg-woot-50 dark:hover:bg-woot-800/30"
    :title="$t('TRACKING_ASSISTANT_VIEW.COPY_HINT')"
    @click="copy"
  >
    <span class="truncate">{{ text }}</span>
    <span v-if="note" class="shrink-0 text-slate-400 dark:text-slate-500">
      {{ note }}
    </span>
  </button>
</template>
