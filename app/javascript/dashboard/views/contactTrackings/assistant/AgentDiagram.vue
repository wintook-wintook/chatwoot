<script>
// proyecto@diagrama_agente_ia — F1: LA PESTAÑA «DIAGRAMA»
// ============================================================================
// Plan: docs/diagrama_agente_ia_plan.md §4.2. Dibuja lo que calcula
// agentDiagramLayout.js (función pura, con su spec): una fila por ruta, de
// izquierda a derecha en el orden en que el motor la recorre, y debajo las
// secciones, que el agente lee completas en cada respuesta.
//
// SIN ILUMINAR (decisión D1): se ve siempre, mientras se crea el agente; la forma
// sola ya deja ver huecos (una ruta sin etiqueta, una fuente que falta).
//
// MAPA DE CALOR (F3): sin prueba elegida, `heat` (heatFromCases) dice cuántas pruebas
// de la pila pasan por cada ruta y cuántas fallaron en vivo: la línea del cliente a
// la ruta engorda con las pruebas, la ruta con fallas va en ámbar y la que no tiene
// ninguna, punteada («sin pruebas»: falta generarlas).
//
// ILUMINADO (F2): `test` es la prueba elegida en el panel Pruebas; su camino lo
// calcula testPath.js contra ESTE dibujo (`highlight`): lo
// recorrido con el color del tema, el punto débil (`failed`) en ámbar con ⚠, y lo
// demás tenue. Los detalles del camino (fragmentos, «por defecto») reemplazan la
// segunda línea del nodo.
//
// Clic en un nodo → su línea en el Entrenamiento (`goToRoute` / `goToSection`; la
// pantalla cambia a la pestaña del editor). El punto rojo/ámbar es el mismo
// hallazgo del comprobador que marca el árbol de la Estructura.
//
// EXPORTAR (F5): SVG o PNG (svgExport.js), con los estilos ya calculados y el fondo
// del panel, para pegarlo en un documento o mandarlo como evidencia.
//
// Colores con clases de Tailwind sobre el SVG (fill-/stroke-), así sigue al modo
// oscuro y a los temas del dashboard (woot-*) sin una paleta propia.
// ============================================================================
import EmptyState from 'dashboard/components/widgets/EmptyState.vue';
import { buildDiagram, NODE_H } from './agentDiagramLayout';
import { pathFromTrace, pathFromDryRun } from './testPath';
import { downloadSvg, downloadPng } from './svgExport';

const TRANSPARENT = ['rgba(0, 0, 0, 0)', 'transparent', ''];

export default {
  name: 'AgentDiagram',
  components: { EmptyState },
  props: {
    structure: { type: Object, default: () => ({ blocks: [] }) },
    issues: { type: Object, default: () => ({}) },
    // proyecto@diagrama_agente_ia F2: la prueba elegida ({ mode: 'dry', result } o
    // { mode: 'live', traza, reply }), o null.
    test: { type: Object, default: null },
    // F3: { ruta: { total, failed } } de la pila del agente, o null.
    heat: { type: Object, default: null },
    // F5: el nombre del archivo exportado, sin extensión.
    exportName: { type: String, default: 'diagrama-agente' },
  },
  emits: ['goToRoute', 'goToSection', 'clearHighlight'],
  computed: {
    blocks() {
      return (this.structure && this.structure.blocks) || [];
    },
    diagram() {
      return buildDiagram(this.blocks, this.issues);
    },
    isEmpty() {
      return !this.blocks.length;
    },
    issueCount() {
      return this.diagram.nodes.filter(n => n.issue).length;
    },
    nodeHeight() {
      return NODE_H;
    },
    // El ⚠ del punto débil: un símbolo, no un texto que traducir.
    warnMark() {
      return '⚠';
    },
    // El mapa de calor solo cuando hay pila y ninguna prueba elegida.
    showHeat() {
      return (
        !this.test && Boolean(this.heat) && Object.keys(this.heat).length > 0
      );
    },
    untestedRoutes() {
      if (!this.showHeat) return 0;
      return this.diagram.nodes.filter(
        n => n.kind === 'route' && !this.heatOf(n)
      ).length;
    },
    highlight() {
      if (!this.test) return null;
      return this.test.mode === 'dry'
        ? pathFromDryRun(this.test.result, this.diagram)
        : pathFromTrace(this.test.traza, this.diagram, this.test.reply);
    },
    litNodes() {
      return new Set(this.highlight ? this.highlight.nodes : []);
    },
    litEdges() {
      return new Set(this.highlight ? this.highlight.edges : []);
    },
    failedNodes() {
      return new Set(this.highlight ? this.highlight.failed : []);
    },
    highlightNote() {
      const nota = this.highlight && this.highlight.note;
      if (!nota) return '';
      return this.t(nota.key, this.noteArgs(nota.args));
    },
    highlightMode() {
      if (!this.highlight) return '';
      return this.t(this.highlight.mode === 'dry' ? 'MODE_DRY' : 'MODE_LIVE');
    },
  },
  methods: {
    t(key, args) {
      return this.$t(`TRACKING_ASSISTANT_VIEW.DIAGRAM.${key}`, args);
    },
    columnLabel(id) {
      return this.t(`COLUMN_${id.toUpperCase()}`);
    },
    // Las dos líneas de cada nodo: qué es y cuál.
    heading(n) {
      if (n.kind === 'client') return this.t('NODE_CLIENT');
      if (n.kind === 'welcome') return this.t('NODE_WELCOME');
      if (n.kind === 'conversational') return this.t('NODE_CONVERSATIONAL');
      if (n.kind === 'source') return this.t(`SOURCE_${n.sourceKind}`);
      if (n.kind === 'action') return this.t(`ACTION_${n.actionKind}`);
      if (n.kind === 'tag') return n.missing ? this.t('NODE_NO_TAG') : n.label;
      return n.label;
    },
    heatOf(n) {
      if (!this.heat || n.kind !== 'route') return null;
      return this.heat[n.target.name] || null;
    },
    detail(n) {
      const extra = this.highlight && this.highlight.details[n.id];
      if (extra) return this.t(extra.key, extra.args);
      if (this.showHeat && n.kind === 'route') {
        const calor = this.heatOf(n);
        return calor
          ? this.t('HEAT_ROUTE', { total: calor.total, failed: calor.failed })
          : this.t('HEAT_NONE');
      }
      if (n.kind === 'client') return this.t('NODE_CLIENT_SUB');
      if (n.kind === 'welcome') return this.t('NODE_WELCOME_SUB');
      if (n.kind === 'conversational') return this.t('NODE_CONVERSATIONAL_SUB');
      if (n.kind === 'route')
        return n.isDefault ? this.t('NODE_DEFAULT') : n.sub;
      if (n.kind === 'source' && n.sourceKind === 'NONE')
        return this.t('SOURCE_NONE_SUB');
      if (n.kind === 'tag') return n.missing ? this.t('NODE_NO_TAG_SUB') : '';
      return n.label;
    },
    tooltip(n) {
      const partes = [n.title];
      if (n.issue) partes.push(...n.issue.messages);
      return partes.filter(Boolean).join('\n');
    },
    // El camino de la nota se dice en palabras (CAMINO_kbase…), no con la llave.
    noteArgs(args) {
      if (!args || !args.camino) return args;
      return { ...args, camino: this.t(`CAMINO_${args.camino.toUpperCase()}`) };
    },
    dimmed(id) {
      return Boolean(this.highlight) && !this.litNodes.has(id);
    },
    edgeClass(edge) {
      if (this.litEdges.has(edge.id)) return 'stroke-woot-500';
      return 'stroke-slate-300 dark:stroke-slate-600';
    },
    // Con el mapa de calor, la línea del cliente a cada ruta engorda con sus pruebas.
    edgeWidth(edge) {
      if (this.litEdges.has(edge.id)) return 2.5;
      if (!this.showHeat || edge.from !== 'client') return 1.5;
      const ruta = this.diagram.nodes.find(n => n.id === edge.to);
      const calor = ruta && this.heatOf(ruta);
      return calor ? 1.5 + Math.min(calor.total, 6) * 0.75 : 1;
    },
    boxDash(n) {
      if (n.muted) return '4 3';
      if (this.showHeat && n.kind === 'route' && !this.heatOf(n)) return '4 3';
      return null;
    },
    boxClass(n) {
      if (this.failedNodes.has(n.id))
        return 'fill-amber-50 dark:fill-slate-800 stroke-amber-500';
      if (this.litNodes.has(n.id))
        return 'fill-woot-50 dark:fill-slate-700 stroke-woot-500';
      const calor = this.showHeat && this.heatOf(n);
      if (calor && calor.failed)
        return 'fill-amber-50 dark:fill-slate-800 stroke-amber-500';
      if (n.issue && n.issue.level === 'blocking')
        return 'fill-white dark:fill-slate-800 stroke-red-400 dark:stroke-red-500';
      if (n.kind === 'client')
        return 'fill-woot-50 dark:fill-slate-700 stroke-woot-300 dark:stroke-woot-600';
      if (n.muted || n.missing)
        return 'fill-slate-50 dark:fill-slate-900 stroke-slate-300 dark:stroke-slate-600';
      return 'fill-white dark:fill-slate-800 stroke-slate-200 dark:stroke-slate-600';
    },
    headingClass(n) {
      if (n.missing) return 'fill-amber-700 dark:fill-amber-400';
      if (n.muted) return 'fill-slate-500 dark:fill-slate-400';
      return 'fill-slate-800 dark:fill-slate-100';
    },
    dotClass(issue) {
      return issue.level === 'blocking'
        ? 'fill-red-500'
        : 'fill-amber-500 dark:fill-amber-400';
    },
    // El primer fondo no transparente hacia arriba: el del panel (claro u oscuro).
    background() {
      let el = this.$el;
      while (el && el.nodeType === 1) {
        const color = window.getComputedStyle(el).backgroundColor;
        if (!TRANSPARENT.includes(color)) return color;
        el = el.parentElement;
      }
      return '#ffffff';
    },
    exportSvg() {
      downloadSvg(this.$refs.svg, `${this.exportName}.svg`, this.background());
    },
    exportPng() {
      return Promise.resolve(
        downloadPng(this.$refs.svg, `${this.exportName}.png`, this.background())
      ).catch(() => {});
    },
    open(n) {
      if (!n.target) return;
      if (n.target.type === 'route') this.$emit('goToRoute', n.target.name);
      if (n.target.type === 'section')
        this.$emit('goToSection', n.target.index);
    },
  },
};
</script>

<template>
  <div class="flex flex-col flex-1 min-h-0 gap-3">
    <EmptyState
      v-if="isEmpty"
      :title="t('EMPTY_TITLE')"
      :message="t('EMPTY_MESSAGE')"
    />
    <template v-else>
      <div
        v-if="highlight"
        class="flex items-center justify-between gap-2 px-3 py-2 text-xs rounded-lg shrink-0 bg-woot-50 dark:bg-slate-700 text-slate-700 dark:text-slate-100"
      >
        <span>
          <strong>{{ highlightMode }}</strong>
          <span v-if="highlightNote"> · {{ highlightNote }}</span>
        </span>
        <woot-button
          size="tiny"
          variant="clear"
          color-scheme="secondary"
          icon="dismiss"
          @click="$emit('clearHighlight')"
        >
          {{ t('CLEAR_HIGHLIGHT') }}
        </woot-button>
      </div>
      <p v-else class="m-0 text-xs text-slate-500 dark:text-slate-400 shrink-0">
        {{ t('INTRO', { count: diagram.routeCount }) }}
        <span v-if="issueCount" class="text-amber-700 dark:text-amber-400">
          {{ t('ISSUES', { count: issueCount }) }}
        </span>
        <span v-if="untestedRoutes" class="text-amber-700 dark:text-amber-400">
          {{ t('HEAT_UNTESTED', { count: untestedRoutes }) }}
        </span>
      </p>

      <div class="flex-1 min-h-0 overflow-auto">
        <svg
          ref="svg"
          :width="diagram.width"
          :height="diagram.height"
          :viewBox="`0 0 ${diagram.width} ${diagram.height}`"
          role="img"
          :aria-label="t('ARIA', { count: diagram.routeCount })"
          class="block"
        >
          <text
            v-for="col in diagram.columns"
            :key="`col-${col.id}`"
            :x="col.center"
            y="18"
            text-anchor="middle"
            class="text-[10px] font-semibold tracking-wide uppercase fill-slate-400 dark:fill-slate-500"
          >
            {{ columnLabel(col.id) }}
          </text>

          <path
            v-for="edge in diagram.edges"
            :key="edge.id"
            :d="edge.d"
            fill="none"
            :stroke-width="edgeWidth(edge)"
            :stroke-dasharray="edge.dashed ? '4 4' : null"
            :opacity="highlight && !litEdges.has(edge.id) ? 0.35 : 1"
            :class="edgeClass(edge)"
          />

          <g
            v-for="n in diagram.nodes"
            :key="n.id"
            :transform="`translate(${n.x},${n.y})`"
            :opacity="dimmed(n.id) ? 0.35 : 1"
            :class="n.target ? 'cursor-pointer group' : ''"
            :role="n.target ? 'button' : null"
            :tabindex="n.target ? 0 : null"
            @click="open(n)"
            @keydown.enter="open(n)"
          >
            <title>{{ tooltip(n) }}</title>
            <rect
              :width="n.w"
              :height="n.h"
              rx="8"
              stroke-width="1.5"
              :stroke-dasharray="boxDash(n)"
              :class="[
                boxClass(n),
                n.target ? 'group-hover:stroke-woot-500' : '',
              ]"
            />
            <text
              x="12"
              :y="nodeHeight / 2 - 3"
              class="text-xs font-medium"
              :class="headingClass(n)"
            >
              {{ heading(n) }}
            </text>
            <text
              x="12"
              :y="nodeHeight / 2 + 12"
              class="text-[11px] fill-slate-500 dark:fill-slate-400"
            >
              {{ detail(n) }}
            </text>
            <text
              v-if="failedNodes.has(n.id)"
              :x="n.w - 18"
              :y="nodeHeight - 8"
              class="text-xs fill-amber-600"
            >
              {{ warnMark }}
            </text>
            <circle
              v-if="n.issue"
              :cx="n.w - 10"
              cy="10"
              r="4"
              :class="dotClass(n.issue)"
            />
          </g>
        </svg>
      </div>

      <div
        v-if="diagram.sections.length"
        class="flex flex-col gap-2 pt-3 border-t shrink-0 border-slate-100 dark:border-slate-700"
      >
        <p class="m-0 text-xs text-slate-500 dark:text-slate-400">
          {{ t('SECTIONS_HINT') }}
        </p>
        <div class="flex flex-wrap gap-1.5">
          <button
            v-for="s in diagram.sections"
            :key="`s-${s.index}`"
            type="button"
            class="inline-flex items-center gap-1.5 px-2 py-0.5 text-xs rounded-md border border-slate-200 dark:border-slate-600 text-slate-700 dark:text-slate-200 hover:border-woot-500"
            :title="s.issue ? s.issue.messages.join('\n') : s.title"
            @click="$emit('goToSection', s.index)"
          >
            <span
              v-if="s.issue"
              class="inline-block w-2 h-2 rounded-full"
              :class="
                s.issue.level === 'blocking' ? 'bg-red-500' : 'bg-amber-500'
              "
            />
            {{ s.title }}
          </button>
        </div>
      </div>

      <div class="flex flex-wrap items-center gap-2 shrink-0">
        <woot-button
          size="tiny"
          variant="clear"
          color-scheme="secondary"
          icon="arrow-download"
          @click="exportSvg"
        >
          {{ t('EXPORT_SVG') }}
        </woot-button>
        <woot-button
          size="tiny"
          variant="clear"
          color-scheme="secondary"
          icon="arrow-download"
          @click="exportPng"
        >
          {{ t('EXPORT_PNG') }}
        </woot-button>
      </div>
      <p
        class="flex flex-wrap m-0 text-[11px] gap-x-4 gap-y-1 text-slate-500 dark:text-slate-400 shrink-0"
      >
        <span>{{ t('LEGEND_DASHED') }}</span>
        <span>{{ t('LEGEND_DOT') }}</span>
        <span>{{ t('LEGEND_CLICK') }}</span>
        <span>{{ t('LEGEND_SOON') }}</span>
      </p>
    </template>
  </div>
</template>
