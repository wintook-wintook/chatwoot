<script>
// proyecto@asistente_agentes_ia — SUBIR UN ENCARGO (.md) Y VER QUÉ ENTENDIÓ
// ============================================================================
// El encargo es la IDEA de cómo se quiere el agente (docs/importar_prompt_md_plan.md).
// Acá se sube, se ve el avance real de la lectura (TurnProgress) y, al terminar,
// "Esto entendí": la ficha del encargo y lo que le falta para escribir el
// Entrenamiento.
//
// Adelantado de la F5 a pedido del usuario (23/09/2026) para poder probar la
// lectura. Va en un modal y no en el chat porque el chat está escondido (SHOW_CHAT
// en Assistant.vue).
//
// F3 (23/09/2026): debajo de "Esto entendí", una pregunta por cada cosa que falta
// (contradicciones, modo, frases, fuente, etiquetas). "Crear el Entrenamiento" arma
// el encargo resuelto (BriefComposer) y lo emite: la vista del Asistente lo manda a
// la redacción de una sola vez y lo carga en la Estructura del Agente. Lo que se
// deje vacío sale <PENDIENTE:>.
//
// El modal se puede cerrar mientras lee: el componente sigue montado y la lectura
// sigue en el servidor; al reabrirlo se ve dónde va.
// ============================================================================
import Spinner from 'shared/components/Spinner.vue';
import AssistantAPI from 'dashboard/api/assistant';
import KnowledgePanel from './KnowledgePanel.vue';
import {
  groupGaps,
  listSizes,
  listItemText,
  pointText,
  isBusy,
  briefQuestions,
  briefAnswers,
} from './briefDigest';

const POLL_MS = 2000;
// Una plantilla con cada sección que el lector sabe leer, con su ejemplo (pedido del
// usuario, 23/09/2026). Archivos estáticos en public/assistant/, uno por idioma.
const EXAMPLE_FILES = {
  es: '/assistant/instrucciones_iniciales_ejemplo.md',
  en: '/assistant/initial_instructions_example.md',
};
const UPLOAD_ERRORS = [
  'too_large',
  'bad_extension',
  'not_text',
  'empty',
  'missing_file',
];

export default {
  components: { Spinner, KnowledgePanel },
  props: {
    show: { type: Boolean, default: false },
    sessionId: { type: [Number, String], default: null },
    // Unas instrucciones ya mandadas a leer (desde la conversación del Asistente):
    // el modal las sigue como si se hubieran subido acá.
    initialBrief: { type: Object, default: null },
    // Las etiquetas de la cuenta, para sugerirlas (inventario del Asistente).
    labels: { type: Array, default: () => [] },
    // La vista del Asistente está escribiendo el Entrenamiento con este encargo.
    writing: { type: Boolean, default: false },
    // Hay un Entrenamiento en pantalla: crear uno desde el encargo lo reemplaza.
    hasDraft: { type: Boolean, default: false },
  },
  emits: ['close', 'write', 'applyGroup'],
  data() {
    return {
      brief: null,
      uploading: false,
      stage: null,
      error: '',
      openList: '',
      timer: null,
      turnId: null,
      // Lo contestado en el formulario, por pregunta: { 'contradiccion:0': 'b' }.
      values: {},
      composing: false,
      // 0 = Esto entendí · 1 = Me falta saber · 2 = Respuestas predefinidas
      tab: 0,
      // Lo creado en la pestaña de respuestas predefinidas: { group, moved } o null.
      // Viaja con las respuestas al escribir (BriefComposer).
      knowledge: null,
    };
  },
  computed: {
    busy() {
      return this.uploading || isBusy(this.brief?.status);
    },
    ficha() {
      return this.brief?.digest?.ficha || {};
    },
    gaps() {
      return groupGaps(this.brief?.digest?.faltas || []);
    },
    lists() {
      return listSizes(this.ficha);
    },
    temas() {
      return this.ficha.temas || [];
    },
    herramientas() {
      return this.ficha.herramientas || [];
    },
    questions() {
      return briefQuestions(this.ficha, this.brief?.digest?.faltas || []);
    },
    // Lo que falta y no se contesta acá: una herramienta que la cuenta no tiene se
    // conecta en la cuenta, no se escribe en un campo.
    notices() {
      return this.gaps.filter(g => g.que === 'herramienta_no_disponible');
    },
    ready() {
      return this.brief?.status === 'ready';
    },
    exampleUrl() {
      const idioma = String(this.$i18n.locale || '').startsWith('es')
        ? 'es'
        : 'en';
      return EXAMPLE_FILES[idioma];
    },
    stageLabel() {
      const etapa = this.stage;
      if (!etapa?.stage) return this.$t('TRACKING_ASSISTANT_VIEW.BRIEF_QUEUED');
      if (etapa.stage === 'merging_brief') {
        return this.$t('TRACKING_ASSISTANT_VIEW.BRIEF_STAGE_MERGING');
      }
      return this.$t('TRACKING_ASSISTANT_VIEW.BRIEF_STAGE_READING', {
        done: etapa.done,
        total: etapa.total,
      });
    },
    // Barra de la lectura: trozos leídos de los totales. Juntar no tiene total fijo.
    percent() {
      const etapa = this.stage;
      if (etapa?.stage !== 'reading_brief' || !etapa.total) return null;
      return Math.round((etapa.done / etapa.total) * 100);
    },
    usageLabel() {
      const uso = this.brief?.usage || {};
      if (uso.segundos === undefined) return '';
      return this.$t('TRACKING_ASSISTANT_VIEW.BRIEF_USAGE', {
        chunks: uso.trozos,
        seconds: Math.round(uso.segundos),
        cost: (uso.costo_usd || 0).toFixed(2),
      });
    },
  },
  watch: {
    initialBrief(brief) {
      if (!brief) return;
      this.brief = brief;
      this.values = {};
      this.knowledge = null;
      this.tab = 0;
      this.error = '';
      this.stage = null;
      this.turnId = null;
      this.follow();
    },
  },
  beforeDestroy() {
    this.stopPolling();
  },
  methods: {
    pointText,
    listItemText,
    pickFile() {
      this.$refs.file?.click();
    },
    newTurnId() {
      return `b${Date.now().toString(36)}${Math.random()
        .toString(36)
        .slice(2, 10)}`;
    },
    async onFile(event) {
      const [file] = event.target.files || [];
      event.target.value = '';
      if (!file) return;

      this.error = '';
      this.uploading = true;
      this.brief = null;
      this.stage = null;
      this.turnId = this.newTurnId();
      try {
        const { data } = await AssistantAPI.uploadBrief(file, {
          sessionId: this.sessionId,
          turnId: this.turnId,
        });
        this.brief = data;
        this.values = {};
        this.knowledge = null;
        this.tab = 0;
        this.follow();
      } catch (error) {
        const code = error?.response?.data?.error;
        this.error = this.$t(
          UPLOAD_ERRORS.includes(code)
            ? `TRACKING_ASSISTANT_VIEW.BRIEF_ERROR_${code.toUpperCase()}`
            : 'TRACKING_ASSISTANT_VIEW.BRIEF_ERROR'
        );
      } finally {
        this.uploading = false;
      }
    },
    async retry() {
      if (!this.brief) return;
      this.turnId = this.newTurnId();
      this.stage = null;
      try {
        const { data } = await AssistantAPI.digestBrief(
          this.brief.id,
          this.turnId
        );
        this.brief = { ...data, status: 'pending' };
        this.follow();
      } catch (error) {
        this.error = this.$t('TRACKING_ASSISTANT_VIEW.BRIEF_ERROR');
      }
    },
    // Mientras lee: el estado del encargo y la etapa real, cada POLL_MS.
    follow() {
      this.stopPolling();
      if (!isBusy(this.brief?.status)) return;
      this.timer = setInterval(this.poll, POLL_MS);
    },
    async poll() {
      try {
        const [{ data: brief }, progreso] = await Promise.all([
          AssistantAPI.getBrief(this.brief.id),
          this.turnId
            ? AssistantAPI.getProgress(this.turnId).catch(() => ({
                data: null,
              }))
            : Promise.resolve({ data: null }),
        ]);
        this.brief = brief;
        if (progreso?.data?.stage) this.stage = progreso.data;
        if (!isBusy(brief.status)) this.stopPolling();
      } catch (error) {
        // Una consulta que falla no corta nada: la siguiente vuelve a preguntar.
      }
    },
    stopPolling() {
      clearInterval(this.timer);
      this.timer = null;
    },
    questionId(pregunta) {
      return ['modo', 'temas'].includes(pregunta.kind)
        ? pregunta.kind
        : `${pregunta.kind}:${pregunta.key}`;
    },
    setValue(pregunta, valor) {
      this.values = { ...this.values, [this.questionId(pregunta)]: valor };
    },
    valueOf(pregunta) {
      return this.values[this.questionId(pregunta)] || '';
    },
    // Arma el encargo resuelto y se lo pasa a la vista, que escribe el Entrenamiento.
    async write() {
      if (!this.brief || this.composing || this.writing) return;
      this.composing = true;
      this.error = '';
      try {
        const respuestas = briefAnswers(this.values);
        if (this.knowledge) {
          respuestas.predefinidas_grupo = this.knowledge.group;
          respuestas.conocimiento_movido = this.knowledge.moved;
        }
        const { data } = await AssistantAPI.composeBrief(
          this.brief.id,
          respuestas
        );
        this.$emit('write', {
          ...data,
          briefId: this.brief.id,
          filename: this.brief.filename,
        });
      } catch (error) {
        this.error = this.$t('TRACKING_ASSISTANT_VIEW.BRIEF_WRITE_ERROR');
      } finally {
        this.composing = false;
      }
    },
    toggleList(campo) {
      this.openList = this.openList === campo ? '' : campo;
    },
    toolLabel(tool) {
      if (tool.disponible === true) return '✓';
      if (tool.disponible === false) return '✗';
      return '·';
    },
  },
};
</script>

<template>
  <!-- Ancho y de alto fijo: título, pestañas y botones quedan quietos y solo se
       desplaza el contenido de la pestaña (pedido del usuario, 23/09/2026: con
       todo en una columna el modal crecía hasta salirse de la pantalla). -->
  <woot-modal :show="show" size="brief-wide" :on-close="() => $emit('close')">
    <div
      class="flex flex-col gap-3 p-8 text-sm"
      :class="ready ? 'h-[80vh]' : 'max-h-[80vh]'"
    >
      <div class="shrink-0">
        <h2 class="!m-0 text-lg font-medium text-slate-800 dark:text-slate-100">
          {{ $t('TRACKING_ASSISTANT_VIEW.BRIEF_TITLE') }}
        </h2>
        <p class="!m-0 mt-1 text-xs text-slate-600 dark:text-slate-300">
          {{ $t('TRACKING_ASSISTANT_VIEW.BRIEF_HINT') }}
          <a
            :href="exampleUrl"
            download
            class="ml-1 font-medium text-woot-600 dark:text-woot-400 hover:underline"
          >
            {{ $t('TRACKING_ASSISTANT_VIEW.BRIEF_EXAMPLE') }}
          </a>
        </p>
      </div>

      <div class="flex flex-wrap items-center gap-3 shrink-0">
        <input
          ref="file"
          type="file"
          accept=".md,.markdown,.txt"
          class="hidden"
          @change="onFile"
        />
        <woot-button
          icon="attach"
          :is-disabled="busy || writing"
          :is-loading="uploading"
          @click="pickFile"
        >
          {{
            brief
              ? $t('TRACKING_ASSISTANT_VIEW.BRIEF_PICK_OTHER')
              : $t('TRACKING_ASSISTANT_VIEW.BRIEF_PICK')
          }}
        </woot-button>
        <span
          v-if="brief"
          class="text-xs text-slate-600 dark:text-slate-300 truncate"
        >
          {{
            $t('TRACKING_ASSISTANT_VIEW.BRIEF_FILE', {
              name: brief.filename,
              size: Math.max(1, Math.round(brief.bytes / 1024)),
            })
          }}
        </span>
        <span
          v-if="ready && usageLabel"
          class="ml-auto text-xs text-slate-500 dark:text-slate-400"
        >
          {{ usageLabel }}
        </span>
      </div>

      <p
        v-if="error"
        class="!m-0 text-xs text-red-600 dark:text-red-400 shrink-0"
      >
        {{ error }}
      </p>

      <!-- Leyendo -->
      <div
        v-if="brief && busy"
        class="flex flex-col gap-2 p-3 rounded-lg shrink-0 bg-slate-50 dark:bg-slate-700"
      >
        <div class="flex items-center gap-2">
          <Spinner size="" />
          <span class="text-xs text-slate-700 dark:text-slate-200">
            {{ stageLabel }}
          </span>
        </div>
        <div
          v-if="percent !== null"
          class="h-1.5 rounded bg-slate-200 dark:bg-slate-600 overflow-hidden"
        >
          <div class="h-full bg-woot-500" :style="{ width: `${percent}%` }" />
        </div>
        <p class="!m-0 text-xs text-slate-500 dark:text-slate-400">
          {{ $t('TRACKING_ASSISTANT_VIEW.BRIEF_CAN_CLOSE') }}
        </p>
      </div>

      <!-- Falló -->
      <div
        v-if="brief && brief.status === 'failed'"
        class="flex flex-wrap items-center gap-3 p-3 rounded-lg shrink-0 bg-red-50 dark:bg-red-900/20"
      >
        <span class="text-xs text-red-700 dark:text-red-300">
          {{ $t('TRACKING_ASSISTANT_VIEW.BRIEF_FAILED') }}
        </span>
        <woot-button size="small" variant="smooth" @click="retry">
          {{ $t('TRACKING_ASSISTANT_VIEW.BRIEF_RETRY') }}
        </woot-button>
      </div>

      <template v-if="ready">
        <woot-tabs :index="tab" class="shrink-0" @change="tab = $event">
          <woot-tabs-item
            :index="0"
            :name="$t('TRACKING_ASSISTANT_VIEW.BRIEF_UNDERSTOOD')"
            :show-badge="false"
          />
          <woot-tabs-item
            :index="1"
            :name="$t('TRACKING_ASSISTANT_VIEW.BRIEF_GAPS')"
            :count="questions.length + notices.length"
          />
          <woot-tabs-item
            :index="2"
            :name="$t('TRACKING_ASSISTANT_VIEW.KNOWLEDGE_TAB')"
            :show-badge="false"
          />
        </woot-tabs>

        <!-- Esto entendí -->
        <div
          v-show="tab === 0"
          class="flex flex-col flex-1 min-h-0 gap-3 pr-1 overflow-y-auto"
        >
          <dl class="grid grid-cols-[auto_1fr] gap-x-3 gap-y-1 !m-0 text-xs">
            <template v-for="campo in ['identidad', 'objetivo']">
              <dt
                v-if="ficha[campo]"
                :key="`${campo}-t`"
                class="font-medium text-slate-600 dark:text-slate-300"
              >
                {{ $t(`TRACKING_ASSISTANT_VIEW.BRIEF_${campo.toUpperCase()}`) }}
              </dt>
              <dd
                v-if="ficha[campo]"
                :key="`${campo}-d`"
                class="!m-0 text-slate-800 dark:text-slate-100"
              >
                {{ pointText(ficha[campo]) }}
              </dd>
            </template>
            <dt class="font-medium text-slate-600 dark:text-slate-300">
              {{ $t('TRACKING_ASSISTANT_VIEW.BRIEF_MODO') }}
            </dt>
            <dd class="!m-0 text-slate-800 dark:text-slate-100">
              {{
                ficha.modo
                  ? $t(
                      `TRACKING_ASSISTANT_VIEW.BRIEF_MODO_${pointText(
                        ficha.modo
                      ).toUpperCase()}`
                    )
                  : $t('TRACKING_ASSISTANT_VIEW.BRIEF_UNKNOWN')
              }}
            </dd>
          </dl>

          <div v-if="temas.length">
            <p
              class="!m-0 mb-1 text-xs font-medium text-slate-600 dark:text-slate-300"
            >
              {{
                $t('TRACKING_ASSISTANT_VIEW.BRIEF_TEMAS', {
                  count: temas.length,
                })
              }}
            </p>
            <ul class="!m-0 !pl-4 text-xs list-disc">
              <li
                v-for="(tema, i) in temas"
                :key="i"
                class="text-slate-800 dark:text-slate-100"
              >
                {{ tema.nombre }}
                <span v-if="tema.etiqueta" class="text-slate-500">
                  #{{ tema.etiqueta }}
                </span>
                <span v-if="tema.que_hace" class="text-slate-500">
                  — {{ tema.que_hace }}
                </span>
              </li>
            </ul>
          </div>

          <p v-if="herramientas.length" class="!m-0 text-xs">
            <span class="font-medium text-slate-600 dark:text-slate-300">
              {{ $t('TRACKING_ASSISTANT_VIEW.BRIEF_HERRAMIENTAS') }}
            </span>
            <span
              v-for="(tool, i) in herramientas"
              :key="i"
              class="ml-2 text-slate-800 dark:text-slate-100"
              :title="tool.para"
            >
              {{ tool.tipo }} {{ toolLabel(tool) }}
            </span>
          </p>

          <!-- La ficha completa, lista por lista. -->
          <div v-if="lists.length" class="flex flex-col gap-1">
            <p
              class="!m-0 text-xs font-medium text-slate-600 dark:text-slate-300"
            >
              {{ $t('TRACKING_ASSISTANT_VIEW.BRIEF_FULL') }}
            </p>
            <div v-for="{ campo, count } in lists" :key="campo">
              <button
                class="text-xs text-woot-600 dark:text-woot-400 hover:underline"
                @click="toggleList(campo)"
              >
                {{ openList === campo ? '▾' : '▸' }}
                {{
                  $t(
                    `TRACKING_ASSISTANT_VIEW.BRIEF_LIST_${campo.toUpperCase()}`
                  )
                }}
                ({{ count }})
              </button>
              <ul
                v-if="openList === campo"
                class="!m-0 !pl-5 mt-1 text-xs list-disc text-slate-800 dark:text-slate-100"
              >
                <li v-for="(punto, i) in ficha[campo]" :key="i">
                  {{ listItemText(campo, punto) }}
                </li>
              </ul>
            </div>
          </div>
        </div>

        <!-- Me falta saber: una pregunta por cada cosa que falta. -->
        <div
          v-show="tab === 1"
          class="flex flex-col flex-1 min-h-0 gap-4 pr-1 overflow-y-auto"
        >
          <p
            v-if="!questions.length && !notices.length"
            class="!m-0 text-xs text-slate-600 dark:text-slate-300"
          >
            {{ $t('TRACKING_ASSISTANT_VIEW.BRIEF_ASK_NOTHING') }}
          </p>
          <div
            v-for="(pregunta, n) in questions"
            :key="questionId(pregunta)"
            class="flex flex-col gap-1 text-xs"
          >
            <p class="!m-0 font-medium text-slate-800 dark:text-slate-100">
              {{ n + 1 }}.
              {{
                $t(
                  `TRACKING_ASSISTANT_VIEW.BRIEF_ASK_${pregunta.kind.toUpperCase()}`,
                  { sobre: pregunta.sobre, tema: pregunta.tema }
                )
              }}
            </p>
            <template v-if="pregunta.kind === 'contradiccion'">
              <label
                v-for="lado in ['a', 'b']"
                :key="lado"
                class="flex items-start gap-2 !m-0 cursor-pointer text-slate-700 dark:text-slate-200"
              >
                <input
                  type="radio"
                  class="!m-0 mt-0.5"
                  :name="questionId(pregunta)"
                  :checked="valueOf(pregunta) === lado"
                  @change="setValue(pregunta, lado)"
                />
                {{ pregunta[lado] }}
              </label>
            </template>
            <template v-else-if="pregunta.kind === 'modo'">
              <label
                v-for="modo in ['responde', 'deriva']"
                :key="modo"
                class="flex items-center gap-2 !m-0 cursor-pointer text-slate-700 dark:text-slate-200"
              >
                <input
                  type="radio"
                  class="!m-0"
                  name="modo"
                  :checked="valueOf(pregunta) === modo"
                  @change="setValue(pregunta, modo)"
                />
                {{
                  $t(`TRACKING_ASSISTANT_VIEW.BRIEF_MODO_${modo.toUpperCase()}`)
                }}
              </label>
            </template>
            <textarea
              v-else-if="['frases', 'temas'].includes(pregunta.kind)"
              rows="2"
              class="!mb-0 text-xs"
              :placeholder="
                $t(
                  `TRACKING_ASSISTANT_VIEW.BRIEF_ASK_${pregunta.kind.toUpperCase()}_HINT`
                )
              "
              :value="valueOf(pregunta)"
              @input="setValue(pregunta, $event.target.value)"
            />
            <input
              v-else
              type="text"
              class="!mb-0 text-xs"
              :list="
                pregunta.kind === 'etiquetas' ? 'brief-account-labels' : null
              "
              :placeholder="
                $t(
                  `TRACKING_ASSISTANT_VIEW.BRIEF_ASK_${pregunta.kind.toUpperCase()}_HINT`
                )
              "
              :value="valueOf(pregunta)"
              @input="setValue(pregunta, $event.target.value)"
            />
          </div>
          <datalist id="brief-account-labels">
            <option v-for="label in labels" :key="label" :value="label" />
          </datalist>

          <div
            v-for="notice in notices"
            :key="notice.que"
            class="p-3 text-xs rounded-lg bg-amber-50 dark:bg-amber-900/20 text-amber-900 dark:text-amber-800"
          >
            {{
              $t('TRACKING_ASSISTANT_VIEW.BRIEF_GAP_HERRAMIENTA_NO_DISPONIBLE')
            }}:
            {{ notice.items.join(', ') }}
          </div>

          <p
            v-if="questions.length"
            class="!m-0 text-xs text-slate-500 dark:text-slate-400"
          >
            {{ $t('TRACKING_ASSISTANT_VIEW.BRIEF_ASK_EMPTY_HINT') }}
          </p>
        </div>

        <!-- Respuestas predefinidas: el conocimiento fuera del prompt. -->
        <div
          v-show="tab === 2"
          class="flex flex-col flex-1 min-h-0 pr-1 overflow-y-auto"
        >
          <KnowledgePanel
            :brief-id="brief && brief.id"
            :active="tab === 2"
            :has-draft="hasDraft"
            @change="knowledge = $event"
            @applyGroup="$emit('applyGroup', $event)"
          />
        </div>
      </template>

      <div
        class="flex flex-wrap items-center justify-end gap-2 pt-3 border-t shrink-0 border-slate-100 dark:border-slate-700"
      >
        <span
          v-if="writing"
          class="flex items-center gap-2 mr-auto text-xs text-slate-600 dark:text-slate-300"
        >
          <Spinner size="" />
          {{ $t('TRACKING_ASSISTANT_VIEW.BRIEF_WRITING') }}
        </span>
        <span
          v-else-if="ready && hasDraft"
          class="mr-auto text-xs text-amber-800 dark:text-amber-800"
        >
          {{ $t('TRACKING_ASSISTANT_VIEW.BRIEF_REPLACES_DRAFT') }}
        </span>
        <woot-button
          variant="clear"
          color-scheme="secondary"
          :is-disabled="writing"
          @click="$emit('close')"
        >
          {{ $t('TRACKING_ASSISTANT_VIEW.BRIEF_CLOSE') }}
        </woot-button>
        <woot-button
          v-if="ready"
          :is-loading="composing || writing"
          :is-disabled="composing || writing"
          @click="write"
        >
          {{ $t('TRACKING_ASSISTANT_VIEW.BRIEF_WRITE') }}
        </woot-button>
      </div>
    </div>
  </woot-modal>
</template>

<style lang="scss">
.modal-container.brief-wide {
  @apply w-[64rem] max-w-[94vw];
}
</style>
