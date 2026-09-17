<script>
// proyecto@asistente_agentes_ia — Entrenamiento por secciones
// ============================================================================
// Plan: docs/formulario_entrenamiento_plan.md. El Entrenamiento como tarjetas:
// ramas, texto inicial y una caja por sección, que se agregan, borran, reordenan
// y pliegan.
//
// Trabaja sobre la estructura que manda el backend ({ blocks }) y devuelve una
// NUEVA en cada cambio (v-model). No arma ni separa texto: eso vive solo en
// Ruby (TrainingStructure), y la ficha lo pide al endpoint training_preview.
//
// Cada bloque conserva `header` y `gap` tal como llegaron: son los que hacen que
// guardar sin tocar nada no cambie ni un carácter del prompt.
// ============================================================================

import RouteCards from './RouteCards.vue';
import RouteModal from './RouteModal.vue';

// Con muchas secciones (medido: hasta 31 en un agente) se abren plegadas; con
// pocas, abiertas.
const COLLAPSE_FROM = 8;

// La sección que lleva una línea por rama. El nombre del contrato es
// "[ALCANCE POR RAMA]", pero los agentes de la cuenta la escriben de varias formas.
const SCOPE_RE = /ALCANCE|SCOPE/i;

let uidCounter = 0;
const nextUid = () => {
  uidCounter += 1;
  return `b${uidCounter}`;
};
const withUid = block => ({ ...block, uid: block.uid || nextUid() });

export default {
  components: { RouteCards, RouteModal },
  props: {
    value: { type: Object, default: () => ({ blocks: [] }) },
    // { suggested: [...], from_account: [...] }
    // Explicar usa el endpoint del Asistente, que es solo de administradores.
    canExplain: { type: Boolean, default: false },
    titles: {
      type: Object,
      default: () => ({ suggested: [], from_account: [] }),
    },
    // Las listas del inventario para las tarjetas de rama (ver RouteCards).
    routeOptions: { type: Object, default: () => ({}) },
  },
  emits: ['input', 'explain'],
  data() {
    return {
      collapsed: {},
      confirmDelete: null,
      showAddMenu: false,
      customTitle: '',
      // Dónde insertan los selectores de directiva y adjunto.
      cursor: { uid: null, start: 0, end: 0 },
      showRouteModal: false,
    };
  },
  computed: {
    blocks() {
      return (this.value?.blocks || []).map(withUid);
    },
    sectionCount() {
      return this.blocks.filter(b => b.type === 'section').length;
    },
    hasRoutes() {
      return this.blocks.some(b => b.type === 'routes');
    },
    // El nombre con el que se crea la sección del alcance: el del contrato que manda
    // el backend en las sugerencias, y si no el del contrato tal cual.
    scopeTitle() {
      return (
        (this.titles.suggested || []).find(t => SCOPE_RE.test(t)) ||
        'ALCANCE POR RAMA'
      );
    },
    routeNames() {
      return this.blocks
        .filter(b => b.type === 'routes')
        .flatMap(b => b.lines || [])
        .filter(l => l.kind === 'route')
        .map(l => l.name);
    },
    usedTitles() {
      return new Set(
        this.blocks
          .filter(b => b.type === 'section')
          .map(b => (b.title || '').trim().toUpperCase())
      );
    },
    suggestions() {
      const libres = list =>
        (list || []).filter(t => !this.usedTitles.has(t.toUpperCase()));
      return {
        suggested: libres(this.titles.suggested),
        fromAccount: libres(this.titles.from_account),
      };
    },
  },
  watch: {
    // Una estructura nueva (otro agente, o separada de nuevo desde el texto) decide
    // de cero qué va plegado.
    'value.blocks': {
      immediate: true,
      handler(nuevos, viejos) {
        if (viejos && nuevos && nuevos.length === viejos.length) return;
        const plegar = this.sectionCount >= COLLAPSE_FROM;
        this.collapsed = Object.fromEntries(
          this.blocks.map(b => [b.uid, plegar && b.type === 'section'])
        );
      },
    },
  },
  methods: {
    emitBlocks(blocks) {
      this.$emit('input', { ...this.value, blocks });
    },
    update(index, changes) {
      const blocks = [...this.blocks];
      blocks[index] = { ...blocks[index], ...changes };
      this.emitBlocks(blocks);
    },
    move(index, delta) {
      const destino = index + delta;
      if (destino < 0 || destino >= this.blocks.length) return;
      const blocks = [...this.blocks];
      [blocks[index], blocks[destino]] = [blocks[destino], blocks[index]];
      // Lo que quedó último no deja renglón en blanco colgando; lo que dejó de serlo,
      // sí lo necesita para no quedar pegado al siguiente.
      this.emitBlocks(this.withGaps(blocks));
    },
    remove(index) {
      const block = this.blocks[index];
      const tieneTexto = (block.body || block.text || '').trim().length > 0;
      if (tieneTexto && this.confirmDelete !== block.uid) {
        this.confirmDelete = block.uid;
        return;
      }
      this.confirmDelete = null;
      this.emitBlocks(this.withGaps(this.blocks.filter((_, i) => i !== index)));
    },
    addSection(title) {
      const limpio = (title || '').replace(/[[\]\n\r]/g, ' ').trim();
      if (!limpio) return;
      const nueva = withUid({
        type: 'section',
        title: limpio,
        body: '',
        gap: 1,
      });
      this.collapsed = { ...this.collapsed, [nueva.uid]: false };
      this.emitBlocks(this.withGaps([...this.blocks, nueva]));
      this.customTitle = '';
      this.showAddMenu = false;
      this.$nextTick(() => this.focusBody(nueva.uid));
    },
    // Una rama entra por el modal, con su línea de alcance: las dos mitades juntas
    // (ver RouteModal). Acá se la mete en el bloque de ramas —creándolo si es el
    // primero— y en la sección [ALCANCE POR RAMA].
    addRouteFromModal({ route, scope }) {
      this.showRouteModal = false;
      let blocks = [...this.blocks];
      let indice = blocks.findIndex(b => b.type === 'routes');
      if (indice < 0) {
        blocks = [
          withUid({ type: 'routes', text: '', gap: 1, lines: [] }),
          ...blocks,
        ];
        indice = 0;
      }
      const lineas = [...(blocks[indice].lines || [])];
      // Antes de la rama por defecto, que por convención va al final del bloque.
      const corte = lineas.findIndex(l => l.kind === 'default');
      lineas.splice(corte < 0 ? lineas.length : corte, 0, route);
      blocks[indice] = { ...blocks[indice], lines: lineas };
      this.emitBlocks(
        this.withGaps(this.withScopeLine(blocks, route.name, scope))
      );
    },
    // La línea de la rama en [ALCANCE POR RAMA]. Si la sección no está, se crea
    // después de la primera sección (o al final si el Entrenamiento no tiene ninguna).
    withScopeLine(blocks, name, scope) {
      if (!scope) return blocks;
      const linea = `${name}: ${scope}`;
      const indice = blocks.findIndex(
        b => b.type === 'section' && SCOPE_RE.test(b.title || '')
      );
      if (indice >= 0) {
        const cuerpo = (blocks[indice].body || '').replace(/\n+$/, '');
        const nuevos = [...blocks];
        nuevos[indice] = {
          ...nuevos[indice],
          body: cuerpo ? `${cuerpo}\n${linea}` : linea,
        };
        return nuevos;
      }
      const seccion = withUid({
        type: 'section',
        title: this.scopeTitle,
        body: linea,
        gap: 1,
      });
      const primera = blocks.findIndex(b => b.type === 'section');
      const donde = primera < 0 ? blocks.length : primera + 1;
      return [...blocks.slice(0, donde), seccion, ...blocks.slice(donde)];
    },
    // Entre bloques, un renglón en blanco como mínimo; el último, sin colgar.
    withGaps(blocks) {
      return blocks.map((b, i) => ({
        ...b,
        gap: i === blocks.length - 1 ? b.gap || 0 : Math.max(b.gap || 0, 1),
      }));
    },
    toggle(uid) {
      this.collapsed = { ...this.collapsed, [uid]: !this.collapsed[uid] };
    },
    focusBody(uid) {
      const el = this.$refs[`body-${uid}`];
      const area = Array.isArray(el) ? el[0] : el;
      if (area) area.focus();
    },
    rememberCursor(uid, event) {
      this.cursor = {
        uid,
        start: event.target.selectionStart,
        end: event.target.selectionEnd,
      };
    },
    // Lo usan los selectores de directiva y adjunto de la ficha: inserta en la caja
    // donde estaba el cursor, o en la última sección si no hubo ninguna activa.
    insertToken(token) {
      const index = this.cursor.uid
        ? this.blocks.findIndex(b => b.uid === this.cursor.uid)
        : this.blocks.map(b => b.type).lastIndexOf('section');
      if (index < 0) return false;
      const block = this.blocks[index];
      const campo = block.type === 'section' ? 'body' : 'text';
      const actual = block[campo] || '';
      const pos =
        this.cursor.uid === block.uid ? this.cursor.start : actual.length;
      const antes = actual.slice(0, pos);
      const despues = actual.slice(pos);
      const separador = antes && !/\s$/.test(antes) ? ' ' : '';
      // Un espacio después solo si lo que sigue no empieza con uno: si no, queda doble.
      const cierre = /^\s/.test(despues) ? '' : ' ';
      this.update(index, {
        [campo]: `${antes}${separador}${token}${cierre}${despues}`,
      });
      this.collapsed = { ...this.collapsed, [block.uid]: false };
      return true;
    },
    rowsFor(texto) {
      const lineas = (texto || '').split('\n').length;
      return Math.min(Math.max(lineas, 3), 18);
    },
    lineCount(block) {
      const texto = block.body || block.text || '';
      return texto.trim() ? texto.split('\n').length : 0;
    },
    // El fragmento que se manda a explicar: la sección con su rótulo, así el modelo
    // sabe de qué parte del Entrenamiento se trata.
    explain(block) {
      const cuerpo = block.type === 'section' ? block.body : block.text;
      const rotulo =
        block.type === 'section' ? block.header || `[${block.title}]` : '';
      const fragmento = [rotulo, cuerpo].filter(Boolean).join('\n').trim();
      if (fragmento) this.$emit('explain', fragmento);
    },
    blockTitle(block) {
      if (block.type === 'routes')
        return this.$t('TRACKING_TEMPLATES.FORM.TRAINING.ROUTES');
      if (block.type === 'preamble')
        return this.$t('TRACKING_TEMPLATES.FORM.TRAINING.PREAMBLE');
      return block.title;
    },
  },
};
</script>

<template>
  <div class="flex flex-col gap-2">
    <p
      v-if="!blocks.length"
      class="px-3 py-4 text-sm text-center rounded-md text-slate-500 bg-slate-50 dark:bg-slate-800 dark:text-slate-400"
    >
      {{ $t('TRACKING_TEMPLATES.FORM.TRAINING.EMPTY') }}
    </p>

    <div
      v-for="(block, index) in blocks"
      :key="block.uid"
      class="border rounded-md border-slate-200 dark:border-slate-600 bg-white dark:bg-slate-900"
    >
      <div class="flex items-center gap-2 px-3 py-2">
        <button
          type="button"
          class="flex items-center min-w-0 gap-1 text-left text-slate-500 dark:text-slate-400"
          :title="$t('TRACKING_TEMPLATES.FORM.TRAINING.TOGGLE')"
          @click="toggle(block.uid)"
        >
          <fluent-icon
            :icon="collapsed[block.uid] ? 'chevron-right' : 'chevron-down'"
            size="14"
          />
        </button>
        <input
          v-if="block.type === 'section'"
          :id="`section-title-${block.uid}`"
          :value="block.title"
          type="text"
          class="flex-1 min-w-0 !mb-0 !py-1 font-mono text-xs font-semibold uppercase"
          :aria-label="$t('TRACKING_TEMPLATES.FORM.TRAINING.SECTION_NAME')"
          @input="update(index, { title: $event.target.value })"
        />
        <span
          v-else
          class="flex-1 text-xs font-semibold tracking-wide uppercase text-slate-600 dark:text-slate-300"
        >
          {{ blockTitle(block) }}
        </span>
        <span
          v-if="collapsed[block.uid]"
          class="text-xs text-slate-400 whitespace-nowrap"
        >
          {{
            $t('TRACKING_TEMPLATES.FORM.TRAINING.LINES', {
              count: lineCount(block),
            })
          }}
        </span>
        <div class="flex items-center gap-1 shrink-0">
          <woot-button
            v-if="canExplain"
            type="button"
            size="tiny"
            variant="clear"
            color-scheme="secondary"
            icon="info"
            :title="$t('TRACKING_TEMPLATES.FORM.TRAINING.EXPLAIN')"
            @click="explain(block)"
          />
          <woot-button
            type="button"
            size="tiny"
            variant="clear"
            color-scheme="secondary"
            icon="arrow-up"
            :is-disabled="index === 0"
            :title="$t('TRACKING_TEMPLATES.FORM.TRAINING.MOVE_UP')"
            @click="move(index, -1)"
          />
          <woot-button
            type="button"
            size="tiny"
            variant="clear"
            color-scheme="secondary"
            icon="arrow-up"
            class="[&_svg]:rotate-180"
            :is-disabled="index === blocks.length - 1"
            :title="$t('TRACKING_TEMPLATES.FORM.TRAINING.MOVE_DOWN')"
            @click="move(index, 1)"
          />
          <woot-button
            type="button"
            size="tiny"
            :variant="confirmDelete === block.uid ? 'smooth' : 'clear'"
            color-scheme="alert"
            icon="delete"
            :title="$t('TRACKING_TEMPLATES.FORM.TRAINING.DELETE')"
            @click="remove(index)"
          >
            <template v-if="confirmDelete === block.uid">
              {{ $t('TRACKING_TEMPLATES.FORM.TRAINING.CONFIRM_DELETE') }}
            </template>
          </woot-button>
        </div>
      </div>

      <div v-show="!collapsed[block.uid]" class="px-3 pb-3">
        <!-- Las ramas se editan en tarjetas: nombre, etiqueta, frases, fuente y
             escalamiento, con listas del inventario. La caja con las líneas crudas
             sigue disponible en la vista Texto del Entrenamiento. -->
        <RouteCards
          v-if="block.type === 'routes' && block.lines"
          :lines="block.lines"
          :options="routeOptions"
          @input="update(index, { lines: $event })"
          @add="showRouteModal = true"
        />
        <textarea
          v-else
          :id="`section-body-${block.uid}`"
          :ref="`body-${block.uid}`"
          :value="block.type === 'section' ? block.body : block.text"
          :rows="rowsFor(block.type === 'section' ? block.body : block.text)"
          :class="{ 'font-mono': block.type === 'routes' }"
          class="w-full !mb-0 text-sm bg-white dark:bg-slate-900 text-slate-900 dark:text-slate-100 border border-slate-200 dark:border-slate-600 rounded-md px-3 py-2 focus:outline-none focus:ring-1 focus:ring-woot-200 focus:border-woot-200"
          :placeholder="
            block.type === 'routes'
              ? $t('TRACKING_TEMPLATES.FORM.TRAINING.ROUTES_PLACEHOLDER')
              : $t('TRACKING_TEMPLATES.FORM.TRAINING.BODY_PLACEHOLDER')
          "
          @input="
            update(index, {
              [block.type === 'section' ? 'body' : 'text']: $event.target.value,
            })
          "
          @select="rememberCursor(block.uid, $event)"
          @keyup="rememberCursor(block.uid, $event)"
          @click="rememberCursor(block.uid, $event)"
        />
      </div>
    </div>

    <div class="flex flex-wrap items-start gap-2 pt-1">
      <div class="relative">
        <woot-button
          type="button"
          size="small"
          variant="smooth"
          icon="add"
          @click="showAddMenu = !showAddMenu"
        >
          {{ $t('TRACKING_TEMPLATES.FORM.TRAINING.ADD_SECTION') }}
        </woot-button>
        <div
          v-if="showAddMenu"
          class="absolute left-0 z-10 flex flex-col gap-2 p-3 mt-1 bg-white border rounded-md shadow-lg w-72 dark:bg-slate-800 border-slate-200 dark:border-slate-600"
        >
          <p
            v-if="suggestions.suggested.length"
            class="!m-0 text-xs text-slate-500"
          >
            {{ $t('TRACKING_TEMPLATES.FORM.TRAINING.SUGGESTED') }}
          </p>
          <div class="flex flex-wrap gap-1">
            <button
              v-for="title in suggestions.suggested"
              :key="`s-${title}`"
              type="button"
              class="px-2 py-0.5 text-xs font-mono border rounded border-slate-200 dark:border-slate-600 hover:border-woot-400"
              @click="addSection(title)"
            >
              {{ title }}
            </button>
          </div>
          <p
            v-if="suggestions.fromAccount.length"
            class="!m-0 text-xs text-slate-500"
          >
            {{ $t('TRACKING_TEMPLATES.FORM.TRAINING.FROM_ACCOUNT') }}
          </p>
          <div class="flex flex-wrap gap-1">
            <button
              v-for="title in suggestions.fromAccount"
              :key="`a-${title}`"
              type="button"
              class="px-2 py-0.5 text-xs font-mono border rounded border-slate-200 dark:border-slate-600 hover:border-woot-400"
              @click="addSection(title)"
            >
              {{ title }}
            </button>
          </div>
          <div class="flex gap-1">
            <input
              id="training-custom-section"
              v-model="customTitle"
              type="text"
              class="flex-1 !mb-0 !py-1 text-xs uppercase"
              :placeholder="$t('TRACKING_TEMPLATES.FORM.TRAINING.CUSTOM')"
              @keydown.enter.prevent="addSection(customTitle)"
            />
            <woot-button
              type="button"
              size="small"
              :is-disabled="!customTitle.trim()"
              @click="addSection(customTitle)"
            >
              {{ $t('TRACKING_TEMPLATES.FORM.TRAINING.ADD') }}
            </woot-button>
          </div>
        </div>
      </div>
      <woot-button
        v-if="!hasRoutes"
        type="button"
        size="small"
        variant="clear"
        color-scheme="secondary"
        @click="showRouteModal = true"
      >
        {{ $t('TRACKING_TEMPLATES.FORM.TRAINING.ADD_ROUTES') }}
      </woot-button>
    </div>

    <RouteModal
      :show="showRouteModal"
      :options="routeOptions"
      :taken-names="routeNames"
      @close="showRouteModal = false"
      @save="addRouteFromModal"
    />
  </div>
</template>
