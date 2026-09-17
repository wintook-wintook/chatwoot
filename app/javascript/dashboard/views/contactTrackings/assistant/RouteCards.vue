<script>
// proyecto@asistente_agentes_ia — LAS RAMAS COMO TARJETAS
// ============================================================================
// Fase 2 de §7 del plan (docs/formulario_entrenamiento_plan.md). El bloque de
// ramas era una caja con las líneas `@ruta` crudas: la parte del Entrenamiento
// con la gramática más estricta, escrita a mano.
//
// Cada rama es una tarjeta con sus campos, y fuente, etiqueta y escalamiento
// salen de LISTAS del inventario de la cuenta: así no se puede elegir una fuente,
// una etiqueta o un tipo de caso que no exista — que es de donde salieron los dos
// defectos que se vieron en vivo ("cuesta 15" con la hoja equivocada y el
// calendario borrado que dejó al agente sin disponibilidad).
//
// No arma ni separa las líneas: eso vive en Ruby (TrainingRoutes) y el texto lo
// devuelve el endpoint training_preview. Acá se editan campos y se emite la lista.
// Lo que el parser no reconoció viaja como `other` y se muestra igual, tal cual:
// esconderlo lo borraría al guardar.
// ============================================================================
// Las prioridades que entiende @crear_ticket(prioridad=…), en las palabras que acepta
// el motor (Cases::TicketCreatorService::PRIORITY_ALIASES).
const PRIORITIES = ['baja', 'media', 'alta', 'urgente'];
const CREATE_TICKET = '@crear_ticket';

export default {
  props: {
    // Las entradas del bloque de ramas: route | default | other (ver TrainingRoutes).
    lines: { type: Array, default: () => [] },
    // { sources: [...], labels: [...], caseTypes: [...], actions: [...] }
    options: { type: Object, default: () => ({}) },
    // Dentro del modal de "Agregar rama": una sola rama, sin el pie (agregar y rama
    // por defecto) ni los botones de mover y quitar. Los campos son los mismos, y
    // viven en un solo lugar para que no se desincronicen.
    compact: { type: Boolean, default: false },
    // Prefijo de los `id` de los campos. El modal usa el suyo: con el mismo, la
    // página tenía dos elementos con el mismo id —los de la lista y los del
    // modal— y quien buscaba uno se llevaba el otro.
    idPrefix: { type: String, default: 'route' },
  },
  emits: ['input', 'add'],
  computed: {
    routes() {
      return this.lines
        .map((linea, index) => ({ ...linea, index }))
        .filter(l => l.kind === 'route');
    },
    // Las líneas del bloque que el parser no reconoce, con su lugar en la lista.
    others() {
      return this.lines
        .map((linea, index) => ({ ...linea, index }))
        .filter(l => l.kind === 'other' && (l.raw || '').trim());
    },
    defaultEntry() {
      const index = this.lines.findIndex(l => l.kind === 'default');
      return index < 0 ? null : { ...this.lines[index], index };
    },
    defaultName() {
      return this.defaultEntry ? this.defaultEntry.name : '';
    },
    routeNames() {
      return this.routes.map(r => r.name);
    },
    sourceOptions() {
      return this.options.sources || [];
    },
    labelOptions() {
      return this.options.labels || [];
    },
    // Lo que una rama puede hacer cuando la fuente no resolvió el turno: abrir un
    // caso —y ahí el tipo y la prioridad se eligen aparte, porque son tres decisiones
    // distintas— o una de las acciones del inventario.
    escalationOptions() {
      return [CREATE_TICKET, ...(this.options.actions || [])];
    },
    caseTypeOptions() {
      return this.options.caseTypes || [];
    },
    priorityOptions() {
      return PRIORITIES;
    },
    // Las listas llegan del inventario DESPUÉS del primer pintado. Un <select> con
    // :value (no v-model) no vuelve a aplicar el valor cuando aparecen sus opciones,
    // y el campo se veía vacío aunque la rama tuviera el tipo de caso escrito. Esto
    // lo vuelve a crear cuando las listas cambian, que pasa una vez al abrir.
    optionsKey() {
      return [
        this.sourceOptions.length,
        this.labelOptions.length,
        this.caseTypeOptions.length,
        this.escalationOptions.length,
      ].join('-');
    },
  },
  methods: {
    emitLines(lineas) {
      this.$emit('input', lineas);
    },
    update(index, changes) {
      const lineas = [...this.lines];
      lineas[index] = { ...lineas[index], ...changes };
      this.emitLines(lineas);
    },
    remove(index) {
      this.emitLines(this.lines.filter((_, i) => i !== index));
    },
    move(index, delta) {
      const destino = index + delta;
      if (destino < 0 || destino >= this.lines.length) return;
      const lineas = [...this.lines];
      [lineas[index], lineas[destino]] = [lineas[destino], lineas[index]];
      this.emitLines(lineas);
    },
    setDefault(nombre) {
      if (this.defaultEntry) {
        if (!nombre) {
          this.remove(this.defaultEntry.index);
          return;
        }
        this.update(this.defaultEntry.index, { name: nombre });
        return;
      }
      if (!nombre) return;
      this.emitLines([
        ...this.lines,
        { kind: 'default', name: nombre, raw: '' },
      ]);
    },
    opensCase(rama) {
      return rama.action === CREATE_TICKET;
    },
    // Elegir otra acción se lleva el tipo y la prioridad, que son solo de abrir caso.
    setAction(index, accion) {
      const changes =
        accion === CREATE_TICKET
          ? { action: accion }
          : { action: accion, case_type: '', priority: '' };
      this.update(index, changes);
    },
    // Un valor guardado que no está en la lista se ofrece igual, marcado: puede ser
    // una fuente que se borró de la cuenta, y hacerlo desaparecer del selector lo
    // cambiaría sin avisar.
    extraOption(valor, lista) {
      return valor && !lista.includes(valor) ? valor : null;
    },
    marca(valor) {
      return this.$t('TRACKING_TEMPLATES.FORM.TRAINING.ROUTE_UNKNOWN', {
        value: valor,
      });
    },
  },
};
</script>

<template>
  <div class="flex flex-col gap-2">
    <div
      v-for="rama in routes"
      :key="`r-${rama.index}`"
      class="p-3 border rounded-md border-slate-200 dark:border-slate-600 bg-slate-25 dark:bg-slate-800"
    >
      <div class="flex flex-wrap items-end gap-2">
        <div class="flex-1 min-w-[10rem]">
          <label
            :for="`${idPrefix}-name-${rama.index}`"
            class="!mb-1 text-xs text-slate-500 dark:text-slate-400"
          >
            {{ $t('TRACKING_TEMPLATES.FORM.TRAINING.ROUTE_NAME') }}
          </label>
          <input
            :id="`${idPrefix}-name-${rama.index}`"
            :value="rama.name"
            type="text"
            class="w-full !mb-0 !py-1 font-mono text-xs"
            :placeholder="
              $t('TRACKING_TEMPLATES.FORM.TRAINING.ROUTE_NAME_PLACEHOLDER')
            "
            @input="update(rama.index, { name: $event.target.value })"
          />
        </div>
        <div class="w-40">
          <label
            :for="`${idPrefix}-tag-${rama.index}`"
            class="!mb-1 text-xs text-slate-500 dark:text-slate-400"
          >
            {{ $t('TRACKING_TEMPLATES.FORM.TRAINING.ROUTE_TAG') }}
          </label>
          <select
            :id="`${idPrefix}-tag-${rama.index}`"
            :key="`tag-${rama.index}-${optionsKey}`"
            :value="rama.tag"
            class="w-full !mb-0 !py-1 text-xs"
            @change="update(rama.index, { tag: $event.target.value })"
          >
            <option value="">
              {{ $t('TRACKING_TEMPLATES.FORM.TRAINING.ROUTE_TAG_NONE') }}
            </option>
            <option
              v-for="etiqueta in labelOptions"
              :key="`t-${rama.index}-${etiqueta}`"
              :value="etiqueta"
            >
              #{{ etiqueta }}
            </option>
            <option
              v-if="extraOption(rama.tag, labelOptions)"
              :value="rama.tag"
            >
              {{ marca(`#${rama.tag}`) }}
            </option>
          </select>
        </div>
        <div v-if="!compact" class="flex items-center gap-1 pb-0.5">
          <woot-button
            type="button"
            size="tiny"
            variant="clear"
            color-scheme="secondary"
            icon="arrow-up"
            :title="$t('TRACKING_TEMPLATES.FORM.TRAINING.MOVE_UP')"
            @click="move(rama.index, -1)"
          />
          <woot-button
            type="button"
            size="tiny"
            variant="clear"
            color-scheme="secondary"
            icon="arrow-up"
            class="[&_svg]:rotate-180"
            :title="$t('TRACKING_TEMPLATES.FORM.TRAINING.MOVE_DOWN')"
            @click="move(rama.index, 1)"
          />
          <woot-button
            type="button"
            size="tiny"
            variant="clear"
            color-scheme="alert"
            icon="delete"
            :title="$t('TRACKING_TEMPLATES.FORM.TRAINING.ROUTE_DELETE')"
            @click="remove(rama.index)"
          />
        </div>
      </div>

      <label
        :for="`${idPrefix}-desc-${rama.index}`"
        class="!mb-1 mt-2 text-xs text-slate-500 dark:text-slate-400"
      >
        {{ $t('TRACKING_TEMPLATES.FORM.TRAINING.ROUTE_PHRASES') }}
      </label>
      <textarea
        :id="`${idPrefix}-desc-${rama.index}`"
        :value="rama.description"
        rows="2"
        class="w-full !mb-0 text-sm bg-white dark:bg-slate-900 border border-slate-200 dark:border-slate-600 rounded-md px-3 py-2"
        :placeholder="
          $t('TRACKING_TEMPLATES.FORM.TRAINING.ROUTE_PHRASES_PLACEHOLDER')
        "
        @input="update(rama.index, { description: $event.target.value })"
      />

      <div class="flex flex-wrap gap-2 mt-2">
        <div class="flex-1 min-w-[12rem]">
          <label
            :for="`${idPrefix}-source-${rama.index}`"
            class="!mb-1 text-xs text-slate-500 dark:text-slate-400"
          >
            {{ $t('TRACKING_TEMPLATES.FORM.TRAINING.ROUTE_SOURCE') }}
          </label>
          <select
            :id="`${idPrefix}-source-${rama.index}`"
            :key="`src-${rama.index}-${optionsKey}`"
            :value="rama.source"
            class="w-full !mb-0 !py-1 font-mono text-xs"
            @change="update(rama.index, { source: $event.target.value })"
          >
            <option value="">
              {{ $t('TRACKING_TEMPLATES.FORM.TRAINING.ROUTE_SOURCE_NONE') }}
            </option>
            <option
              v-for="fuente in sourceOptions"
              :key="`s-${rama.index}-${fuente}`"
              :value="fuente"
            >
              {{ fuente }}
            </option>
            <option
              v-if="extraOption(rama.source, sourceOptions)"
              :value="rama.source"
            >
              {{ marca(rama.source) }}
            </option>
          </select>
        </div>
        <div class="flex-1 min-w-[12rem]">
          <label
            :for="`${idPrefix}-esc-${rama.index}`"
            class="!mb-1 text-xs text-slate-500 dark:text-slate-400"
          >
            {{ $t('TRACKING_TEMPLATES.FORM.TRAINING.ROUTE_ESCALATION') }}
          </label>
          <select
            :id="`${idPrefix}-esc-${rama.index}`"
            :key="`esc-${rama.index}-${optionsKey}`"
            :value="rama.action"
            class="w-full !mb-0 !py-1 font-mono text-xs"
            @change="setAction(rama.index, $event.target.value)"
          >
            <option value="">
              {{ $t('TRACKING_TEMPLATES.FORM.TRAINING.ROUTE_ESCALATION_NONE') }}
            </option>
            <option
              v-for="accion in escalationOptions"
              :key="`e-${rama.index}-${accion}`"
              :value="accion"
            >
              {{
                accion === '@crear_ticket'
                  ? $t('TRACKING_TEMPLATES.FORM.TRAINING.ROUTE_OPEN_CASE')
                  : accion
              }}
            </option>
            <option
              v-if="extraOption(rama.action, escalationOptions)"
              :value="rama.action"
            >
              {{ marca(rama.action) }}
            </option>
          </select>
        </div>
      </div>

      <!-- Solo para abrir caso: de qué tipo y con qué prioridad. -->
      <div v-if="opensCase(rama)" class="flex flex-wrap gap-2 mt-2">
        <div class="flex-1 min-w-[12rem]">
          <label
            :for="`${idPrefix}-case-${rama.index}`"
            class="!mb-1 text-xs text-slate-500 dark:text-slate-400"
          >
            {{ $t('TRACKING_TEMPLATES.FORM.TRAINING.ROUTE_CASE_TYPE') }}
          </label>
          <select
            :id="`${idPrefix}-case-${rama.index}`"
            :key="`case-${rama.index}-${optionsKey}`"
            :value="rama.case_type"
            class="w-full !mb-0 !py-1 text-xs"
            @change="update(rama.index, { case_type: $event.target.value })"
          >
            <option value="">
              {{ $t('TRACKING_TEMPLATES.FORM.TRAINING.ROUTE_CASE_TYPE_NONE') }}
            </option>
            <option
              v-for="tipo in caseTypeOptions"
              :key="`c-${rama.index}-${tipo}`"
              :value="tipo"
            >
              {{ tipo }}
            </option>
            <option
              v-if="extraOption(rama.case_type, caseTypeOptions)"
              :value="rama.case_type"
            >
              {{ marca(rama.case_type) }}
            </option>
          </select>
        </div>
        <div class="w-44">
          <label
            :for="`${idPrefix}-prio-${rama.index}`"
            class="!mb-1 text-xs text-slate-500 dark:text-slate-400"
          >
            {{ $t('TRACKING_TEMPLATES.FORM.TRAINING.ROUTE_PRIORITY') }}
          </label>
          <select
            :id="`${idPrefix}-prio-${rama.index}`"
            :value="rama.priority"
            class="w-full !mb-0 !py-1 text-xs"
            @change="update(rama.index, { priority: $event.target.value })"
          >
            <option value="">
              {{ $t('TRACKING_TEMPLATES.FORM.TRAINING.ROUTE_PRIORITY_NONE') }}
            </option>
            <option
              v-for="prioridad in priorityOptions"
              :key="`p-${rama.index}-${prioridad}`"
              :value="prioridad"
            >
              {{ prioridad }}
            </option>
            <option
              v-if="extraOption(rama.priority, priorityOptions)"
              :value="rama.priority"
            >
              {{ marca(rama.priority) }}
            </option>
          </select>
        </div>
      </div>
    </div>

    <!-- Lo que estaba escrito en el bloque y no es una rama ni la rama por defecto. -->
    <div
      v-for="linea in others"
      v-show="!compact"
      :key="`o-${linea.index}`"
      class="flex gap-2"
    >
      <input
        :id="`${idPrefix}-other-${linea.index}`"
        :value="linea.raw"
        type="text"
        class="flex-1 !mb-0 !py-1 font-mono text-xs"
        :aria-label="$t('TRACKING_TEMPLATES.FORM.TRAINING.ROUTE_OTHER')"
        @input="update(linea.index, { raw: $event.target.value })"
      />
      <woot-button
        type="button"
        size="tiny"
        variant="clear"
        color-scheme="alert"
        icon="delete"
        :title="$t('TRACKING_TEMPLATES.FORM.TRAINING.ROUTE_DELETE')"
        @click="remove(linea.index)"
      />
    </div>

    <div v-if="!compact" class="flex flex-wrap items-center gap-3">
      <woot-button
        type="button"
        size="small"
        variant="smooth"
        icon="add"
        @click="$emit('add')"
      >
        {{ $t('TRACKING_TEMPLATES.FORM.TRAINING.ROUTE_ADD') }}
      </woot-button>
      <div class="flex items-center gap-2">
        <label
          for="route-default"
          class="!mb-0 text-xs text-slate-500 dark:text-slate-400"
        >
          {{ $t('TRACKING_TEMPLATES.FORM.TRAINING.ROUTE_DEFAULT') }}
        </label>
        <select
          id="route-default"
          :value="defaultName"
          class="!mb-0 !py-1 font-mono text-xs w-44"
          @change="setDefault($event.target.value)"
        >
          <option value="">
            {{ $t('TRACKING_TEMPLATES.FORM.TRAINING.ROUTE_DEFAULT_NONE') }}
          </option>
          <option
            v-for="rama in routes"
            :key="`d-${rama.index}`"
            :value="rama.name"
          >
            {{ rama.name }}
          </option>
          <option
            v-if="extraOption(defaultName, routeNames)"
            :value="defaultName"
          >
            {{ marca(defaultName) }}
          </option>
        </select>
      </div>
    </div>
  </div>
</template>
