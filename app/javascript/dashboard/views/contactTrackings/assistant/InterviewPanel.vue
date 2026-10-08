<script>
// proyecto@asistente_agentes_ia — F4
// ============================================================================
// La conversación con el asistente. El hilo vive acá y se manda entero en cada
// turno: el backend no guarda sesión, así que el cliente es el dueño del hilo.
// ============================================================================
import Spinner from 'shared/components/Spinner.vue';
import WootAudioRecorder from 'dashboard/components/widgets/WootWriter/AudioRecorder.vue';
import { useAlert } from 'dashboard/composables';
import AssistantAPI from 'dashboard/api/assistant';
import { AUDIO_FORMATS } from 'shared/constants/messages';
import MessageFormatter from 'shared/helpers/MessageFormatter';
import ChangeList from './ChangeList.vue';
import { hasChanges } from './changeList';

// Un mensaje de más de estas líneas (o caracteres) se muestra recortado, con «Mostrar
// más» (pedido del usuario, 23/09/2026: el de las instrucciones iniciales ocupaba toda
// la conversación).
const COLLAPSED_LINES = 5;
const COLLAPSED_CHARS = 500;

// Errores de la transcripción que merecen un mensaje propio: el resto es "no se pudo".
const DICTATION_ERRORS = ['no_api_key', 'too_large', 'no_audio'];

export default {
  components: { Spinner, ChangeList, WootAudioRecorder },
  props: {
    messages: { type: Array, default: () => [] },
    isThinking: { type: Boolean, default: false },
    // Las preguntas del último turno, en forma de lista, para mostrarlas como
    // botones. Llega null cuando el asistente no preguntó nada con opciones
    // —una pregunta abierta como "qué temas atiende" no tiene lista— y entonces
    // la conversación funciona como siempre, escribiendo.
    options: { type: Array, default: null },
    // Hay un Entrenamiento en pantalla: el turno es una edición y, con uno largo,
    // tarda (medido: 40–52 s por llamada con 17.000 caracteres). Un spinner solo
    // durante un minuto se lee como que se colgó.
    isEditing: { type: Boolean, default: false },
    // Fase D: la etapa REAL del turno en curso ({ stage, round, of, editing }),
    // consultada mientras se espera. null = todavía no hay dato.
    stage: { type: Object, default: null },
  },
  emits: ['send'],
  data() {
    // Lo elegido en cada pregunta, por índice: { 0: '#demo', 2: 'responde' }.
    //
    // dictation: '' | 'recording' | 'transcribing'. El grabador es el nativo del
    // cuadro de respuesta de Chatwoot (graba al montarse); el texto lo pasa el
    // backend con la integración de OpenAI de la cuenta.
    return {
      input: '',
      picked: {},
      // Los mensajes largos desplegados, por índice: { 0: true }.
      expanded: {},
      dictation: '',
      dictationTime: '00:00',
      audioFormat: AUDIO_FORMATS.OGG,
    };
  },
  computed: {
    // Qué está haciendo el asistente, en palabras. Sin etapa todavía, la espera
    // genérica: la de editar si hay Entrenamiento, que es la que tarda.
    stageLabel() {
      const etapa = this.stage?.stage;
      if (!etapa) {
        return this.isEditing
          ? this.$t('TRACKING_ASSISTANT_VIEW.THINKING_EDIT')
          : '';
      }
      if (etapa === 'writing') {
        return this.$t(
          this.stage.editing
            ? 'TRACKING_ASSISTANT_VIEW.STAGE_WRITING_EDIT'
            : 'TRACKING_ASSISTANT_VIEW.STAGE_WRITING'
        );
      }
      return this.$t(`TRACKING_ASSISTANT_VIEW.STAGE_${etapa.toUpperCase()}`, {
        round: this.stage.round,
        of: this.stage.of,
      });
    },
    // Cuántas de las preguntas ofrecidas ya tienen respuesta elegida.
    pickedCount() {
      return Object.keys(this.picked).length;
    },
  },
  watch: {
    // Otra conversación (o una nueva): lo desplegado era de la anterior.
    messages(nuevos, viejos) {
      if (!viejos || nuevos.length < viejos.length || nuevos[0] !== viejos[0])
        this.expanded = {};
      this.$nextTick(this.scrollToBottom);
    },
    // Cada turno trae sus propias preguntas: lo elegido en el anterior ya se
    // envió y dejarlo marcado haría que la respuesta siguiente arrastre cosas
    // que la persona no volvió a elegir.
    options() {
      this.picked = {};
      this.$nextTick(this.scrollToBottom);
    },
  },
  methods: {
    hasChanges,
    messageText(message) {
      return message.display || message.content || '';
    },
    isLong(message) {
      const texto = this.messageText(message);
      return (
        texto.split('\n').length > COLLAPSED_LINES ||
        texto.length > COLLAPSED_CHARS
      );
    },
    // El texto a la vista: entero si está desplegado o es corto; si no, el principio.
    shownText(message, index) {
      const texto = this.messageText(message);
      if (this.expanded[index] || !this.isLong(message)) return texto;
      const recorte = texto.split('\n').slice(0, COLLAPSED_LINES).join('\n');
      return `${recorte.slice(0, COLLAPSED_CHARS).trimEnd()}…`;
    },
    // El Asistente escribe en Markdown (**negritas**, viñetas): se muestra con formato,
    // con el formateador nativo de los mensajes de Chatwoot, en vez de ver los
    // asteriscos (pedido del usuario, 24/09/2026). Lo que escribe la persona va tal cual.
    formatted(message, index) {
      return new MessageFormatter(this.shownText(message, index))
        .formattedMessage;
    },
    toggleExpanded(index) {
      this.expanded = { ...this.expanded, [index]: !this.expanded[index] };
    },
    // Solo bajo el ÚLTIMO mensaje, y solo si es del asistente: el hilo de arriba
    // es historial, y un botón de tres turnos atrás contestaría algo ya respondido.
    showOptions(index, message) {
      return (
        message.role === 'assistant' &&
        index === this.messages.length - 1 &&
        !this.isThinking &&
        Boolean(this.options && this.options.length)
      );
    },
    isOpenChoice(choice) {
      return /^otr[ao]s?$/i.test(choice.trim());
    },
    // "otra" no se puede contestar con un botón: hay que decir CUÁL. Al tocarla,
    // todo lo elegido hasta ahí se pasa al campo de texto ya numerado y se deja
    // el cursor listo para escribir.
    //
    // Se mueve TODO y no solo esa pregunta a propósito: si la respuesta queda
    // partida entre los botones y el texto, enviar por un lado pierde el otro.
    // Con todo en el campo, lo que se ve es exactamente lo que se manda.
    openOther(index) {
      const yaElegido = this.composeAnswer();
      this.input = `${yaElegido ? `${yaElegido} · ` : ''}${index + 1}) `;
      this.picked = {};

      this.$nextTick(() => {
        const box = this.$refs.composer;
        if (!box) return;

        box.focus();
        box.setSelectionRange(this.input.length, this.input.length);
      });
    },
    pick(index, choice) {
      if (this.isOpenChoice(choice)) {
        this.openOther(index);
        return;
      }
      // Volver a tocar la misma la deselecciona: es la única forma de corregirse
      // sin recargar.
      this.picked =
        this.picked[index] === choice
          ? Object.fromEntries(
              Object.entries(this.picked).filter(
                ([key]) => Number(key) !== index
              )
            )
          : { ...this.picked, [index]: choice };
    },
    // En la misma clave numerada que el asistente usó al preguntar, para que sepa
    // qué contestó a qué. Solo van las elegidas: mandar las vacías haría que las
    // dé por respondidas.
    composeAnswer() {
      return Object.entries(this.picked)
        .sort(([a], [b]) => Number(a) - Number(b))
        .map(([index, choice]) => `${Number(index) + 1}) ${choice}`)
        .join(' · ');
    },
    sendPicked() {
      if (!this.pickedCount || this.isThinking) return;

      const respuesta = this.composeAnswer();
      this.picked = {};
      this.$emit('send', respuesta);
    },
    // ── dictado ──
    startDictation() {
      if (this.isThinking || this.dictation) return;
      this.dictationTime = '00:00';
      this.dictation = 'recording';
    },
    stopDictation() {
      if (this.dictation !== 'recording') return;
      this.$refs.recorder?.stopAudioRecording();
    },
    cancelDictation() {
      this.dictation = '';
    },
    onRecorderState(state) {
      // Sin permiso de micrófono el grabador ya avisó: solo se cierra.
      if (state === 'notallowederror') this.dictation = '';
    },
    // El texto se SUMA a lo que ya estaba escrito y no se envía: se revisa antes.
    async onRecorded({ file }) {
      this.dictation = 'transcribing';
      try {
        const { data } = await AssistantAPI.transcribe(file);
        const texto = (data.text || '').trim();
        if (!texto) {
          useAlert(this.$t('TRACKING_ASSISTANT_VIEW.DICTATE_EMPTY'));
          return;
        }
        this.input = this.input.trim()
          ? `${this.input.trim()} ${texto}`
          : texto;
        this.$nextTick(() => this.$refs.composer?.focus());
      } catch (error) {
        const code = error?.response?.data?.error;
        useAlert(
          this.$t(
            DICTATION_ERRORS.includes(code)
              ? `TRACKING_ASSISTANT_VIEW.DICTATE_ERROR_${code.toUpperCase()}`
              : 'TRACKING_ASSISTANT_VIEW.DICTATE_ERROR'
          )
        );
      } finally {
        this.dictation = '';
      }
    },
    send() {
      const content = this.input.trim();
      if (!content || this.isThinking) return;
      this.input = '';
      this.$emit('send', content);
    },
    scrollToBottom() {
      const el = this.$refs.thread;
      if (el) el.scrollTop = el.scrollHeight;
    },
  },
};
</script>

<template>
  <div class="flex flex-col h-full min-h-0">
    <div
      ref="thread"
      class="flex-1 min-h-0 overflow-y-auto flex flex-col gap-3"
    >
      <div
        v-for="(message, index) in messages"
        :key="index"
        class="flex"
        :class="message.role === 'user' ? 'justify-end' : 'justify-start'"
      >
        <div
          class="max-w-[85%] text-sm px-3 py-2 rounded-lg"
          :class="
            message.role === 'user'
              ? 'bg-woot-500 text-white'
              : 'bg-slate-100 dark:bg-slate-700 text-slate-800 dark:text-slate-100'
          "
        >
          <!-- `display`: una versión corta para la pantalla, cuando lo que se le
               manda al modelo es largo y no está escrito para leerlo (el encargo). -->
          <div
            v-if="message.role === 'assistant'"
            v-dompurify-html="formatted(message, index)"
            class="break-words [&_p]:mb-2 [&_p:last-child]:mb-0 [&_ul]:list-disc [&_ul]:pl-4 [&_ul]:mb-2 [&_ol]:list-decimal [&_ol]:pl-4 [&_ol]:mb-2 [&_li]:mb-0.5"
          />
          <span v-else class="whitespace-pre-wrap">{{
            shownText(message, index)
          }}</span>
          <button
            v-if="isLong(message)"
            type="button"
            class="block mt-1 text-xs font-medium underline opacity-80 hover:opacity-100"
            @click="toggleExpanded(index)"
          >
            {{
              expanded[index]
                ? $t('TRACKING_ASSISTANT_VIEW.CHAT_SHOW_LESS')
                : $t('TRACKING_ASSISTANT_VIEW.CHAT_SHOW_MORE')
            }}
          </button>

          <ChangeList
            v-if="message.role === 'assistant' && hasChanges(message.changes)"
            :changes="message.changes"
          />

          <!-- Los botones van DENTRO de la burbuja del último mensaje del
               asistente, no en un bloque aparte: separados se leían como dos
               cosas distintas —el texto por un lado y una lista suelta por el
               otro— cuando son la misma pregunta. -->
          <div
            v-if="showOptions(index, message)"
            class="flex flex-col gap-2 pt-3 mt-3 border-t border-slate-200 dark:border-slate-600"
          >
            <!-- La pregunta se dibuja ACÁ, no en el texto del mensaje: el modelo
                 vaciaba el mensaje cada vez que se le pedía no repetir las
                 opciones. Con la pregunta y sus botones en la misma pieza, no
                 hay dos lugares que puedan desincronizarse. -->
            <div v-for="(question, qIndex) in options" :key="qIndex">
              <p class="mb-1 text-sm">
                <!-- El número solo con varias preguntas: con una sola, «1. 6 de estos
                     avisos…» se leía como un decimal (25/09/2026). -->
                <template v-if="options.length > 1">{{ qIndex + 1 }}.</template>
                {{ question.question }}
              </p>
              <div class="flex flex-wrap items-center gap-1">
                <button
                  v-for="choice in question.choices"
                  :key="choice"
                  class="px-2 py-1 text-xs border rounded cursor-pointer"
                  :class="
                    picked[qIndex] === choice
                      ? 'bg-woot-500 text-white border-woot-500'
                      : 'bg-white dark:bg-slate-800 text-slate-700 dark:text-slate-200 border-slate-200 dark:border-slate-600 hover:border-woot-400'
                  "
                  :title="
                    isOpenChoice(choice)
                      ? $t('TRACKING_ASSISTANT_VIEW.PICK_OTHER_HINT')
                      : ''
                  "
                  @click="pick(qIndex, choice)"
                >
                  {{ choice }}
                  <fluent-icon
                    v-if="isOpenChoice(choice)"
                    icon="arrow-right"
                    size="12"
                    class="inline-block"
                  />
                </button>
              </div>
            </div>

            <div>
              <woot-button
                size="small"
                :is-disabled="!pickedCount"
                @click="sendPicked"
              >
                {{
                  pickedCount
                    ? $t('TRACKING_ASSISTANT_VIEW.SEND_PICKED', {
                        count: pickedCount,
                      })
                    : $t('TRACKING_ASSISTANT_VIEW.SEND_PICKED_EMPTY')
                }}
              </woot-button>
            </div>
          </div>
        </div>
      </div>

      <div v-if="isThinking" class="flex justify-start">
        <div
          class="flex items-center gap-2 max-w-[85%] px-3 py-2 rounded-lg bg-slate-100 dark:bg-slate-700"
        >
          <Spinner size="" />
          <span
            v-if="stageLabel"
            class="text-xs text-slate-600 dark:text-slate-300"
          >
            {{ stageLabel }}
          </span>
        </div>
      </div>
    </div>

    <!-- El compositor va en una fila: el texto a la izquierda y Enviar a la
         derecha. Apilados —textarea arriba, botón de ancho completo abajo— se
         llevaban cuatro líneas de alto de la columna donde vive el hilo, que es
         lo único que hay que leer acá.
         items-stretch le da al botón el ALTO del textarea: alineado solo a la
         base quedaba un botón chico flotando junto a una caja de dos renglones.
         resize-none impide que arrastrar el textarea le coma alto al hilo. -->
    <!-- Dictado: mientras graba, la onda del grabador nativo ocupa el lugar del
         texto; al detener, lo dictado vuelve al cuadro para revisarlo. -->
    <div
      v-if="dictation"
      class="flex items-center gap-2 pt-3 shrink-0 text-xs text-slate-600 dark:text-slate-300"
    >
      <WootAudioRecorder
        v-if="dictation === 'recording'"
        ref="recorder"
        class="flex-1 min-w-0"
        :audio-record-format="audioFormat"
        @stateRecorderProgressChanged="dictationTime = $event"
        @stateRecorderChanged="onRecorderState"
        @finishRecord="onRecorded"
      />
      <span v-if="dictation === 'recording'" class="shrink-0 tabular-nums">
        {{
          $t('TRACKING_ASSISTANT_VIEW.DICTATE_RECORDING', {
            time: dictationTime,
          })
        }}
      </span>
      <span v-else class="flex items-center gap-2">
        <Spinner size="" />
        {{ $t('TRACKING_ASSISTANT_VIEW.DICTATE_TRANSCRIBING') }}
      </span>
      <template v-if="dictation === 'recording'">
        <woot-button size="small" @click="stopDictation">
          {{ $t('TRACKING_ASSISTANT_VIEW.DICTATE_STOP') }}
        </woot-button>
        <woot-button
          size="small"
          variant="clear"
          color-scheme="secondary"
          @click="cancelDictation"
        >
          {{ $t('TRACKING_ASSISTANT_VIEW.DICTATE_CANCEL') }}
        </woot-button>
      </template>
    </div>

    <div class="flex items-stretch gap-2 pt-3 shrink-0">
      <textarea
        ref="composer"
        v-model="input"
        rows="2"
        class="flex-1 min-w-0 text-sm resize-none !mb-0"
        :placeholder="$t('TRACKING_ASSISTANT_VIEW.INPUT_PLACEHOLDER')"
        :disabled="isThinking || dictation === 'transcribing'"
        @keydown.enter.exact.prevent="send"
      />
      <woot-button
        class="shrink-0"
        variant="smooth"
        color-scheme="secondary"
        icon="microphone"
        :title="$t('TRACKING_ASSISTANT_VIEW.DICTATE_HINT')"
        :is-disabled="isThinking || Boolean(dictation)"
        @click="startDictation"
      />
      <woot-button
        class="shrink-0"
        :is-disabled="!input.trim() || isThinking"
        :is-loading="isThinking"
        @click="send"
      >
        {{ $t('TRACKING_ASSISTANT_VIEW.SEND') }}
      </woot-button>
    </div>
  </div>
</template>
