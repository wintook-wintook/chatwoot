<script>
// proyecto@asistente_agentes_ia — F6
// ============================================================================
// "Probar sin enviar nada": una pregunta contra el Entrenamiento, sin tocar
// ninguna conversación.
//
// ESTO ES SOLO EL INFORME de UNA corrida. El campo, el botón y el historial
// viven en DryRunModal: probar un agente es hacerle varias preguntas seguidas y
// comparar, y con un panel fijo cada prueba borraba la anterior.
//
// (La primera versión estaba abajo del Entrenamiento y no en un modal, con el
// argumento de que un modal tapa el texto que se viene a corregir. El argumento
// suponía que se lee y se edita a la vez; en el uso real se prueban varias
// preguntas y DESPUÉS se edita, así que perder el historial costaba más que
// tapar el borrador un rato.)
//
// LO QUE MÁS IMPORTA DE ESTE PANEL es la primera línea, la rama. El comprobador
// ya dice si el Entrenamiento se ejecuta; lo que no puede decir es si rutea BIEN.
// Un Entrenamiento con tres ramas impecables puede mandar todas las preguntas de
// soporte a la rama comercial y parsear perfecto.
// ============================================================================
export default {
  props: {
    result: { type: Object, default: null },
  },
  computed: {
    routes() {
      return this.result?.routes || {};
    },
    source() {
      return this.result?.source || {};
    },
    caseReport() {
      return this.result?.case || {};
    },
    items() {
      return this.source.items || [];
    },
    // Cuando la rama elegida ES la por defecto, un fallo de clasificación aterriza
    // en el mismo sitio que un acierto y no se distingue. Es el único caso en el
    // que el resultado necesita una advertencia.
    chosenIsDefault() {
      return (
        this.routes.chosen &&
        this.routes.default &&
        this.routes.chosen === this.routes.default &&
        !this.routes.single
      );
    },
    // Por qué no hay fragmentos. Cada motivo se explica distinto porque cada uno
    // se arregla distinto: una fuente en vivo no es un error, una fuente que no
    // existe sí.
    sourceNoticeKey() {
      const map = {
        no_source: 'DRY_RUN_NO_SOURCE',
        unreadable: 'DRY_RUN_UNREADABLE',
        source_missing: 'DRY_RUN_SOURCE_MISSING',
        live_source: 'DRY_RUN_LIVE_SOURCE',
        embedding_failed: 'DRY_RUN_EMBEDDING_FAILED',
        no_match: 'DRY_RUN_NO_MATCH',
        unsupported_mode: 'DRY_RUN_UNSUPPORTED_MODE',
      };
      return map[this.source.reason] || null;
    },
  },
  methods: {
    percent(similarity) {
      return `${Math.round(similarity * 100)}%`;
    },
  },
};
</script>

<template>
  <div>
    <div v-if="result" class="flex flex-col gap-3 text-xs">
      <!-- RAMA — lo que el comprobador no podía contestar. -->
      <div>
        <span class="text-slate-500 dark:text-slate-400">
          {{ $t('TRACKING_ASSISTANT_VIEW.DRY_RUN_ROUTE') }}
        </span>
        <template v-if="routes.chosen">
          <span class="font-medium text-slate-800 dark:text-slate-100 ml-1">
            {{ routes.chosen }}
          </span>
          <span
            v-if="routes.description"
            class="text-slate-500 dark:text-slate-400"
          >
            — {{ routes.description }}
          </span>
        </template>
        <span v-else class="text-amber-700 dark:text-amber-400 ml-1">
          {{
            routes.none_declared
              ? $t('TRACKING_ASSISTANT_VIEW.DRY_RUN_ROUTE_NONE_DECLARED')
              : $t('TRACKING_ASSISTANT_VIEW.DRY_RUN_ROUTE_UNMATCHED')
          }}
        </span>

        <p
          v-if="chosenIsDefault"
          class="text-amber-700 dark:text-amber-400 mt-1"
        >
          {{ $t('TRACKING_ASSISTANT_VIEW.DRY_RUN_ROUTE_IS_DEFAULT') }}
        </p>
      </div>

      <!-- FUENTE -->
      <div>
        <span class="text-slate-500 dark:text-slate-400">
          {{ $t('TRACKING_ASSISTANT_VIEW.DRY_RUN_SOURCE') }}
        </span>
        <code v-if="source.directive" class="ml-1">{{ source.directive }}</code>
        <span v-else class="text-slate-500 dark:text-slate-400 ml-1">—</span>

        <p
          v-if="sourceNoticeKey"
          class="mt-1"
          :class="
            source.reason === 'live_source' || source.reason === 'no_source'
              ? 'text-slate-500 dark:text-slate-400'
              : 'text-amber-700 dark:text-amber-400'
          "
        >
          {{ $t(`TRACKING_ASSISTANT_VIEW.${sourceNoticeKey}`) }}
        </p>
      </div>

      <!-- FRAGMENTOS — si vuelven los equivocados, no hay redacción que lo salve. -->
      <div v-if="items.length">
        <p class="text-slate-500 dark:text-slate-400 mb-1">
          {{
            $t('TRACKING_ASSISTANT_VIEW.DRY_RUN_ITEMS', {
              count: items.length,
              threshold: source.threshold,
            })
          }}
        </p>
        <ul class="flex flex-col gap-2">
          <li
            v-for="(item, index) in items"
            :key="index"
            class="border-l-2 border-slate-200 dark:border-slate-600 pl-2"
          >
            <div class="flex items-baseline gap-2">
              <span class="font-medium text-slate-800 dark:text-slate-100">
                {{ item.title || '—' }}
              </span>
              <span class="text-slate-400 dark:text-slate-500">
                {{ percent(item.similarity) }}
              </span>
            </div>
            <p class="text-slate-500 dark:text-slate-400">
              {{ item.excerpt }}
            </p>
          </li>
        </ul>
      </div>

      <!-- ETIQUETA y CASO -->
      <div class="flex flex-col gap-1">
        <div>
          <span class="text-slate-500 dark:text-slate-400">
            {{ $t('TRACKING_ASSISTANT_VIEW.DRY_RUN_TAG') }}
          </span>
          <code v-if="result.tag" class="ml-1">{{ result.tag }}</code>
          <span v-else class="text-slate-500 dark:text-slate-400 ml-1">
            {{ $t('TRACKING_ASSISTANT_VIEW.DRY_RUN_TAG_NONE') }}
          </span>
        </div>

        <div>
          <span class="text-slate-500 dark:text-slate-400">
            {{ $t('TRACKING_ASSISTANT_VIEW.DRY_RUN_CASE') }}
          </span>
          <span v-if="!caseReport.creates" class="ml-1">
            {{ $t('TRACKING_ASSISTANT_VIEW.DRY_RUN_CASE_NO') }}
          </span>
          <template v-else>
            <span class="ml-1 text-slate-800 dark:text-slate-100">
              {{
                caseReport.after_source
                  ? $t('TRACKING_ASSISTANT_VIEW.DRY_RUN_CASE_AFTER')
                  : $t('TRACKING_ASSISTANT_VIEW.DRY_RUN_CASE_BEFORE')
              }}
            </span>
            <span
              v-if="caseReport.case_type"
              class="text-slate-500 dark:text-slate-400"
            >
              · {{ caseReport.case_type.name }}
            </span>
          </template>
        </div>

        <!-- El tipo escrito no existe: el caso se abre igual, pero con otro tipo. -->
        <p
          v-if="caseReport.case_type && !caseReport.case_type.exists"
          class="text-amber-700 dark:text-amber-400"
        >
          {{
            $t('TRACKING_ASSISTANT_VIEW.DRY_RUN_CASE_TYPE_MISSING', {
              name: caseReport.case_type.name,
            })
          }}
        </p>

        <!-- El hallazgo que más sorprende: una rama sin flecha NO queda sin
             escalamiento, hereda el @crear_ticket suelto del prompt. -->
        <p
          v-if="caseReport.inherited_from_prompt && caseReport.creates"
          class="text-amber-700 dark:text-amber-400"
        >
          {{ $t('TRACKING_ASSISTANT_VIEW.DRY_RUN_CASE_INHERITED') }}
        </p>
      </div>

      <p class="text-slate-400 dark:text-slate-500">
        {{
          $t('TRACKING_ASSISTANT_VIEW.DRY_RUN_FOOTER', { model: result.model })
        }}
      </p>
    </div>
  </div>
</template>
