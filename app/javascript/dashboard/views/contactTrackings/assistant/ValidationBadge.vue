<script>
// proyecto@asistente_agentes_ia — EL RESUMEN DEL COMPROBADOR, EN UNA LÍNEA
// ============================================================================
// Vive en la cabecera del acordeón de "Lo que el motor va a leer".
//
// POR QUÉ EXISTE COMO PIEZA APARTE:
//   El comprobador revalida en cada tecla, y esa señal es lo que hace distinta
//   a esta pantalla de un editor de texto. Pero el detalle ocupaba diez líneas
//   permanentes en la misma columna donde se escribe el Entrenamiento —que en
//   esta cuenta tiene 46 líneas de mediana y hasta 645—, así que el detalle se
//   colapsa y ESTO se queda siempre visible. Se conserva la señal y se devuelve
//   el alto al texto.
//
//   Está en su propio archivo, y no repetido en la cabecera, para que la regla
//   de cuándo algo está rojo esté escrita una sola vez.
//
// "0 ramas" va en rojo aunque no haya ningún hallazgo bloqueante: un
// Entrenamiento que parsea a cero ramas es sintácticamente impecable y no
// ejecuta nada. Es el estado que hay que gritar.
// ============================================================================
export default {
  props: {
    validation: { type: Object, default: null },
    isChecking: { type: Boolean, default: false },
  },
  computed: {
    routes() {
      return this.validation?.routes || [];
    },
    blocking() {
      return this.validation?.blocking || [];
    },
    hasNoRoutes() {
      return Boolean(this.validation) && this.routes.length === 0;
    },
    isBad() {
      return this.hasNoRoutes || this.blocking.length > 0;
    },
    label() {
      if (this.hasNoRoutes) {
        return this.$t('TRACKING_ASSISTANT_VIEW.REPORT_NO_ROUTES');
      }
      const routes = this.$t('TRACKING_ASSISTANT_VIEW.REPORT_ROUTES', {
        count: this.routes.length,
      });
      if (!this.blocking.length) return routes;

      return `${routes} · ${this.$t('TRACKING_ASSISTANT_VIEW.REPORT_BLOCKING', {
        count: this.blocking.length,
      })}`;
    },
  },
};
</script>

<template>
  <span
    v-if="isChecking"
    class="text-xs font-normal text-slate-400 dark:text-slate-500"
  >
    {{ $t('TRACKING_ASSISTANT_VIEW.REPORT_CHECKING') }}
  </span>
  <span
    v-else-if="validation"
    class="text-xs font-medium px-2 py-0.5 rounded"
    :class="
      isBad
        ? 'text-red-700 bg-red-100 dark:bg-red-900/30 dark:text-red-300'
        : 'text-green-700 bg-green-100 dark:bg-green-900/30 dark:text-green-300'
    "
  >
    {{ label }}
  </span>
</template>
