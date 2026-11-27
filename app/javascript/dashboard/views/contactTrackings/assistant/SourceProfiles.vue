<script>
// proyecto@crear_agente_conversando — FR: LO QUE TIENE CADA FUENTE
// ============================================================================
// Plan: docs/creacion_conversacional_agentes_plan.md §12.3 A. El catálogo dice qué
// directivas hay; esto dice qué hay DENTRO de cada fuente de la cuenta (columnas y
// filas de una hoja, partes de un documento, grupos de predefinidas, campos de un tipo
// de caso), qué se le puede preguntar y cómo va en una ruta. Lo arma el backend sin IA
// (SourceProfiles); aquí solo se dibuja.
// ============================================================================
import CopyChip from './CopyChip.vue';

export default {
  components: { CopyChip },
  props: {
    profiles: { type: Array, default: () => [] },
    // Lo que la cuenta no tiene: google_sheet, google_doc, article, canned_response, case_type.
    missing: { type: Array, default: () => [] },
  },
  computed: {
    missingText() {
      return this.missing
        .map(m => this.$t(`TRACKING_ASSISTANT_VIEW.PROFILES_MISSING_${m}`))
        .join(' · ');
    },
  },
  methods: {
    examples(perfil) {
      const ejemplo = perfil.ejemplo;
      if (!ejemplo) return [];
      if (Array.isArray(ejemplo)) return ejemplo;
      // Predefinidas: { GRUPO: [códigos] }.
      return Object.entries(ejemplo).map(
        ([grupo, codigos]) => `${grupo}: ${codigos.join(', ')}`
      );
    },
  },
};
</script>

<template>
  <section class="flex flex-col gap-3">
    <div>
      <h3
        class="!mb-1 text-sm font-semibold text-slate-800 dark:text-slate-100"
      >
        {{ $t('TRACKING_ASSISTANT_VIEW.PROFILES_TITLE') }}
      </h3>
      <p class="!m-0 text-sm text-slate-600 dark:text-slate-300">
        {{ $t('TRACKING_ASSISTANT_VIEW.PROFILES_HINT') }}
      </p>
    </div>
    <p
      v-if="!profiles.length"
      class="!m-0 text-sm text-amber-800 dark:text-amber-800"
    >
      {{ $t('TRACKING_ASSISTANT_VIEW.PROFILES_EMPTY') }}
    </p>
    <div class="grid gap-3 md:grid-cols-2 xl:grid-cols-3">
      <article
        v-for="perfil in profiles"
        :key="`${perfil.tipo}-${perfil.nombre}`"
        class="flex flex-col gap-2 p-4 bg-white border rounded-lg dark:bg-slate-800 border-slate-100 dark:border-slate-700"
      >
        <div class="flex items-baseline justify-between gap-2">
          <span class="font-medium text-slate-800 dark:text-slate-100">
            {{ perfil.nombre }}
          </span>
          <span class="text-xs text-slate-500 dark:text-slate-400">
            {{ $t(`TRACKING_ASSISTANT_VIEW.PROFILES_TYPE_${perfil.tipo}`) }}
          </span>
        </div>
        <p class="!m-0 text-sm text-slate-700 dark:text-slate-200">
          {{ perfil.que_tiene }}
        </p>
        <ul
          v-if="examples(perfil).length"
          class="!m-0 !pl-4 text-xs list-disc text-slate-500 dark:text-slate-400"
        >
          <li v-for="(linea, i) in examples(perfil).slice(0, 4)" :key="i">
            {{ linea }}
          </li>
        </ul>
        <p class="!m-0 text-xs text-slate-600 dark:text-slate-300">
          <span class="font-medium">
            {{ $t('TRACKING_ASSISTANT_VIEW.PROFILES_ASK') }}
          </span>
          {{ perfil.se_le_puede_preguntar }}
        </p>
        <div class="flex flex-wrap gap-1.5">
          <CopyChip :text="perfil.como_se_usa" />
          <CopyChip v-if="perfil.ruta_sugerida" :text="perfil.ruta_sugerida" />
        </div>
      </article>
    </div>
    <p
      v-if="missing.length"
      class="!m-0 text-xs text-slate-500 dark:text-slate-400"
    >
      {{ $t('TRACKING_ASSISTANT_VIEW.PROFILES_MISSING') }}
      {{ missingText }}
    </p>
  </section>
</template>
