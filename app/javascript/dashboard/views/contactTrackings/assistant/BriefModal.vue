<script>
// proyecto@asistente_agentes_ia — SUBIR UN ENCARGO (.md) Y VER QUÉ ENTENDIÓ
// ============================================================================
// El encargo es la IDEA de cómo se quiere el agente (docs/importar_prompt_md_plan.md).
// Acá se sube, se ve el avance real de la lectura (TurnProgress) y, al terminar,
// "Esto entendí": la ficha del encargo y lo que le falta para escribir el
// Entrenamiento.
//
// Adelantado de la F5 a pedido del usuario (23/09/2026) para poder probar la
// lectura. Todavía NO pregunta ni escribe: eso es la F3. Va en un modal y no en el
// chat porque el chat está escondido (SHOW_CHAT en Assistant.vue).
//
// El modal se puede cerrar mientras lee: el componente sigue montado y la lectura
// sigue en el servidor; al reabrirlo se ve dónde va.
// ============================================================================
import Spinner from 'shared/components/Spinner.vue';
import AssistantAPI from 'dashboard/api/assistant';
import {
  groupGaps,
  listSizes,
  listItemText,
  pointText,
  isBusy,
} from './briefDigest';

const POLL_MS = 2000;
const UPLOAD_ERRORS = [
  'too_large',
  'bad_extension',
  'not_text',
  'empty',
  'missing_file',
];

export default {
  components: { Spinner },
  props: {
    show: { type: Boolean, default: false },
    sessionId: { type: [Number, String], default: null },
  },
  emits: ['close'],
  data() {
    return {
      brief: null,
      uploading: false,
      stage: null,
      error: '',
      openList: '',
      timer: null,
      turnId: null,
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
          AssistantAPI.getProgress(this.turnId).catch(() => ({ data: null })),
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
  <woot-modal :show="show" size="medium" :on-close="() => $emit('close')">
    <div class="flex flex-col gap-4 p-8 text-sm max-h-[85vh]">
      <div class="shrink-0">
        <h2 class="!m-0 text-lg font-medium text-slate-800 dark:text-slate-100">
          {{ $t('TRACKING_ASSISTANT_VIEW.BRIEF_TITLE') }}
        </h2>
        <p class="!m-0 mt-1 text-xs text-slate-600 dark:text-slate-300">
          {{ $t('TRACKING_ASSISTANT_VIEW.BRIEF_HINT') }}
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
          :is-disabled="busy"
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
      </div>

      <p v-if="error" class="!m-0 text-xs text-red-600 dark:text-red-400">
        {{ error }}
      </p>

      <!-- Leyendo -->
      <div
        v-if="brief && busy"
        class="flex flex-col gap-2 p-3 rounded-lg bg-slate-50 dark:bg-slate-700"
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
        class="flex flex-wrap items-center gap-3 p-3 rounded-lg bg-red-50 dark:bg-red-900/20"
      >
        <span class="text-xs text-red-700 dark:text-red-300">
          {{ $t('TRACKING_ASSISTANT_VIEW.BRIEF_FAILED') }}
        </span>
        <woot-button size="small" variant="smooth" @click="retry">
          {{ $t('TRACKING_ASSISTANT_VIEW.BRIEF_RETRY') }}
        </woot-button>
      </div>

      <!-- Esto entendí -->
      <div
        v-if="brief && brief.status === 'ready'"
        class="flex flex-col flex-1 min-h-0 gap-3 pr-1 overflow-y-auto"
      >
        <h3
          class="!m-0 text-sm font-semibold text-slate-800 dark:text-slate-100"
        >
          {{ $t('TRACKING_ASSISTANT_VIEW.BRIEF_UNDERSTOOD') }}
        </h3>

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
              $t('TRACKING_ASSISTANT_VIEW.BRIEF_TEMAS', { count: temas.length })
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

        <div
          v-if="gaps.length"
          class="p-3 rounded-lg bg-amber-50 dark:bg-amber-900/20"
        >
          <p
            class="!m-0 mb-1 text-xs font-medium text-amber-800 dark:text-amber-300"
          >
            {{ $t('TRACKING_ASSISTANT_VIEW.BRIEF_GAPS') }}
          </p>
          <ul
            class="!m-0 !pl-4 text-xs list-disc text-amber-900 dark:text-amber-200"
          >
            <li v-for="gap in gaps" :key="gap.que">
              {{
                $t(`TRACKING_ASSISTANT_VIEW.BRIEF_GAP_${gap.que.toUpperCase()}`)
              }}
              <span v-if="gap.items.length">: {{ gap.items.join(', ') }}</span>
            </li>
          </ul>
        </div>

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
                $t(`TRACKING_ASSISTANT_VIEW.BRIEF_LIST_${campo.toUpperCase()}`)
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

        <p
          v-if="usageLabel"
          class="!m-0 text-xs text-slate-500 dark:text-slate-400"
        >
          {{ usageLabel }}
        </p>
        <p class="!m-0 text-xs text-slate-500 dark:text-slate-400">
          {{ $t('TRACKING_ASSISTANT_VIEW.BRIEF_NEXT') }}
        </p>
      </div>

      <div class="flex items-center justify-end shrink-0">
        <woot-button
          variant="clear"
          color-scheme="secondary"
          @click="$emit('close')"
        >
          {{ $t('TRACKING_ASSISTANT_VIEW.BRIEF_CLOSE') }}
        </woot-button>
      </div>
    </div>
  </woot-modal>
</template>
