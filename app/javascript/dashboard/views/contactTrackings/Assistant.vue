<script>
// proyecto@asistente_agentes_ia — F0 · F4
// ============================================================================
// Pantalla del Asistente de Agentes IA: dos paneles.
//
//   IZQUIERDA  la conversación — pregunta qué querés que haga el agente
//   DERECHA    en qué va el trabajo, el Entrenamiento editable a mano, y
//              colapsados abajo lo que el motor va a leer y la prueba en seco
//
// POR QUÉ EL ENTRENAMIENTO SE LLEVA TODO EL ALTO:
//   La columna derecha tenía tres secciones de alto libre en un solo scroll, y
//   la única con alto FIJO y chico (rows=14) era justo el texto que se está
//   editando. Medido sobre los 28 agentes de la cuenta 2: 46 líneas de mediana,
//   645 el más grande. Se veía el 30% del típico y el 2% del más grande.
//   Ahora el texto toma lo que sobra y los otros dos se colapsan; del comprobador
//   queda siempre a la vista el resumen, que es lo que no se puede esconder.
//
// La tercera pestaña revisa los agentes YA cargados: la misma máquina al revés.
// Ahí "0 ramas" no es un defecto —un agente sin ramas es conversacional, un estilo
// válido— así que ese estado se muestra aparte y no en rojo.
//
// La segunda pestaña muestra el inventario: con qué material trabaja el asistente.
// No es decorativa — ahí se ven las frases de clientes YA enmascaradas, que son
// exactamente las que salen hacia OpenAI. Lo que se ve es lo que se manda.
//
// El panel de abajo es lo que hace distinta a esta pantalla de un editor de
// texto: antes de guardar se ve, en las palabras del motor, qué ramas reconoció
// y en qué fuente va a buscar cada una. Y por eso se revalida al teclear — el
// comprobador es una función pura, así que no cuesta nada.
//
// Guardar queda apagado mientras haya un hallazgo bloqueante: guardar un agente
// que no ejecuta nada es exactamente el problema que este módulo vino a arreglar.
// ============================================================================
import { useAlert } from 'dashboard/composables';
import AssistantAPI from 'dashboard/api/assistant';
import EmptyState from 'dashboard/components/widgets/EmptyState.vue';
import Spinner from 'shared/components/Spinner.vue';
import AccordionItem from 'dashboard/components/Accordion/AccordionItem.vue';
import InterviewPanel from './assistant/InterviewPanel.vue';
import ProgressStrip from './assistant/ProgressStrip.vue';
import ValidationBadge from './assistant/ValidationBadge.vue';
import ValidationReport from './assistant/ValidationReport.vue';
import DryRunPanel from './assistant/DryRunPanel.vue';
import SaveModal from './assistant/SaveModal.vue';

// El teclado va más rápido que un request: se espera a que la persona pare.
const VALIDATE_DEBOUNCE_MS = 400;

// Explícito y no armado por concatenación: una clave dinámica no la puede verificar
// nadie —ni un linter ni quien traduce— y el día que el backend agregue un estado, el
// cartel sale en blanco sin que falle nada.
const AUDIT_STATUS_LABEL = {
  broken: 'TRACKING_ASSISTANT_VIEW.AUDIT_BROKEN',
  routed: 'TRACKING_ASSISTANT_VIEW.AUDIT_ROUTED',
  conversational: 'TRACKING_ASSISTANT_VIEW.AUDIT_CONVERSATIONAL',
  empty: 'TRACKING_ASSISTANT_VIEW.AUDIT_EMPTY',
};

export default {
  components: {
    AccordionItem,
    EmptyState,
    Spinner,
    InterviewPanel,
    ProgressStrip,
    ValidationBadge,
    ValidationReport,
    DryRunPanel,
    SaveModal,
  },
  data() {
    return {
      inventory: null,
      isLoadingInventory: false,
      inventoryError: null,
      messages: [],
      isThinking: false,
      draft: '',
      validation: null,
      isChecking: false,
      showSaveModal: false,
      // Los datos del agente que el asistente propone junto al Entrenamiento.
      proposal: null,
      // De qué Agente IA vino el borrador, si vino de uno. Sin esto, arreglar un
      // agente y guardar creaba un DUPLICADO en vez de corregir el original: el
      // modal abría en "crear nuevo" y nadie lo notaba hasta ver la lista con dos.
      editingTemplate: null,
      // La conversación persistida. Sin esto el hilo vivía solo en el navegador y
      // cerrar la pestaña tiraba una entrevista de 30–45 minutos.
      sessionId: null,
      isSaving: false,
      saveError: '',
      validateTimer: null,
      activeTab: 0,
      audit: [],
      isAuditing: false,
      sessions: [],
      // F6 — probar sin enviar nada. Se dispara con botón, nunca al teclear.
      dryRun: null,
      isDryRunning: false,
      dryRunError: '',
      // El comprobador arranca ABIERTO y la prueba CERRADA. El comprobador es el
      // producto de esta pantalla: esconderlo de entrada sería devolverle el alto
      // al texto a costa de que nadie lo vea. Probar es una acción puntual, y
      // cerrada ocupa una línea en vez de un cuarto de la columna.
      isReportOpen: true,
      isDryRunOpen: false,
      // Modo ancho: esconde la conversación y deja el Entrenamiento a todo el
      // ancho. Para los 6 agentes de la cuenta que pasan de 370 líneas.
      isWideEditor: false,
    };
  },
  computed: {
    isEmptyAccount() {
      return this.inventory?.empty;
    },
    unsupported() {
      return this.inventory?.unsupported || [];
    },
    brokenAgents() {
      return this.audit.filter(row => row.status === 'broken');
    },
    hasBlocking() {
      return Boolean(this.validation?.blocking?.length);
    },
    canSave() {
      return this.draft.trim().length > 0 && !this.hasBlocking;
    },
    inboxes() {
      return this.$store.getters['inboxes/getInboxes'] || [];
    },
    // El getter se llama getTemplates, no getTrackingTemplates: pedir el nombre
    // equivocado devolvía undefined y el `|| []` dejaba el desplegable de
    // "reemplazar" vacío, sin que nada fallara.
    templates() {
      return this.$store.getters['trackingTemplates/getTemplates'] || [];
    },
  },
  async mounted() {
    this.fetchInventory();
    this.$store.dispatch('inboxes/get');
    // Se espera la lista antes de resolver el ?template_id de la URL: si no, se
    // entraría desde Agentes IA con el panel vacío y sin decir por qué.
    await this.$store.dispatch('trackingTemplates/get');
    this.fetchAudit();
    this.fetchSessions();
    // El ?template_id manda sobre la conversación guardada: si se entró desde un
    // agente concreto, es a ese al que se vino, no a lo que quedó a medias.
    if (!this.loadTemplateFromRoute()) await this.resumeSession();
  },
  beforeUnmount() {
    clearTimeout(this.validateTimer);
  },
  methods: {
    // Entrada desde Agentes IA: /tracking-dashboard/assistant?template_id=123
    loadTemplateFromRoute() {
      const id = Number(this.$route.query.template_id);
      if (!id) return false;

      this.loadTemplate(this.templates.find(t => t.id === id));
      return true;
    },
    // Retomar lo que quedó a medias. Si falla, se arranca en limpio: no poder
    // recuperar una conversación no debería impedir empezar otra.
    async resumeSession() {
      try {
        const { data } = await AssistantAPI.getSession();
        if (!data) return;

        this.sessionId = data.id;
        this.messages = data.messages || [];
        this.draft = data.draft || '';
        this.validation = data.validation || null;
        this.proposal = data.proposal || null;
        if (data.tracking_template_id) {
          this.loadEditingFrom(data.tracking_template_id);
        }
      } catch (error) {
        this.sessionId = null;
      }
    },
    loadEditingFrom(id) {
      const template = this.templates.find(t => t.id === id);
      if (template)
        this.editingTemplate = { id: template.id, name: template.name };
    },
    async fetchInventory() {
      this.isLoadingInventory = true;
      this.inventoryError = null;
      try {
        const { data } = await AssistantAPI.getInventory();
        this.inventory = data;
      } catch (error) {
        this.inventoryError =
          error?.response?.status === 401
            ? this.$t('TRACKING_ASSISTANT_VIEW.ERROR_FORBIDDEN')
            : this.$t('TRACKING_ASSISTANT_VIEW.ERROR_GENERIC');
      } finally {
        this.isLoadingInventory = false;
      }
    },
    async fetchSessions() {
      try {
        const { data } = await AssistantAPI.getSessions();
        this.sessions = data;
      } catch (error) {
        this.sessions = [];
      }
    },
    // Abrir una conversación guardada la deja como estaba: hilo, borrador y su
    // comprobación. Es lo que permite comparar dos intentos en vez de reescribir.
    async openSession(id) {
      try {
        const { data } = await AssistantAPI.openSession(id);
        this.sessionId = data.id;
        this.messages = data.messages || [];
        this.draft = data.draft || '';
        this.validation = data.validation || null;
        this.proposal = data.proposal || null;
        this.editingTemplate = null;
        if (data.tracking_template_id)
          this.loadEditingFrom(data.tracking_template_id);
        this.activeTab = 0;
      } catch (error) {
        useAlert(this.$t('TRACKING_ASSISTANT_VIEW.SESSIONS_OPEN_ERROR'));
      }
    },
    async discardSession(id) {
      try {
        await AssistantAPI.discardSession(id);
        this.sessions = this.sessions.filter(s => s.id !== id);
        if (this.sessionId === id) this.startFresh();
      } catch (error) {
        useAlert(this.$t('TRACKING_ASSISTANT_VIEW.SESSIONS_OPEN_ERROR'));
      }
    },
    startFresh() {
      this.sessionId = null;
      this.messages = [];
      this.draft = '';
      this.validation = null;
      this.proposal = null;
      this.editingTemplate = null;
      this.activeTab = 0;
    },
    async fetchAudit() {
      this.isAuditing = true;
      try {
        const { data } = await AssistantAPI.audit();
        this.audit = data;
      } catch (error) {
        this.audit = [];
      } finally {
        this.isAuditing = false;
      }
    },
    // ── El informe como índice ──────────────────────────────────────────
    // En un Entrenamiento de 645 líneas, saber que "la rama comercial no tiene
    // descripción" no sirve de nada si después hay que buscarla a mano. El
    // comprobador ya sabe dónde está: tocar el hallazgo lleva hasta ahí.

    // Selecciona la línea entera, no solo la deja a la vista: en un texto
    // monoespaciado de cientos de líneas, "algo se movió" no le dice a nadie
    // cuál es la línea. Seleccionada, se ve.
    goToLine(line) {
      const editor = this.$refs.draftEditor;
      if (!editor || !line) return;

      const lines = this.draft.split('\n');
      if (line > lines.length) return;

      const start = lines
        .slice(0, line - 1)
        .reduce((total, text) => total + text.length + 1, 0);

      editor.focus();
      editor.setSelectionRange(start, start + lines[line - 1].length);
    },

    // Las ramas del informe no traen número de línea —RouteMap no lo registra— y
    // agregárselo sería tocar el parser de producción por una comodidad de la
    // pantalla. Se busca acá: los nombres de rama son únicos (RouteMap hace
    // uniq(&:name)) y la línea siempre empieza con @ruta(nombre.
    goToRoute(name) {
      const line = this.findRouteLine(name);
      if (line) this.goToLine(line);
    },

    findRouteLine(name) {
      const needle = `@ruta(${name}`.toLowerCase();
      const index = this.draft.split('\n').findIndex(text => {
        const line = text.trimStart().toLowerCase();
        if (!line.startsWith(needle)) return false;

        // Sin esto, una rama llamada "sop" saltaría a la línea de "soporte".
        // Después del nombre solo puede venir la etiqueta, los dos puntos o el
        // paréntesis de cierre.
        return ' \t#:)'.includes(line.charAt(needle.length));
      });
      return index === -1 ? null : index + 1;
    },

    // F6 — probar sin enviar nada. A diferencia de validateDraft, esto NO corre
    // solo: clasifica la rama con el modelo y vectoriza la pregunta.
    async runDryRun(question) {
      this.isDryRunning = true;
      this.dryRunError = '';
      try {
        const { data } = await AssistantAPI.dryRun(this.draft, question, null);
        this.dryRun = data;
      } catch (error) {
        this.dryRun = null;
        this.dryRunError =
          error?.response?.data?.error ||
          this.$t('TRACKING_ASSISTANT_VIEW.DRY_RUN_FAILED');
      } finally {
        this.isDryRunning = false;
      }
    },
    // Cargar un agente roto en el panel lo deja listo para corregir y reemplazar:
    // el arreglo pasa por el mismo comprobador y el mismo guardado que uno nuevo.
    auditLabel(status) {
      return AUDIT_STATUS_LABEL[status] || AUDIT_STATUS_LABEL.empty;
    },
    openInAssistant(row) {
      this.loadTemplate(this.templates.find(t => t.id === row.id));
    },
    // Carga un Agente IA existente para mejorarlo. Deja anotado cuál es, para que
    // el guardado ofrezca reemplazarlo —conservando el Entrenamiento anterior— en
    // vez de crear otro al lado.
    loadTemplate(template) {
      if (!template) return;

      this.draft = template.complementary_prompt || '';
      this.editingTemplate = { id: template.id, name: template.name };
      this.proposal = null;
      this.activeTab = 0;
      this.validateDraft();
    },
    async sendMessage(content) {
      this.messages.push({ role: 'user', content });
      this.isThinking = true;
      try {
        const { data } = await AssistantAPI.interview(this.messages, null, {
          sessionId: this.sessionId,
        });
        this.sessionId = data.session_id || this.sessionId;
        this.messages.push({ role: 'assistant', content: data.reply });
        if (data.draft) {
          this.draft = data.draft;
          this.validation = data.validation;
          this.proposal = data.proposal || null;
        }
      } catch (error) {
        const reason =
          error?.response?.data?.error === 'no_api_key'
            ? this.$t('TRACKING_ASSISTANT_VIEW.ERROR_NO_KEY')
            : this.$t('TRACKING_ASSISTANT_VIEW.ERROR_GENERIC');
        this.messages.push({ role: 'assistant', content: reason });
      } finally {
        this.isThinking = false;
      }
    },
    // Se revalida también cuando la persona edita a mano: el borrador del modelo
    // no es más confiable que el suyo, y ninguno de los dos se guarda sin pasar.
    onDraftInput() {
      clearTimeout(this.validateTimer);
      this.validateTimer = setTimeout(this.validateDraft, VALIDATE_DEBOUNCE_MS);
      // La prueba en seco caduca al editar. Un resultado de hace tres cambios no
      // dice nada del texto que hay ahora, y dejarlo en pantalla —con su rama y
      // sus fragmentos— es peor que no mostrarlo: se lee como si describiera lo
      // que se está viendo.
      this.dryRun = null;
    },
    async validateDraft() {
      if (!this.draft.trim()) {
        this.validation = null;
        return;
      }
      this.isChecking = true;
      try {
        const { data } = await AssistantAPI.validate(this.draft);
        this.validation = data;
      } catch (error) {
        this.validation = null;
      } finally {
        this.isChecking = false;
      }
    },
    async saveDraft(payload) {
      this.isSaving = true;
      this.saveError = '';
      try {
        const { data } = await AssistantAPI.save({
          ...payload,
          draft: this.draft,
          sessionId: this.sessionId,
        });
        this.showSaveModal = false;
        this.editingTemplate = null;
        this.sessionId = null;
        this.$router.push({
          name: 'contact_trackings_agents',
          query: { template_id: data.tracking_template_id },
        });
      } catch (error) {
        const details = error?.response?.data?.details;
        this.saveError = Array.isArray(details)
          ? details.join(' · ')
          : this.$t('TRACKING_ASSISTANT_VIEW.ERROR_GENERIC');
      } finally {
        this.isSaving = false;
      }
    },
  },
};
</script>

<template>
  <div class="flex flex-col flex-1 w-full h-full min-h-0 overflow-hidden p-4">
    <div class="flex items-start justify-between mb-3 shrink-0">
      <div class="flex items-start gap-2">
        <woot-sidemenu-icon />
        <div>
          <h1 class="text-xl font-bold text-slate-800 dark:text-slate-100">
            {{ $t('TRACKING_ASSISTANT_VIEW.TITLE') }}
          </h1>
          <p class="text-sm text-slate-600 dark:text-slate-400 mt-1">
            {{ $t('TRACKING_ASSISTANT_VIEW.DESCRIPTION') }}
          </p>
        </div>
      </div>
      <woot-button
        variant="clear"
        icon="arrow-clockwise"
        :is-loading="isLoadingInventory"
        @click="fetchInventory"
      >
        {{ $t('TRACKING_ASSISTANT_VIEW.REFRESH') }}
      </woot-button>
    </div>

    <div
      v-if="isLoadingInventory"
      class="flex items-center justify-center flex-1"
    >
      <Spinner size="" />
    </div>

    <EmptyState v-else-if="inventoryError" :title="inventoryError" />

    <div v-else-if="inventory" class="flex-1 min-h-0 flex flex-col">
      <!-- Cuenta sin nada cargado: no hay de dónde proponer. -->
      <EmptyState
        v-if="isEmptyAccount"
        :title="$t('TRACKING_ASSISTANT_VIEW.EMPTY_ACCOUNT_TITLE')"
        :message="$t('TRACKING_ASSISTANT_VIEW.EMPTY_ACCOUNT_HINT')"
      />

      <template v-else>
        <woot-tabs
          :index="activeTab"
          class="mb-4 shrink-0"
          @change="activeTab = $event"
        >
          <woot-tabs-item
            :index="0"
            :name="$t('TRACKING_ASSISTANT_VIEW.TAB_ASSISTANT')"
            :show-badge="false"
          />
          <woot-tabs-item
            :index="1"
            :name="$t('TRACKING_ASSISTANT_VIEW.TAB_INVENTORY')"
            :show-badge="false"
          />
          <woot-tabs-item
            :index="2"
            :name="$t('TRACKING_ASSISTANT_VIEW.TAB_AUDIT')"
            :count="brokenAgents.length"
          />
          <woot-tabs-item
            :index="3"
            :name="$t('TRACKING_ASSISTANT_VIEW.TAB_SESSIONS')"
            :count="sessions.length"
          />
        </woot-tabs>

        <div
          v-show="activeTab === 0"
          class="grid flex-1 min-h-0 gap-4"
          :class="isWideEditor ? 'grid-cols-1' : 'md:grid-cols-2'"
        >
          <!-- v-show y no v-if: la conversación se esconde, no se desmonta. Con
               v-if se perdería el scroll del hilo y lo tecleado sin enviar cada
               vez que alguien entra y sale del modo ancho. -->
          <section
            v-show="!isWideEditor"
            class="p-4 bg-white rounded-lg dark:bg-slate-800 border border-slate-100 dark:border-slate-700 flex flex-col min-h-0"
          >
            <InterviewPanel
              :messages="messages"
              :is-thinking="isThinking"
              @send="sendMessage"
            />
          </section>

          <!-- El Entrenamiento manda: se lleva todo el alto que sobre, y los
               dos paneles se colapsan. Antes eran tres secciones de alto libre
               en una sola columna con scroll, y la única con alto FIJO y chico
               (rows=14) era justo el texto que se está editando: en esta cuenta
               los Entrenamientos tienen 46 líneas de mediana y llegan a 645, o
               sea que se veía el 30% del típico y el 2% del más grande. -->
          <section class="flex flex-col gap-2 min-h-0">
            <ProgressStrip
              class="shrink-0 px-1"
              :messages="messages"
              :draft="draft"
              :validation="validation"
              :dry-run="dryRun"
              :editing-template="editingTemplate"
            />

            <!-- min-h-40: piso del editor. Sin él, un Entrenamiento con seis
                 hallazgos abría tanto el informe que el texto se encogía a
                 nada — el mismo problema de antes, por el otro lado. -->
            <div
              class="flex flex-col flex-1 min-h-[10rem] p-4 bg-white rounded-lg dark:bg-slate-800 border border-slate-100 dark:border-slate-700"
            >
              <div class="flex items-center justify-between mb-2 shrink-0">
                <h3
                  class="text-sm font-semibold text-slate-800 dark:text-slate-100"
                >
                  {{ $t('TRACKING_ASSISTANT_VIEW.DRAFT_TITLE') }}
                </h3>
                <!-- Para los Entrenamientos largos: 38 líneas siguen siendo poco
                     para uno de 645. Mientras se edita un texto así no hace falta
                     ver el chat; al volver, sigue donde estaba. -->
                <woot-button
                  variant="clear"
                  size="tiny"
                  color-scheme="secondary"
                  :icon="isWideEditor ? 'chat' : 'arrow-expand'"
                  @click="isWideEditor = !isWideEditor"
                >
                  {{
                    isWideEditor
                      ? $t('TRACKING_ASSISTANT_VIEW.DRAFT_SHOW_CHAT')
                      : $t('TRACKING_ASSISTANT_VIEW.DRAFT_WIDE')
                  }}
                </woot-button>
              </div>
              <!-- resize-none: el alto lo decide el contenedor, no el navegador;
                   arrastrarlo a mano volvería a empujar todo lo de abajo. -->
              <textarea
                ref="draftEditor"
                v-model="draft"
                class="flex-1 min-h-0 w-full font-mono text-xs resize-none !mb-0"
                :placeholder="$t('TRACKING_ASSISTANT_VIEW.DRAFT_PLACEHOLDER')"
                @input="onDraftInput"
              />
            </div>

            <!-- Acordeón nativo, el mismo del panel de contacto. El resumen del
                 comprobador queda SIEMPRE visible en la cabecera: revalida en
                 cada tecla y esa señal no se puede esconder. -->
            <!-- max-h-[40%]: techo de los dos paneles. Lo que no entra scrollea
                 acá adentro en vez de empujar al editor. -->
            <div
              class="shrink-0 max-h-[40%] overflow-y-auto border rounded-lg border-slate-100 dark:border-slate-700"
            >
              <AccordionItem
                :title="$t('TRACKING_ASSISTANT_VIEW.REPORT_TITLE')"
                :is-open="isReportOpen"
                @click="isReportOpen = !isReportOpen"
              >
                <template #button>
                  <ValidationBadge
                    class="mr-2"
                    :validation="validation"
                    :is-checking="isChecking"
                  />
                </template>
                <ValidationReport
                  :validation="validation"
                  @gotoRoute="goToRoute"
                  @gotoLine="goToLine"
                />
              </AccordionItem>

              <AccordionItem
                :title="$t('TRACKING_ASSISTANT_VIEW.DRY_RUN_TITLE')"
                :is-open="isDryRunOpen"
                @click="isDryRunOpen = !isDryRunOpen"
              >
                <DryRunPanel
                  :draft="draft"
                  :result="dryRun"
                  :is-running="isDryRunning"
                  :error="dryRunError"
                  @run="runDryRun"
                />
              </AccordionItem>
            </div>

            <!-- Fuentes guardadas que el asistente no sabe ofrecer. -->
            <p
              v-if="unsupported.length"
              class="shrink-0 text-xs text-amber-600 dark:text-amber-400"
            >
              {{ $t('TRACKING_ASSISTANT_VIEW.UNSUPPORTED_HINT') }}
              {{ unsupported.map(s => s.name).join(' · ') }}
            </p>
          </section>
        </div>

        <!-- Con qué material trabaja el asistente. Las frases van enmascaradas:
             son las mismas que salen hacia OpenAI. -->
        <div
          v-show="activeTab === 1"
          class="flex-1 min-h-0 overflow-y-auto grid gap-4 md:grid-cols-2"
        >
          <section
            class="p-4 bg-white rounded-lg dark:bg-slate-800 border border-slate-100 dark:border-slate-700"
          >
            <h3
              class="text-sm font-semibold text-slate-800 dark:text-slate-100 mb-3"
            >
              {{ $t('TRACKING_ASSISTANT_VIEW.SOURCES_TITLE') }}
            </h3>
            <ul class="flex flex-col gap-2">
              <li
                v-for="source in inventory.sources"
                :key="source.directive"
                class="flex items-center justify-between gap-3"
              >
                <code
                  class="text-xs px-2 py-1 rounded bg-slate-50 dark:bg-slate-900 text-slate-800 dark:text-slate-100 truncate"
                >
                  {{ source.directive }}
                </code>
                <span
                  class="text-xs text-slate-500 dark:text-slate-400 shrink-0"
                >
                  {{ source.name }}
                </span>
              </li>
            </ul>
          </section>

          <section
            class="p-4 bg-white rounded-lg dark:bg-slate-800 border border-slate-100 dark:border-slate-700"
          >
            <h3
              class="text-sm font-semibold text-slate-800 dark:text-slate-100 mb-2"
            >
              {{ $t('TRACKING_ASSISTANT_VIEW.CASE_TYPES_TITLE') }}
            </h3>
            <p class="text-xs text-slate-600 dark:text-slate-400">
              {{ inventory.case_types.join(' · ') || '—' }}
            </p>

            <h3
              class="text-sm font-semibold text-slate-800 dark:text-slate-100 mt-4 mb-2"
            >
              {{ $t('TRACKING_ASSISTANT_VIEW.LABELS_TITLE') }}
            </h3>
            <p class="text-xs text-slate-600 dark:text-slate-400">
              {{ inventory.labels.join(' · ') || '—' }}
            </p>

            <h3
              class="text-sm font-semibold text-slate-800 dark:text-slate-100 mt-4 mb-2"
            >
              {{ $t('TRACKING_ASSISTANT_VIEW.GROUPS_TITLE') }}
            </h3>
            <p class="text-xs text-slate-600 dark:text-slate-400">
              <span
                v-for="group in inventory.canned_groups"
                :key="group.prefix"
              >
                {{ group.prefix }} ({{ group.count }})
              </span>
              <span v-if="!inventory.canned_groups.length">—</span>
            </p>
          </section>

          <section
            class="p-4 bg-white rounded-lg dark:bg-slate-800 border border-slate-100 dark:border-slate-700 md:col-span-2"
          >
            <h3
              class="text-sm font-semibold text-slate-800 dark:text-slate-100 mb-1"
            >
              {{ $t('TRACKING_ASSISTANT_VIEW.PHRASES_TITLE') }}
            </h3>
            <p class="text-xs text-slate-500 dark:text-slate-400 mb-3">
              {{ $t('TRACKING_ASSISTANT_VIEW.PHRASES_HINT') }}
            </p>
            <ul class="flex flex-col gap-1">
              <li
                v-for="phrase in inventory.customer_phrases"
                :key="phrase"
                class="text-xs text-slate-600 dark:text-slate-400"
              >
                · {{ phrase }}
              </li>
              <li
                v-if="!inventory.customer_phrases.length"
                class="text-xs text-slate-500 dark:text-slate-400"
              >
                {{ $t('TRACKING_ASSISTANT_VIEW.PHRASES_EMPTY') }}
              </li>
            </ul>
          </section>
        </div>

        <!-- Revisar los agentes ya cargados. La misma máquina al revés. -->
        <div v-show="activeTab === 2" class="flex-1 min-h-0 overflow-y-auto">
          <p class="text-xs text-slate-500 dark:text-slate-400 mb-3">
            {{ $t('TRACKING_ASSISTANT_VIEW.AUDIT_HINT') }}
          </p>
          <ul class="flex flex-col gap-2">
            <li
              v-for="row in audit"
              :key="row.id"
              class="p-3 bg-white rounded-lg dark:bg-slate-800 border border-slate-100 dark:border-slate-700"
            >
              <div class="flex items-center justify-between gap-3">
                <div class="min-w-0">
                  <div class="flex items-center gap-2">
                    <span
                      class="text-xs font-medium px-2 py-0.5 rounded shrink-0"
                      :class="{
                        'text-red-700 bg-red-100 dark:bg-red-900/30 dark:text-red-300':
                          row.status === 'broken',
                        'text-green-700 bg-green-100 dark:bg-green-900/30 dark:text-green-300':
                          row.status === 'routed',
                        'text-slate-600 bg-slate-100 dark:bg-slate-700 dark:text-slate-300':
                          row.status === 'conversational' ||
                          row.status === 'empty',
                      }"
                    >
                      {{ $t(auditLabel(row.status)) }}
                    </span>
                    <span
                      class="text-sm text-slate-800 dark:text-slate-100 truncate"
                    >
                      {{ row.name }}
                    </span>
                  </div>
                  <p
                    v-if="row.headline"
                    class="text-xs text-red-700 dark:text-red-300 mt-1"
                  >
                    {{ row.headline }}
                  </p>
                  <p
                    v-else-if="row.status === 'routed'"
                    class="text-xs text-slate-500 dark:text-slate-400 mt-1"
                  >
                    {{
                      $t('TRACKING_ASSISTANT_VIEW.REPORT_ROUTES', {
                        count: row.routes,
                      })
                    }}
                  </p>
                </div>
                <woot-button
                  v-if="row.status === 'broken'"
                  size="small"
                  variant="clear"
                  class="shrink-0"
                  @click="openInAssistant(row)"
                >
                  {{ $t('TRACKING_ASSISTANT_VIEW.AUDIT_FIX') }}
                </woot-button>
              </div>
            </li>
          </ul>
        </div>

        <!-- Las conversaciones: un Entrenamiento bueno rara vez sale de una
             sentada, así que hay que poder volver a una y comparar intentos. -->
        <div v-show="activeTab === 3" class="flex-1 min-h-0 overflow-y-auto">
          <div class="flex items-center justify-between mb-3">
            <p class="text-xs text-slate-500 dark:text-slate-400">
              {{ $t('TRACKING_ASSISTANT_VIEW.SESSIONS_HINT') }}
            </p>
            <woot-button variant="clear" size="small" @click="startFresh">
              {{ $t('TRACKING_ASSISTANT_VIEW.SESSIONS_NEW') }}
            </woot-button>
          </div>

          <ul class="flex flex-col gap-2">
            <li
              v-for="row in sessions"
              :key="row.id"
              class="p-3 bg-white rounded-lg dark:bg-slate-800 border border-slate-100 dark:border-slate-700"
            >
              <div class="flex items-center justify-between gap-3">
                <div class="min-w-0">
                  <div class="flex items-center gap-2">
                    <span
                      class="text-xs font-medium px-2 py-0.5 rounded shrink-0"
                      :class="
                        row.status === 'saved'
                          ? 'text-green-700 bg-green-100 dark:bg-green-900/30 dark:text-green-300'
                          : 'text-slate-600 bg-slate-100 dark:bg-slate-700 dark:text-slate-300'
                      "
                    >
                      {{
                        row.status === 'saved'
                          ? $t('TRACKING_ASSISTANT_VIEW.SESSIONS_SAVED')
                          : $t('TRACKING_ASSISTANT_VIEW.SESSIONS_OPEN')
                      }}
                    </span>
                    <span
                      class="text-sm text-slate-800 dark:text-slate-100 truncate"
                    >
                      {{
                        row.title ||
                        $t('TRACKING_ASSISTANT_VIEW.SESSIONS_UNTITLED')
                      }}
                    </span>
                  </div>
                  <p class="text-xs text-slate-500 dark:text-slate-400 mt-1">
                    <span v-if="row.template_name">
                      {{ row.template_name }} ·
                    </span>
                    {{
                      $t('TRACKING_ASSISTANT_VIEW.REPORT_ROUTES', {
                        count: row.routes,
                      })
                    }}
                  </p>
                </div>
                <div class="flex items-center gap-1 shrink-0">
                  <woot-button
                    size="small"
                    variant="clear"
                    @click="openSession(row.id)"
                  >
                    {{ $t('TRACKING_ASSISTANT_VIEW.SESSIONS_RESUME') }}
                  </woot-button>
                  <woot-button
                    size="small"
                    variant="clear"
                    color-scheme="alert"
                    icon="delete"
                    @click="discardSession(row.id)"
                  />
                </div>
              </div>
            </li>
            <li
              v-if="!sessions.length"
              class="text-xs text-slate-500 dark:text-slate-400 py-4"
            >
              {{ $t('TRACKING_ASSISTANT_VIEW.SESSIONS_EMPTY') }}
            </li>
          </ul>
        </div>

        <div
          v-show="activeTab === 0"
          class="flex justify-end gap-2 pt-4 shrink-0"
        >
          <woot-button :is-disabled="!canSave" @click="showSaveModal = true">
            {{ $t('TRACKING_ASSISTANT_VIEW.SAVE_CTA') }}
          </woot-button>
        </div>
      </template>
    </div>

    <SaveModal
      :show="showSaveModal"
      :templates="templates"
      :inboxes="inboxes"
      :is-saving="isSaving"
      :proposal="proposal"
      :editing-template="editingTemplate"
      :error="saveError"
      @close="showSaveModal = false"
      @save="saveDraft"
    />
  </div>
</template>

<style scoped>
/* AccordionItem viene del panel de contacto, donde sus secciones SÍ se arrastran
   para reordenarlas, así que su cabecera trae `cursor-grab`. Acá no se arrastra
   nada: el cursor prometía un gesto que no existe. Se corrige solo dentro de esta
   pantalla; el componente sigue igual para quien lo usa como fue pensado. */
:deep(.drag-handle) {
  cursor: pointer;
}
</style>
