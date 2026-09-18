<script>
// proyecto@asistente_agentes_ia — ESTRUCTURA DEL AGENTE
// ============================================================================
// Plan: docs/estructura_agente_arbol_plan.md. El Entrenamiento como árbol, con tres
// grupos fijos, y cada nodo se edita en un modal:
//
//   Definición del Agente   Objetivo y Contexto — NO están en el Entrenamiento:
//                           son columnas del agente (proposal mientras se arma)
//   Ramas                   una por línea @ruta, más la rama por defecto
//   Secciones               el texto inicial y cada rótulo con su cuerpo
//
// Solo dibuja y avisa qué se tocó: las operaciones sobre los bloques viven en
// trainingBlocks.js y el texto lo arma Ruby (training_preview).
//
// Medido sobre 28 agentes: hasta 31 secciones y 7 ramas en uno solo, así que el
// grupo de secciones se pliega solo cuando pasa de 8 — y 19 de 28 no tienen ninguna
// rama, por eso el grupo vacío se ve igual, con su "Agregar rama".
// ============================================================================
import {
  routeLines,
  defaultRouteName,
  canMoveSection,
  canMoveRoute,
} from './trainingBlocks';

const COLLAPSE_FROM = 8;

export default {
  props: {
    // La estructura del backend: { blocks: [...] }.
    value: { type: Object, default: () => ({ blocks: [] }) },
    // { name, objective, ai_context } o null: lo que se va a guardar en el agente.
    definition: { type: Object, default: null },
    // Hallazgos del comprobador por nodo: { 'route:soporte': 'blocking', … }
    issues: { type: Object, default: () => ({}) },
  },
  emits: [
    'editDefinition',
    'editRoute',
    'addRoute',
    'findRoute',
    'editSection',
    'addSection',
    'findSection',
    'moveSection',
    'moveRoute',
  ],
  data() {
    return {
      open: { definition: true, routes: true, sections: true },
    };
  },
  computed: {
    blocks() {
      return this.value?.blocks || [];
    },
    routes() {
      return routeLines(this.blocks).map((linea, position) => ({
        ...linea,
        position,
      }));
    },
    defaultRoute() {
      return defaultRouteName(this.blocks);
    },
    // Las secciones y el texto inicial, con su lugar en la lista de bloques (que es
    // lo que hace falta para editarlo o moverlo).
    sections() {
      return this.blocks
        .map((block, index) => ({ ...block, index }))
        .filter(b => b.type === 'section' || b.type === 'preamble');
    },
    tooManySections() {
      return this.sections.length >= COLLAPSE_FROM;
    },
  },
  watch: {
    // Otro agente (o el mismo separado de nuevo): con muchas secciones, plegadas.
    'value.blocks': {
      immediate: true,
      handler() {
        this.open = {
          ...this.open,
          sections: !this.tooManySections,
        };
      },
    },
  },
  methods: {
    toggle(grupo) {
      this.open = { ...this.open, [grupo]: !this.open[grupo] };
    },
    sectionName(block) {
      return block.type === 'preamble'
        ? this.$t('TRACKING_TEMPLATES.FORM.TRAINING.PREAMBLE')
        : block.title;
    },
    // Cuántas líneas tiene escritas: es lo que dice si un nodo está vacío.
    lineCount(block) {
      const texto = block.body || block.text || '';
      return texto.trim() ? texto.split('\n').length : 0;
    },
    canMove(index, delta) {
      return canMoveSection(this.blocks, index, delta);
    },
    canMoveR(position, delta) {
      return canMoveRoute(this.blocks, position, delta);
    },
    issue(clave) {
      return this.issues[clave] || '';
    },
    // Un grupo se marca con lo peor que tengan sus hijos.
    groupIssue(prefijo) {
      const suyos = Object.entries(this.issues).filter(([clave]) =>
        clave.startsWith(prefijo)
      );
      if (suyos.some(([, nivel]) => nivel === 'blocking')) return 'blocking';
      return suyos.length ? 'degrading' : '';
    },
    definitionValue(campo) {
      return (this.definition || {})[campo] || '';
    },
    // Una línea de lo escrito, para que el nodo diga algo sin abrir el modal.
    preview(texto, largo = 60) {
      const limpio = (texto || '').replace(/\s+/g, ' ').trim();
      return limpio.length > largo ? `${limpio.slice(0, largo)}…` : limpio;
    },
  },
};
</script>

<template>
  <div class="flex flex-col gap-1 text-sm">
    <!-- ── Definición del Agente ─────────────────────────────────────────── -->
    <button
      type="button"
      class="flex items-center w-full gap-1 px-1 py-1 text-left"
      @click="toggle('definition')"
    >
      <fluent-icon
        :icon="open.definition ? 'chevron-down' : 'chevron-right'"
        size="14"
      />
      <span class="font-semibold text-slate-700 dark:text-slate-200">
        {{ $t('TRACKING_ASSISTANT_VIEW.TREE_DEFINITION') }}
      </span>
    </button>
    <div v-if="open.definition" class="flex flex-col">
      <button
        v-for="campo in ['objective', 'ai_context']"
        :key="campo"
        type="button"
        class="flex items-center gap-2 py-1 pl-6 pr-1 text-left rounded hover:bg-slate-50 dark:hover:bg-slate-700"
        @click="$emit('editDefinition', campo)"
      >
        <span class="shrink-0 text-slate-700 dark:text-slate-200">
          {{
            campo === 'objective'
              ? $t('TRACKING_ASSISTANT_VIEW.TREE_OBJECTIVE')
              : $t('TRACKING_ASSISTANT_VIEW.TREE_CONTEXT')
          }}
        </span>
        <span
          class="flex-1 min-w-0 text-xs truncate"
          :class="
            definitionValue(campo)
              ? 'text-slate-500 dark:text-slate-400'
              : 'text-amber-600 dark:text-amber-400'
          "
        >
          {{
            preview(definitionValue(campo)) ||
            $t('TRACKING_ASSISTANT_VIEW.TREE_EMPTY')
          }}
        </span>
      </button>
    </div>

    <!-- ── Ramas ────────────────────────────────────────────────────────── -->
    <div class="flex items-center gap-1 px-1 py-1 mt-1">
      <button
        type="button"
        class="flex items-center flex-1 gap-1 text-left"
        @click="toggle('routes')"
      >
        <fluent-icon
          :icon="open.routes ? 'chevron-down' : 'chevron-right'"
          size="14"
        />
        <span class="font-semibold text-slate-700 dark:text-slate-200">
          {{ $t('TRACKING_ASSISTANT_VIEW.TREE_ROUTES') }}
        </span>
        <span class="text-xs text-slate-400">({{ routes.length }})</span>
        <!-- Un punto, no un carácter: el estado del grupo es lo peor que tengan
             sus hijos (ver groupIssue). -->
        <span
          v-if="groupIssue('route:')"
          class="w-1.5 h-1.5 rounded-full shrink-0"
          :class="
            groupIssue('route:') === 'blocking' ? 'bg-red-500' : 'bg-amber-500'
          "
        />
      </button>
      <!-- La acción del grupo, en su misma fila: agregar es lo que se hace desde
           el grupo, y con el nombre puesto no hay que adivinar qué agrega. Al lado,
           copiar una rama que la cuenta ya escribió (ver RouteCatalogModal). -->
      <woot-button
        type="button"
        size="tiny"
        variant="smooth"
        color-scheme="secondary"
        icon="search"
        @click="$emit('findRoute')"
      >
        {{ $t('TRACKING_TEMPLATES.FORM.TRAINING.ROUTE_FIND') }}
      </woot-button>
      <woot-button
        type="button"
        size="tiny"
        variant="smooth"
        color-scheme="success"
        icon="add"
        @click="$emit('addRoute')"
      >
        {{ $t('TRACKING_TEMPLATES.FORM.TRAINING.ROUTE_ADD') }}
      </woot-button>
    </div>
    <div v-if="open.routes" class="flex flex-col">
      <div
        v-for="rama in routes"
        :key="`r-${rama.position}`"
        class="flex items-center gap-2 pl-6 pr-1 rounded group/rama hover:bg-slate-50 dark:hover:bg-slate-700"
      >
        <button
          type="button"
          class="flex items-center flex-1 min-w-0 gap-2 py-1 text-left"
          @click="$emit('editRoute', rama.position)"
        >
          <span
            v-if="issue(`route:${rama.name}`)"
            class="w-1.5 h-1.5 rounded-full shrink-0"
            :class="
              issue(`route:${rama.name}`) === 'blocking'
                ? 'bg-red-500'
                : 'bg-amber-500'
            "
          />
          <span
            class="font-mono text-xs shrink-0 text-slate-700 dark:text-slate-200"
          >
            {{ rama.name || $t('TRACKING_ASSISTANT_VIEW.TREE_NO_NAME') }}
          </span>
          <span
            v-if="rama.name && rama.name === defaultRoute"
            class="px-1 text-xs rounded shrink-0 bg-slate-100 text-slate-500 dark:bg-slate-700 dark:text-slate-300"
          >
            {{ $t('TRACKING_ASSISTANT_VIEW.TREE_DEFAULT') }}
          </span>
          <span
            class="flex-1 min-w-0 text-xs truncate text-slate-500 dark:text-slate-400"
          >
            {{ preview(rama.description) }}
          </span>
        </button>
        <!-- El orden de las ramas es el orden de las líneas @ruta. -->
        <div class="flex items-center gap-1 shrink-0">
          <woot-button
            type="button"
            size="tiny"
            variant="smooth"
            color-scheme="success"
            icon="arrow-up"
            :is-disabled="!canMoveR(rama.position, -1)"
            :title="$t('TRACKING_TEMPLATES.FORM.TRAINING.MOVE_UP')"
            @click="$emit('moveRoute', { position: rama.position, delta: -1 })"
          />
          <woot-button
            type="button"
            size="tiny"
            variant="smooth"
            color-scheme="alert"
            icon="arrow-up"
            class="[&_svg]:rotate-180"
            :is-disabled="!canMoveR(rama.position, 1)"
            :title="$t('TRACKING_TEMPLATES.FORM.TRAINING.MOVE_DOWN')"
            @click="$emit('moveRoute', { position: rama.position, delta: 1 })"
          />
        </div>
      </div>
      <p
        v-if="!routes.length"
        class="!m-0 py-1 pl-6 text-xs text-slate-400 dark:text-slate-500"
      >
        {{ $t('TRACKING_ASSISTANT_VIEW.TREE_ROUTES_EMPTY') }}
      </p>
    </div>

    <!-- ── Secciones ────────────────────────────────────────────────────── -->
    <div class="flex items-center gap-1 px-1 py-1 mt-1">
      <button
        type="button"
        class="flex items-center flex-1 gap-1 text-left"
        @click="toggle('sections')"
      >
        <fluent-icon
          :icon="open.sections ? 'chevron-down' : 'chevron-right'"
          size="14"
        />
        <span class="font-semibold text-slate-700 dark:text-slate-200">
          {{ $t('TRACKING_ASSISTANT_VIEW.TREE_SECTIONS') }}
        </span>
        <span class="text-xs text-slate-400">({{ sections.length }})</span>
      </button>
      <woot-button
        type="button"
        size="tiny"
        variant="smooth"
        color-scheme="secondary"
        icon="search"
        @click="$emit('findSection')"
      >
        {{ $t('TRACKING_TEMPLATES.FORM.TRAINING.SECTION_FIND') }}
      </woot-button>
      <woot-button
        type="button"
        size="tiny"
        variant="smooth"
        color-scheme="success"
        icon="add"
        @click="$emit('addSection')"
      >
        {{ $t('TRACKING_TEMPLATES.FORM.TRAINING.ADD_SECTION') }}
      </woot-button>
    </div>
    <div v-if="open.sections" class="flex flex-col">
      <!-- La fila es un contenedor y no un botón: el nombre abre la sección y las
           flechas la mueven de lugar, y un botón adentro de otro no es válido. -->
      <div
        v-for="block in sections"
        :key="`s-${block.index}`"
        class="flex items-center gap-2 pl-6 pr-1 rounded group/fila hover:bg-slate-50 dark:hover:bg-slate-700"
      >
        <button
          type="button"
          class="flex items-center flex-1 min-w-0 gap-2 py-1 text-left"
          @click="$emit('editSection', block.index)"
        >
          <span
            v-if="issue(`section:${block.index}`)"
            class="w-1.5 h-1.5 rounded-full shrink-0"
            :class="
              issue(`section:${block.index}`) === 'blocking'
                ? 'bg-red-500'
                : 'bg-amber-500'
            "
          />
          <span
            class="text-xs font-semibold tracking-wide uppercase shrink-0 text-slate-700 dark:text-slate-200"
          >
            {{ sectionName(block) }}
          </span>
          <span
            class="flex-1 min-w-0 text-xs truncate text-slate-500 dark:text-slate-400"
          >
            {{
              lineCount(block)
                ? preview(block.body || block.text)
                : $t('TRACKING_ASSISTANT_VIEW.TREE_EMPTY')
            }}
          </span>
        </button>
        <!-- El orden importa: el agente lee las secciones en el orden en que están.
             Botones con color y SIEMPRE visibles —subir verde, bajar rojo—: con
             flechas grises y atenuadas nadie se enteraba de que se pueden reordenar. -->
        <div
          v-if="block.type === 'section'"
          class="flex items-center gap-1 shrink-0"
        >
          <woot-button
            type="button"
            size="tiny"
            variant="smooth"
            color-scheme="success"
            icon="arrow-up"
            :is-disabled="!canMove(block.index, -1)"
            :title="$t('TRACKING_TEMPLATES.FORM.TRAINING.MOVE_UP')"
            @click="$emit('moveSection', { index: block.index, delta: -1 })"
          />
          <woot-button
            type="button"
            size="tiny"
            variant="smooth"
            color-scheme="alert"
            icon="arrow-up"
            class="[&_svg]:rotate-180"
            :is-disabled="!canMove(block.index, 1)"
            :title="$t('TRACKING_TEMPLATES.FORM.TRAINING.MOVE_DOWN')"
            @click="$emit('moveSection', { index: block.index, delta: 1 })"
          />
        </div>
      </div>
      <p
        v-if="!sections.length"
        class="!m-0 py-1 pl-6 text-xs text-slate-400 dark:text-slate-500"
      >
        {{ $t('TRACKING_ASSISTANT_VIEW.TREE_SECTIONS_EMPTY') }}
      </p>
    </div>
  </div>
</template>
