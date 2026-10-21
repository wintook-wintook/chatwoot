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
import TrackingTemplatesAPI from 'dashboard/api/trackingTemplates';
import EmptyState from 'dashboard/components/widgets/EmptyState.vue';
import Spinner from 'shared/components/Spinner.vue';
import {
  findRouteLine,
  lineRange,
  lineMarks,
  lineMessages,
} from './assistant/draftNavigation';
import DraftLineMarks from './assistant/DraftLineMarks.vue';
import ChangeLog from './assistant/ChangeLog.vue';
import ConfigureTab from './assistant/ConfigureTab.vue';
import { withCannedGroup } from './assistant/knowledgeGroup';
import { emitter } from 'shared/helpers/mitt';
import { ASSISTANT_SOURCES_CHANGED } from './assistant/sourceDirective';
import { pendingCount } from './assistant/pendingMarkers';
import InterviewPanel from './assistant/InterviewPanel.vue';
import SessionCard from './assistant/SessionCard.vue';
import ProgressStrip from './assistant/ProgressStrip.vue';
import ValidationBadge from './assistant/ValidationBadge.vue';
import ReportModal from './assistant/ReportModal.vue';
import InstructionsPanel from './assistant/InstructionsPanel.vue';
import {
  instructionsProgress,
  instructionsFilename,
} from './assistant/instructionsProgress';
import { downloadMarkdown } from './assistant/engineCatalogMarkdown';
import {
  mentionsConversation,
  reviewMessage,
  hasTrainingFixes,
} from './assistant/conversationReview';
import BriefModal from './assistant/BriefModal.vue';
import PublishedPromptsModal from './assistant/PublishedPromptsModal.vue'; // proyecto@publicar_prompts
import PublishedUpdateModal from './assistant/PublishedUpdateModal.vue'; // proyecto@publicar_prompts (F7)
import ManualConflictNotice from './assistant/ManualConflictNotice.vue';
import VersionsPanel from './assistant/VersionsPanel.vue';
// La Estructura del Agente: el árbol con sus modales (docs/estructura_agente_arbol_plan.md).
import AgentStructure from './assistant/AgentStructure.vue';
import trainingSectionsMixin from './assistant/trainingSectionsMixin';
import OptimizeModal from './assistant/OptimizeModal.vue';
import ExplainModal from './assistant/ExplainModal.vue';
import DryRunModal from './assistant/DryRunModal.vue';
import TestBatteryModal from './assistant/TestBatteryModal.vue';
import SaveModal from './assistant/SaveModal.vue';

// El teclado va más rápido que un request: se espera a que la persona pare.
const VALIDATE_DEBOUNCE_MS = 400;
// Cada cuánto se pregunta en qué etapa está el turno. Las etapas duran de 1 a 58 s:
// más seguido no muestra nada nuevo.
const PROGRESS_POLL_MS = 1500;
const OPTIMIZE_MAX_WAIT_MS = 5 * 60 * 1000;
// Guardado automático de lo editado a mano: tras esta pausa sin escribir.
const AUTOSAVE_DELAY_MS = 4000;
// Pegar un prompt en el Entrenamiento vacío ofrece analizarlo (onDraftPaste). Menos
// que esto es un nombre o una prueba, no un prompt.
const MIN_PASTE_TO_ANALYZE = 80;
const INBOX_STORAGE_KEY = 'tracking_assistant_inbox_id';

// El chat del Asistente, escondido a pedido del usuario (17/09/2026): el
// Entrenamiento se arma en el formulario de secciones, que se lleva todo el ancho.
// Vuelve el 23/09/2026 para REFINAR, y comparte la columna izquierda con la
// Estructura del Agente: se ve uno a la vez (`leftPanel`), con un selector arriba.
// La pantalla arranca en la Estructura; el chat se abre solo al crear un
// Entrenamiento desde un encargo.
const SHOW_CHAT = true;

// Las pestañas «Versiones» y «Cambios» del Entrenamiento. Escondidas el 20/10/2026
// por el momento; el historial se sigue guardando igual.
const SHOW_HISTORY_TABS = false;

// feat/agentes_ia_unificado (21/10/2026): el Asistente ya no es una pantalla con
// pestañas propias. Vive dentro del espacio de cada agente (AgentWorkspace) y recibe
// por props qué agente o qué conversación abrir. «En construcción», la auditoría y
// «Recursos» se mudaron a la lista de Agentes IA (agents/SessionsPanel,
// agents/InventoryPanel y la columna «Revisión»). Publicar ya no navega: avisa con
// `saved` y el espacio sigue en el mismo agente.

export default {
  components: {
    EmptyState,
    Spinner,
    InterviewPanel,
    DraftLineMarks,
    ChangeLog,
    ConfigureTab,
    SessionCard,
    ProgressStrip,
    ValidationBadge,
    ReportModal,
    InstructionsPanel,
    BriefModal,
    PublishedPromptsModal,
    PublishedUpdateModal,
    ManualConflictNotice,
    VersionsPanel,
    AgentStructure,
    OptimizeModal,
    ExplainModal,
    DryRunModal,
    TestBatteryModal,
    SaveModal,
  },
  mixins: [trainingSectionsMixin],
  props: {
    // El agente a abrir; null = agente nuevo.
    templateId: { type: Number, default: null },
    // Retomar esta conversación (desde «En construcción»).
    initialSessionId: { type: Number, default: null },
    // Abrir la Galería al entrar («Nuevo agente › Bajar de la Galería»).
    openGallery: { type: Boolean, default: false },
  },
  emits: ['saved', 'installed', 'session'],
  data() {
    return {
      // Las secciones tienen columna propia y no se apagan: el mixin siempre
      // sincroniza en los dos sentidos (ver trainingSectionsMixin).
      trainingView: 'sections',
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
      // Una edición que dejaba sin ejecutar el Entrenamiento que ejecutaba: el
      // backend conserva el anterior y manda lo propuesto aparte ({ draft,
      // validation }), para que la persona decida con los dos a la vista.
      rejected: null,
      // Lo último que entregó el asistente (o el agente cargado). Lo que difiere
      // de esto en el editor es lo que la persona escribió a mano (fase B).
      lastDelivered: '',
      // El asistente pisó algo editado a mano: { assistant_draft, items }.
      manualConflict: null,
      // La entrevista sigue abierta y lo que hay en el editor es un borrador (fase
      // C). Lo decide el backend en cada turno que trae Entrenamiento; la pantalla
      // solo lo recuerda y se lo devuelve. Deducirlo de las marcas <PENDIENTE:>
      // falló: una etiqueta adivinada no lleva marca, y la entrevista pasaba a
      // "editar" antes de preguntarla.
      isBuilding: true,
      // Fase D: las versiones del Entrenamiento en esta conversación (sin texto) y
      // qué muestra el panel derecho: el editor o la lista de versiones.
      versions: [],
      draftTab: 'editor',
      // proyecto@adaptar_prompts_publicados — pestaña «Configurar»: lo que el texto
      // usa y la cuenta no tiene (AdaptationInventory). Se pide junto con el comprobador.
      adaptationItems: [],
      isAdapting: false,
      // La etapa del turno en curso, consultada mientras se espera ({ stage, … }).
      turnStage: null,
      // El canal del agente. Decide con qué modelo clasifica y contesta el motor
      // (y de dónde salen las frases de clientes del inventario). Sin canal, la
      // prueba de ruteo y los tests usan el modelo por defecto, no el del agente.
      inboxId: null,
      progressTimer: null,
      // De qué Agente IA vino el borrador, si vino de uno. Sin esto, arreglar un
      // agente y guardar creaba un DUPLICADO en vez de corregir el original: el
      // modal abría en "crear nuevo" y nadie lo notaba hasta ver la lista con dos.
      editingTemplate: null,
      // La conversación persistida. Sin esto el hilo vivía solo en el navegador y
      // cerrar la pestaña tiraba una entrevista de 30–45 minutos.
      sessionId: null,
      // Su identidad —id, estado, fechas, de qué agente salió—. La pantalla
      // mostraba el hilo y el borrador sin decir en CUÁL conversación estabas.
      sessionMeta: null,
      isSaving: false,
      saveError: '',
      validateTimer: null,
      // F6 — probar sin enviar nada. Se dispara con botón, nunca al teclear.
      // El historial no se borra al editar el Entrenamiento: las corridas viejas
      // se marcan como de otra versión. Borrarlas perdería justo la comparación
      // que se vino a hacer.
      dryRunHistory: [],
      // Fase E: tests sugeridos ({ cases, generated_by, version }) y su avance.
      suggestedTests: null,
      // Fase E: optimizar ({ …, version }) y explicar lo seleccionado en el editor.
      showOptimizeModal: false,
      optimizeResult: null,
      // El <textarea> del Entrenamiento, para DraftLineMarks. Los $refs no son
      // reactivos y el editor aparece y desaparece con las pestañas: se toma en
      // cada render (ver `updated`).
      draftEditorEl: null,
      // Lo último que se guardó solo (autosave), para no mandar lo mismo dos veces.
      lastAutosaved: '',
      isOptimizing: false,
      optimizeError: '',
      draftSelection: '',
      showExplainModal: false,
      explainExcerpt: '',
      explainResult: null,
      isExplaining: false,
      explainError: '',
      isSuggesting: false,
      suggestStage: null,
      showDryRunModal: false,
      // «Probar el agente» (pila en vivo, M5) y el encargo del que salió el agente.
      showTestBattery: false,
      batteryBriefId: null,
      draftVersion: 0,
      isDryRunning: false,
      dryRunError: '',
      // Las preguntas del último turno, para mostrarlas como botones.
      interviewOptions: null,
      // El comprobador arranca ABIERTO y la prueba CERRADA. El comprobador es el
      // producto de esta pantalla: esconderlo de entrada sería devolverle el alto
      // al texto a costa de que nadie lo vea. Probar es una acción puntual, y
      // cerrada ocupa una línea en vez de un cuarto de la columna.
      // El informe del comprobador, en un modal: el alto de la columna es del texto.
      showReportModal: false,
      // El encargo (.md) con la idea del agente: ver BriefModal.
      showBriefModal: false,
      // proyecto@publicar_prompts: la Galería de prompts publicados por otras cuentas.
      showPublishedPrompts: false,
      showPublishedUpdate: false, // F7: «el autor publicó una versión nueva»
      isWritingBrief: false,
      // Qué ocupa la columna izquierda: 'structure' (la Estructura del Agente) o
      // 'chat'. Uno a la vez (pedido del usuario, 23/09/2026): con los dos, más el
      // Entrenamiento, eran tres columnas apretadas.
      leftPanel: 'structure',
      // Las instrucciones iniciales que se llenan conversando mientras no hay
      // Entrenamiento (DraftingChat). Se guardan con la conversación.
      instructions: '',
      // Unas instrucciones mandadas a leer desde el chat: el modal las toma de acá.
      chatBrief: null,
      isSendingInstructions: false,
      // Las cuentas de Google conectadas, para elegir el calendario al guardar.
      calendarIntegrations: [],
    };
  },
  computed: {
    // proyecto@adaptar_prompts_publicados — cuántas cosas faltan configurar.
    adaptationMissing() {
      return this.adaptationItems.filter(item => item.status === 'missing')
        .length;
    },
    editingTemplateId() {
      return this.editingTemplate ? this.editingTemplate.id : null;
    },
    // Las líneas del texto con hallazgos, para pintarlas en el editor.
    draftLineMarks() {
      return lineMarks(this.draft, this.validation);
    },
    // Lo que dice cada línea marcada, para el recuadro al pasar el mouse.
    draftLineMessages() {
      return lineMessages(this.draft, this.validation);
    },
    // El texto que edita el mixin de secciones acá es el borrador. Al escribirlo se
    // pasa por onDraftInput, igual que si se hubiera tipeado en el editor: revalida,
    // envejece las pruebas y cuenta como edición a mano.
    trainingText: {
      get() {
        return this.draft;
      },
      set(texto) {
        if (texto === this.draft) return;
        this.draft = texto;
        this.onDraftInput();
      },
    },
    trainingInboxId() {
      return this.inboxId;
    },
    showChat() {
      return SHOW_CHAT;
    },
    showHistoryTabs() {
      return SHOW_HISTORY_TABS;
    },
    // Qué puede ocupar la columna izquierda, con el texto de su botón.
    leftPanels() {
      const avance = instructionsProgress(this.instructions);
      return [
        {
          id: 'structure',
          icon: 'list',
          label: this.$t('TRACKING_ASSISTANT_VIEW.TREE_TITLE'),
        },
        {
          id: 'chat',
          icon: 'chat',
          label: this.$t('TRACKING_ASSISTANT_VIEW.PANEL_CHAT', {
            count: this.messages.length,
          }),
        },
        {
          id: 'instructions',
          icon: 'document',
          label: avance.total
            ? this.$t('TRACKING_ASSISTANT_VIEW.PANEL_INSTRUCTIONS', {
                filled: avance.filled,
                total: avance.total,
              })
            : this.$t('TRACKING_ASSISTANT_VIEW.PANEL_INSTRUCTIONS_EMPTY'),
        },
      ];
    },
    // Con un agente abierto, guardar es publicar el borrador en él (deja versión);
    // sin agente, es crearlo.
    saveLabel() {
      return this.editingTemplate
        ? this.$t('TRACKING_ASSISTANT_VIEW.PUBLISH_CTA')
        : this.$t('TRACKING_ASSISTANT_VIEW.CREATE_CTA');
    },
    // El Entrenamiento agenda: al guardar hay que elegir el calendario.
    usesCalendar() {
      return /@agendar_calendar\b/i.test(this.draft);
    },
    // En la plantilla no: el loader de Vue 2 no entiende `?.` ahí.
    // Se comparan con los espacios normalizados: agregar un salto de línea no es
    // "editar a mano" de nada que valga avisarle al asistente.
    hasManualEdits() {
      const plano = texto => (texto || '').replace(/\s+/g, ' ').trim();
      return plano(this.draft) !== plano(this.lastDelivered);
    },
    draftPendingCount() {
      return pendingCount(this.draft);
    },
    rejectedBlockingCount() {
      return this.rejected?.validation?.blocking?.length || 0;
    },
    isEmptyAccount() {
      return this.inventory?.empty;
    },
    unsupported() {
      return this.inventory?.unsupported || [];
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
    // proyecto@publicar_prompts (F7) — el agente cargado se bajó de la Galería y el autor
    // publicó una versión más nueva: { published_prompt_id, version, current_version }.
    publishedUpdate() {
      if (!this.editingTemplate) return null;
      const template = this.templates.find(
        t => t.id === this.editingTemplate.id
      );
      return (template && template.published_prompt_update) || null;
    },
    publishedUpdateText() {
      const update = this.publishedUpdate;
      if (!update) return '';
      return this.$t('TRACKING_ASSISTANT_VIEW.GALLERY.UPDATE_NOTICE', {
        version: update.version,
        current: update.current_version || 1,
      });
    },
    // El getter se llama getTemplates, no getTrackingTemplates: pedir el nombre
    // equivocado devolvía undefined y el `|| []` dejaba el desplegable de
    // "reemplazar" vacío, sin que nada fallara.
    templates() {
      return this.$store.getters['trackingTemplates/getTemplates'] || [];
    },
    // El último resultado, para la tira de hitos: "Probado" se apaga cuando el
    // borrador cambió después de la prueba.
    lastDryRun() {
      const ultima = this.dryRunHistory[this.dryRunHistory.length - 1];
      return ultima && ultima.version === this.draftVersion
        ? ultima.result
        : null;
    },
  },
  watch: {
    // Publicar un agente nuevo o bajar uno de la Galería cambia la ruta a ese agente:
    // si ya es el que está abierto, no se recarga (se perdería el chat de bienvenida).
    templateId(id) {
      if (id && this.editingTemplate && this.editingTemplate.id === id) return;
      this.openFromProps();
    },
    initialSessionId(id) {
      if (id && id !== this.sessionId) this.openFromProps();
    },
    // Los calendarios se piden al abrir Guardar y solo si el agente agenda: la
    // lista consulta Google por cada cuenta conectada.
    async showSaveModal(abierto) {
      if (!abierto || !this.usesCalendar) return;
      try {
        const { data } = await TrackingTemplatesAPI.getCalendarIntegrations();
        this.calendarIntegrations = Array.isArray(data) ? data : [];
      } catch (error) {
        this.calendarIntegrations = [];
      }
    },
  },
  updated() {
    const editor = this.$refs.draftEditor || null;
    if (editor !== this.draftEditorEl) this.draftEditorEl = editor;
  },
  async mounted() {
    // El último canal elegido en este navegador: es una comodidad, no un dato
    // de la conversación.
    try {
      const guardado = Number(window.localStorage.getItem(INBOX_STORAGE_KEY));
      if (guardado) this.inboxId = guardado;
    } catch (error) {
      this.inboxId = null;
    }
    this.fetchInventory();
    // Una fuente creada desde el modal de una ruta (RouteFields): la lista de fuentes
    // se recarga y el Entrenamiento se vuelve a comprobar, sin salir del Asistente.
    emitter.on(ASSISTANT_SOURCES_CHANGED, this.onSourcesChanged);
    // «Configurar» manda a otras pantallas en otra pestaña: al volver, se revisa.
    window.addEventListener('focus', this.onWindowFocus);
    this.$store.dispatch('inboxes/get');
    // Se espera la lista antes de resolver el ?template_id de la URL: si no, se
    // entraría desde Agentes IA con el panel vacío y sin decir por qué.
    await this.$store.dispatch('trackingTemplates/get');
    await this.openFromProps();
    if (this.openGallery) this.showPublishedPrompts = true;
    // Sin nada que retomar, el formulario igual tiene que estar listo (los nombres
    // de sección que ofrece "Agregar sección" salen del backend).
    this.reloadTrainingSections();
  },
  // ⚠ Era `beforeUnmount`, que en Vue 2.7 con la Options API no existe: el
  // temporizador de validación nunca se limpiaba al salir de la pantalla.
  beforeDestroy() {
    clearTimeout(this.validateTimer);
    clearInterval(this.progressTimer);
    emitter.off(ASSISTANT_SOURCES_CHANGED, this.onSourcesChanged);
    window.removeEventListener('focus', this.onWindowFocus);
    // Lo que quedaba por guardar solo, se manda al salir de la pantalla.
    if (this.autosaveTimer) this.autosaveDraft();
  },
  methods: {
    // Lo editado a mano se guarda solo, en la conversación (pedido del usuario,
    // 25/09/2026: cerrar la pestaña sin mandar mensaje ni guardar lo perdía). Sin
    // conversación todavía, el servidor la crea.
    async autosaveDraft() {
      clearTimeout(this.autosaveTimer);
      const texto = this.draft;
      if (!texto.trim() || this.isThinking || texto === this.lastAutosaved)
        return;
      try {
        const { data } = await AssistantAPI.autosaveDraft(
          texto,
          this.sessionId
        );
        this.lastAutosaved = texto;
        this.sessionId = data.session_id || this.sessionId;
        if (data.session && !this.sessionMeta) this.sessionMeta = data.session;
        if (Array.isArray(data.versions)) this.versions = data.versions;
      } catch (error) {
        // Sin guardado automático se sigue editando; se guarda al mandar o al guardar.
      }
    },
    // Nombre puesto a mano; se refleja también en la lista de «En construcción».
    async renameSession(name) {
      if (!this.sessionId) return;
      try {
        const { data } = await AssistantAPI.renameSession(this.sessionId, name);
        this.sessionMeta = {
          ...this.sessionMeta,
          title: data.title,
          named: data.named,
        };
      } catch (error) {
        useAlert(this.$t('TRACKING_ASSISTANT_VIEW.SESSION_RENAME_ERROR'));
      }
    },
    async onSourcesChanged() {
      await this.fetchInventory();
      // El árbol toma la comprobación de la vista previa si la hay: se descarta para
      // que use la nueva, que ya conoce la fuente.
      this.trainingValidation = null;
      this.validateDraft();
    },
    // feat/agentes_ia_unificado — qué abrir: la conversación pedida; si no, la que el
    // agente tenga a medias (su borrador sin publicar: salir del espacio no lo pierde);
    // si no, el agente tal como está publicado; sin agente, uno nuevo.
    async openFromProps() {
      if (this.initialSessionId) {
        await this.openSession(this.initialSessionId);
        return;
      }
      if (!this.templateId) {
        this.startFresh();
        return;
      }
      const abierta = await this.openSessionFor(this.templateId);
      if (abierta) return;
      this.loadTemplate(this.templates.find(t => t.id === this.templateId));
    },
    async openSessionFor(templateId) {
      try {
        const { data } = await AssistantAPI.getSessions();
        const sesion = (data || [])
          .filter(
            s => s.status === 'open' && s.tracking_template_id === templateId
          )
          .sort((a, b) => new Date(b.updated_at) - new Date(a.updated_at))[0];
        if (!sesion) return false;
        await this.openSession(sesion.id);
        return true;
      } catch (error) {
        return false;
      }
    },
    // Retomar y abrir una conversación cargan lo mismo. Estaba escrito dos veces
    // y sumar la identidad habría hecho una tercera copia: cada campo nuevo hay
    // que acordarse de agregarlo en todas, y el que se olvida no falla — queda
    // en blanco.
    applySession(data) {
      this.sessionId = data.id;
      this.interviewOptions = null;
      this.messages = data.messages || [];
      this.instructions = data.instructions || '';
      this.draft = data.draft || '';
      this.validation = data.validation || null;
      this.proposal = data.proposal || null;
      this.rejected = null;
      this.manualConflict = null;
      this.lastDelivered = data.draft || '';
      // La sesión no guarda el estado: sin borrador, o con marcas, sigue abierta.
      this.isBuilding = !data.draft || pendingCount(data.draft) > 0;
      this.versions = data.versions || [];
      this.draftTab = 'editor';
      this.adaptationItems = [];
      this.reloadTrainingSections();
      this.dryRunHistory = [];
      this.suggestedTests = null;
      this.optimizeResult = null;
      this.sessionMeta = {
        id: data.id,
        status: data.status,
        title: data.title,
        template_name: data.template_name,
        created_at: data.created_at,
        updated_at: data.updated_at,
      };
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
        const { data } = await AssistantAPI.getInventory(this.inboxId);
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
    // Abrir una conversación guardada la deja como estaba: hilo, borrador y su
    // comprobación. Es lo que permite comparar dos intentos en vez de reescribir.
    async openSession(id) {
      try {
        const { data } = await AssistantAPI.openSession(id);
        this.applySession(data);
        this.editingTemplate = null;
        if (data.tracking_template_id)
          this.loadEditingFrom(data.tracking_template_id);
        this.$emit('session', data.id);
      } catch (error) {
        useAlert(this.$t('TRACKING_ASSISTANT_VIEW.SESSIONS_OPEN_ERROR'));
      }
    },
    startFresh() {
      this.instructions = '';
      this.chatBrief = null;
      this.sessionId = null;
      this.sessionMeta = null;
      this.interviewOptions = null;
      this.dryRunHistory = [];
      this.suggestedTests = null;
      this.optimizeResult = null;
      this.messages = [];
      this.draft = '';
      this.validation = null;
      this.proposal = null;
      this.rejected = null;
      this.manualConflict = null;
      this.lastDelivered = '';
      this.lastAutosaved = '';
      clearTimeout(this.autosaveTimer);
      this.isBuilding = true;
      this.versions = [];
      this.draftTab = 'editor';
      this.adaptationItems = [];
      this.reloadTrainingSections();
      this.editingTemplate = null;
    },
    // ── El informe como índice ──────────────────────────────────────────
    // En un Entrenamiento de 645 líneas, saber que "la rama comercial no tiene
    // descripción" no sirve de nada si después hay que buscarla a mano. El
    // comprobador ya sabe dónde está: tocar el hallazgo lleva hasta ahí.

    // Selecciona la línea entera, no solo la deja a la vista: en un texto
    // monoespaciado de cientos de líneas, "algo se movió" no le dice a nadie
    // cuál es la línea. Seleccionada, se ve.
    //
    // El cálculo vive en draftNavigation.js, con su spec: la regla del límite
    // del nombre de rama se rompe sola y en silencio.
    goToLine(line) {
      const editor = this.$refs.draftEditor;
      const range = lineRange(this.draft, line);
      if (!editor || !range) return;

      editor.focus();
      editor.setSelectionRange(range[0], range[1]);
    },

    goToRoute(name) {
      this.goToLine(findRouteLine(this.draft, name));
    },

    // F6 — probar sin enviar nada. A diferencia de validateDraft, esto NO corre
    // solo: clasifica la rama con el modelo y vectoriza la pregunta.
    async runDryRun(question) {
      this.isDryRunning = true;
      this.dryRunError = '';
      try {
        const { data } = await AssistantAPI.dryRun(
          this.draft,
          question,
          this.inboxId
        );
        // Con la versión del borrador contra la que se corrió: es lo que después
        // permite decir "esto ya no describe el texto actual".
        this.dryRunHistory.push({
          question,
          result: data,
          version: this.draftVersion,
        });
      } catch (error) {
        this.dryRunError =
          error?.response?.data?.error ||
          this.$t('TRACKING_ASSISTANT_VIEW.DRY_RUN_FAILED');
      } finally {
        this.isDryRunning = false;
      }
    },
    // proyecto@publicar_prompts (F5) — se bajó UN prompt publicado: la copia ya es un
    // Agente IA de la cuenta. Se abre aquí como cualquier agente cargado (guardar la
    // reemplaza a ella, nunca al original del autor) y el chat arranca diciendo qué se
    // bajó, qué falta configurar y qué contar para adecuarlo.
    // proyecto@adaptar_prompts_publicados (F3): se abre en «Configurar» — lo que falta
    // se resuelve ahí, ya no se lista en el chat.
    async onPromptInstalled({ tracking_template: copia }) {
      this.showPublishedPrompts = false;
      await this.$store.dispatch('trackingTemplates/get');
      const template = this.templates.find(t => t.id === copia.id);
      useAlert(
        this.$t('TRACKING_ASSISTANT_VIEW.GALLERY.INSTALLED', {
          name: copia.name,
        })
      );
      if (!template) return;

      this.startFresh();
      this.loadTemplate(template);
      this.$emit('installed', template.id);
      this.draftTab = 'configure';
      this.messages = [
        { role: 'assistant', content: this.installedIntro(copia.name) },
      ];
      if (this.showChat) this.leftPanel = 'chat';
    },
    installedIntro(name) {
      const t = (key, args) =>
        this.$t(`TRACKING_ASSISTANT_VIEW.GALLERY.${key}`, args);
      return [
        t('INTRO_DONE', { name }),
        t('INTRO_CONFIGURE'),
        t('INTRO_ASK'),
      ].join('\n\n');
    },
    // F7: el texto de la versión nueva va al editor SIN guardar. Cuenta como editado a
    // mano (lastDelivered sigue siendo el guardado): la persona revisa y guarda si quiere.
    // proyecto@adaptar_prompts_publicados (F6): se abre en «Configurar», prellenada con lo
    // que ya se había configurado en este agente (adaptation_answers): un clic en Aplicar.
    loadPublishedVersion(published) {
      this.draft = published.prompt || '';
      this.draftTab = 'configure';
      this.reloadTrainingSections();
      this.validateDraft();
      useAlert(this.$t('TRACKING_ASSISTANT_VIEW.GALLERY.UPDATE_LOADED'));
    },
    // Carga un Agente IA existente para mejorarlo. Deja anotado cuál es, para que
    // el guardado ofrezca reemplazarlo —conservando el Entrenamiento anterior— en
    // vez de crear otro al lado.
    loadTemplate(template) {
      if (!template) return;

      this.draft = template.complementary_prompt || '';
      this.editingTemplate = { id: template.id, name: template.name };
      if (template.inbox_id) this.setInbox(template.inbox_id);
      this.proposal = null;
      this.rejected = null;
      this.manualConflict = null;
      // El agente cargado cuenta como entregado: lo editado a mano es lo que se
      // le cambie a partir de acá. Y está terminado: lo que se pida es editarlo.
      this.lastDelivered = this.draft;
      this.isBuilding = false;
      this.versions = [];
      this.draftTab = 'editor';
      this.reloadTrainingSections();
      // Traer un agente al Asistente arranca una conversación nueva: la
      // identidad y la prueba de la anterior no describen nada de esto.
      this.sessionId = null;
      this.sessionMeta = null;
      this.interviewOptions = null;
      this.dryRunHistory = [];
      this.suggestedTests = null;
      this.optimizeResult = null;
      this.validateDraft();
    },
    // oneShot: redacta de una, sin preguntar (lo usa el encargo, ver writeFromBrief).
    // Sin Entrenamiento todavía, el chat conversa para llenar las instrucciones
    // iniciales (armar un agente desde cero); con uno en pantalla, lo edita.
    //
    // Un link a una conversación (…/conversations/173) no es un turno: es pedir que
    // se revise esa conversación real (reviewConversation).
    async sendMessage(content, { oneShot = false } = {}) {
      if (!oneShot && mentionsConversation(content)) {
        await this.reviewConversation(content);
        return;
      }
      if (!oneShot && !this.draft.trim()) {
        await this.sendDraftingMessage(content);
        return;
      }
      this.messages.push({ role: 'user', content });
      this.isThinking = true;
      const turnId = this.startProgress();
      try {
        const { data } = await AssistantAPI.interview(
          this.messages,
          this.inboxId,
          {
            oneShot,
            sessionId: this.sessionId,
            draft: this.draft.trim() ? this.draft : null,
            deliveredDraft: this.lastDelivered,
            building: this.isBuilding,
            turnId,
          }
        );
        this.sessionId = data.session_id || this.sessionId;
        // El backend devuelve la identidad ya armada: sin eso habría que
        // inventar las fechas del lado del cliente.
        if (data.session) this.sessionMeta = data.session;
        // Solo del último turno: en cuanto se contesta, dejan de ofrecerse.
        this.interviewOptions = data.options || null;
        this.messages.push({
          role: 'assistant',
          content: data.reply,
          changes: data.changes || null,
        });
        if (data.draft) {
          this.draft = data.draft;
          // Con conflicto, lo entregado es la versión DEL ASISTENTE: así las
          // piezas que se le devolvieron a la persona siguen contando como
          // editadas a mano, y en el próximo turno se le vuelven a proteger.
          // Una edición rechazada no entregó nada.
          if (!data.rejected_draft) {
            this.lastDelivered = data.manual_conflict
              ? data.manual_conflict.assistant_draft
              : data.draft;
          }
          this.validation = data.validation;
          // Al editar el modelo manda la propuesta en null: pisarla borraba el
          // nombre ya elegido (el "Soporte v2" de crear otra versión).
          if (data.proposal) this.proposal = data.proposal;
        }
        this.manualConflict = data.manual_conflict || null;
        if (Array.isArray(data.versions)) this.versions = data.versions;
        // Un aviso que pide decidir no puede quedar tapado por la lista de versiones.
        if (data.manual_conflict || data.rejected_draft)
          this.draftTab = 'editor';
        if (typeof data.building === 'boolean') this.isBuilding = data.building;
        this.rejected = data.rejected_draft
          ? { draft: data.rejected_draft, validation: data.rejected_validation }
          : null;
      } catch (error) {
        const reason =
          error?.response?.data?.error === 'no_api_key'
            ? this.$t('TRACKING_ASSISTANT_VIEW.ERROR_NO_KEY')
            : this.$t('TRACKING_ASSISTANT_VIEW.ERROR_TURN');
        this.messages.push({ role: 'assistant', content: reason });
      } finally {
        this.stopProgress();
        this.isThinking = false;
      }
    },
    // F3 del encargo (docs/importar_prompt_md_plan.md): el encargo ya resuelto con lo
    // que se contestó en el modal va a la redacción de una sola vez, en un agente
    // nuevo. La Definición sale de la ficha (objetivo, y los datos del negocio como
    // Contexto si caben): el modelo de una sola vez no la propone.
    //
    // Después, la cobertura (BriefCoverage): la redacción de una sola vez sigue su
    // molde y suelta reglas; lo que falte del encargo se agrega en su sección.
    //
    // El chat se abre al terminar: desde ahí se refina conversando (pedido del
    // usuario, 23/09/2026). El mensaje del encargo es largo y escrito para el modelo:
    // en pantalla se ve corto (`display`), y al modelo le sigue llegando entero.
    //
    // Si las instrucciones salieron de la conversación, la conversación sigue: no se
    // arranca en limpio (se perdería lo hablado).
    async writeFromBrief({ message, proposal, briefId, filename }) {
      this.batteryBriefId = briefId || null;
      if (!this.chatBrief) this.startFresh();
      this.chatBrief = null;
      this.isWritingBrief = true;
      await this.sendMessage(message, { oneShot: true });
      // Reemplazado entero: en Vue 2 una propiedad nueva no es reactiva.
      const donde = this.messages.findIndex(
        m => m.role === 'user' && m.content === message
      );
      if (donde >= 0) {
        this.messages.splice(donde, 1, {
          ...this.messages[donde],
          display: this.$t('TRACKING_ASSISTANT_VIEW.BRIEF_CHAT_USER', {
            name: filename,
          }),
        });
      }
      if (!this.draft.trim()) {
        this.isWritingBrief = false;
        useAlert(this.$t('TRACKING_ASSISTANT_VIEW.BRIEF_WRITE_ERROR'));
        return;
      }
      const agregados = await this.coverFromBrief(briefId);
      this.isWritingBrief = false;
      this.inviteToRefine(agregados);
      const definicion = Object.fromEntries(
        Object.entries(proposal || {}).filter(([, valor]) => valor)
      );
      this.proposal = { ...(this.proposal || {}), ...definicion };
      this.showBriefModal = false;
      this.leftPanel = 'chat';
    },
    // Revisar una conversación real (pedido del usuario, 24/09/2026): qué respuestas
    // del agente estuvieron mal, por qué y qué cambiar. El resultado entra al hilo
    // como mensaje del Asistente; si se pide corregir, el editor lo tiene a la vista.
    // Sin Entrenamiento abierto, se abre el del agente que atendió: corregir es el
    // paso siguiente y el chat solo edita lo que está abierto.
    async reviewConversation(content) {
      this.messages.push({ role: 'user', content });
      this.interviewOptions = null;
      this.isThinking = true;
      const turnId = this.startProgress();
      try {
        await AssistantAPI.reviewConversation(content, turnId, {
          draft: this.draft.trim() ? this.draft : null,
          inboxId: this.inboxId,
        });
        const result = await this.waitTurnResult(() =>
          AssistantAPI.getConversationReview(turnId)
        );
        const aviso = this.openReviewedAgent(result.agent);
        this.messages.push({
          role: 'assistant',
          content: [reviewMessage(result, (k, a) => this.$t(k, a)), aviso]
            .filter(Boolean)
            .join('\n\n'),
        });
        if (this.draft.trim() && hasTrainingFixes(result)) {
          this.interviewOptions = [
            {
              question: this.$t('TRACKING_ASSISTANT_VIEW.REVIEW_NEXT'),
              choices: [this.$t('TRACKING_ASSISTANT_VIEW.REVIEW_APPLY')],
            },
          ];
        }
      } catch (error) {
        this.messages.push({
          role: 'assistant',
          content: this.reviewError(error?.response?.data?.error),
        });
      } finally {
        this.stopProgress();
        this.isThinking = false;
      }
    },
    reviewError(code) {
      if (code === 'no_api_key')
        return this.$t('TRACKING_ASSISTANT_VIEW.ERROR_NO_KEY');
      const conocidos = ['not_found', 'no_conversation', 'no_messages'];
      return this.$t(
        conocidos.includes(code)
          ? `TRACKING_ASSISTANT_VIEW.REVIEW_ERROR_${code.toUpperCase()}`
          : 'TRACKING_ASSISTANT_VIEW.REVIEW_ERROR'
      );
    },
    // Devuelve el aviso para el mensaje, o ''.
    openReviewedAgent(agent) {
      if (!agent?.template_id) return '';
      if (!this.draft.trim()) {
        const template = this.templates.find(t => t.id === agent.template_id);
        if (!template) return '';
        this.loadTemplate(template);
        return this.$t('TRACKING_ASSISTANT_VIEW.REVIEW_OPENED_AGENT', {
          name: template.name,
        });
      }
      if (this.editingTemplate?.id === agent.template_id) return '';
      return this.$t('TRACKING_ASSISTANT_VIEW.REVIEW_OTHER_AGENT', {
        name: agent.name,
      });
    },
    // Conocimiento sugerido: creadas las respuestas predefinidas del agente, las rutas
    // del Entrenamiento abierto que buscaban en TODAS pasan a buscar en su grupo.
    applyCannedGroup(group) {
      const nuevo = withCannedGroup(this.draft, group);
      if (nuevo === this.draft) {
        useAlert(this.$t('TRACKING_ASSISTANT_VIEW.KNOWLEDGE_APPLY_NONE'));
        return;
      }
      this.draft = nuevo;
      this.onDraftInput();
      useAlert(
        this.$t('TRACKING_ASSISTANT_VIEW.KNOWLEDGE_APPLY_DONE', { group })
      );
    },
    // Un turno de la conversación que arma un agente desde cero (DraftingChat).
    async sendDraftingMessage(content) {
      this.messages.push({ role: 'user', content });
      this.isThinking = true;
      try {
        const { data } = await AssistantAPI.draftingChat(
          this.messages,
          this.instructions,
          { sessionId: this.sessionId }
        );
        this.sessionId = data.session_id || this.sessionId;
        if (data.session) this.sessionMeta = data.session;
        this.messages.push({ role: 'assistant', content: data.reply });
        if (data.instructions) this.instructions = data.instructions;
      } catch (error) {
        const reason =
          error?.response?.data?.error === 'no_api_key'
            ? this.$t('TRACKING_ASSISTANT_VIEW.ERROR_NO_KEY')
            : this.$t('TRACKING_ASSISTANT_VIEW.ERROR_TURN');
        this.messages.push({ role: 'assistant', content: reason });
      } finally {
        this.isThinking = false;
      }
    },
    // «Crear el Entrenamiento» desde las instrucciones de la conversación: entran
    // como un .md subido y siguen en el modal de siempre (Esto entendí / Me falta saber).
    async createFromInstructions() {
      if (!this.instructions.trim() || this.isSendingInstructions) return;
      this.isSendingInstructions = true;
      try {
        const { data } = await AssistantAPI.briefFromInstructions(
          this.instructions,
          instructionsFilename(this.instructions),
          { sessionId: this.sessionId }
        );
        this.chatBrief = data;
        this.showBriefModal = true;
      } catch (error) {
        useAlert(this.$t('TRACKING_ASSISTANT_VIEW.BRIEF_ERROR'));
      } finally {
        this.isSendingInstructions = false;
      }
    },
    downloadInstructions() {
      downloadMarkdown(
        this.instructions,
        instructionsFilename(this.instructions)
      );
    },
    // Al mensaje del Asistente se le suma lo que agregó la cobertura y la invitación
    // a seguir: el chat queda abierto para eso.
    inviteToRefine(agregados) {
      const ultimo = this.messages[this.messages.length - 1];
      if (!ultimo || ultimo.role !== 'assistant') return;
      const extras = [];
      if (agregados) {
        extras.push(
          this.$t('TRACKING_ASSISTANT_VIEW.BRIEF_COVERED', { count: agregados })
        );
      }
      extras.push(this.$t('TRACKING_ASSISTANT_VIEW.BRIEF_CHAT_INVITE'));
      ultimo.content = [ultimo.content, ...extras].filter(Boolean).join('\n\n');
    },
    // Si la cobertura falla, queda lo que escribió el Asistente: no es motivo para
    // tirar un Entrenamiento que ya está en pantalla.
    // Devuelve cuántos puntos agregó.
    async coverFromBrief(briefId) {
      try {
        const { data } = await AssistantAPI.coverBrief(briefId, this.draft);
        if (!data.draft || data.draft === this.draft) return 0;
        this.draft = data.draft;
        this.lastDelivered = data.draft;
        this.validateDraft();
        return (data.added || []).length;
      } catch (error) {
        // Queda lo escrito por el Asistente.
        return 0;
      }
    },
    // Fase D: mientras el turno corre, se consulta en qué etapa está. El id lo
    // genera la pantalla porque la sesión puede no existir todavía (primer turno).
    startProgress(
      onStage = data => {
        this.turnStage = data;
      }
    ) {
      const turnId = `t${Date.now().toString(36)}${Math.random()
        .toString(36)
        .slice(2, 10)}`;
      this.turnStage = null;
      clearInterval(this.progressTimer);
      this.progressTimer = setInterval(async () => {
        try {
          const { data } = await AssistantAPI.getProgress(turnId);
          if (data && data.stage) onStage(data);
        } catch (error) {
          // Sin progreso se ve la espera de siempre: no es motivo para avisar nada.
        }
      }, PROGRESS_POLL_MS);
      return turnId;
    },
    stopProgress() {
      clearInterval(this.progressTimer);
      this.progressTimer = null;
      this.turnStage = null;
    },
    // Fase E: optimizar. El resultado se anota contra la versión del borrador:
    // si después se edita, aplicar pisaría esos cambios y el modal lo impide.
    async runOptimize() {
      if (this.isOptimizing || !this.draft.trim()) return;
      this.isOptimizing = true;
      this.optimizeError = '';
      const version = this.draftVersion;
      const turnId = this.startProgress();
      try {
        await AssistantAPI.optimize(this.draft, turnId, this.inboxId);
        const data = await this.waitOptimizeResult(turnId);
        this.optimizeResult = { ...data, version };
      } catch (error) {
        this.optimizeError = this.$t('TRACKING_ASSISTANT_VIEW.OPTIMIZE_ERROR');
      } finally {
        this.stopProgress();
        this.isOptimizing = false;
      }
    },
    // El backend responde 202 mientras trabaja, 200 con el resultado y 422 si falló
    // (axios lo lanza como error). Se rinde a los 5 minutos.
    async waitOptimizeResult(turnId) {
      return this.waitTurnResult(() => AssistantAPI.getOptimizeResult(turnId));
    },
    // Lo mismo para cualquier turno que corre en segundo plano (optimizar, revisar
    // una conversación): `fetch` pide el resultado.
    async waitTurnResult(fetch) {
      const deadline = Date.now() + OPTIMIZE_MAX_WAIT_MS;
      while (Date.now() < deadline) {
        // eslint-disable-next-line no-await-in-loop
        await new Promise(resolve => {
          setTimeout(resolve, PROGRESS_POLL_MS);
        });
        // eslint-disable-next-line no-await-in-loop
        const { status, data } = await fetch();
        if (status === 200) return data;
      }
      throw new Error('turn timeout');
    },
    applyOptimization(texto) {
      if (!texto) return;
      this.draft = texto;
      this.manualConflict = null;
      this.rejected = null;
      this.optimizeResult = null;
      this.showOptimizeModal = false;
      this.validateDraft();
      useAlert(this.$t('TRACKING_ASSISTANT_VIEW.OPTIMIZE_APPLIED'));
    },
    // Cambiar de canal cambia el modelo que clasifica: lo probado con el canal
    // anterior deja de valer, y el inventario se vuelve a pedir para ese canal.
    setInbox(id) {
      const nuevo = id ? Number(id) : null;
      if (nuevo === this.inboxId) return;
      this.inboxId = nuevo;
      this.suggestedTests = null;
      this.optimizeResult = null;
      try {
        if (nuevo)
          window.localStorage.setItem(INBOX_STORAGE_KEY, String(nuevo));
        else window.localStorage.removeItem(INBOX_STORAGE_KEY);
      } catch (error) {
        // Sin almacenamiento se pierde solo la comodidad de recordarlo.
      }
      this.fetchInventory();
    },
    // Separa en bloques el borrador que haya quedado en pantalla. Se llama en cada
    // carga —conversación, agente, empezar de cero— porque la columna de Secciones
    // está siempre a la vista y tiene que decir lo mismo que el texto.
    reloadTrainingSections() {
      return this.loadTrainingFromText(this.draft);
    },
    // El Objetivo y el Contexto del árbol. No son parte del Entrenamiento: viajan al
    // Agente IA cuando se guarda (el modal de guardar los toma de acá).
    updateDefinition(valores) {
      this.proposal = { ...(this.proposal || {}), ...valores };
    },
    // Lo seleccionado en el editor, para "Explicar selección".
    onDraftSelect(event) {
      const { selectionStart, selectionEnd } = event.target;
      this.draftSelection = this.draft
        .slice(selectionStart, selectionEnd)
        .trim();
    },
    explainSelection() {
      if (this.draftSelection) this.explainFragment(this.draftSelection);
    },
    // Lo usa también el editor de secciones (@explain), con la sección y su rótulo.
    async explainFragment(fragmento) {
      if (!fragmento || this.isExplaining) return;
      this.explainExcerpt = fragmento;
      this.explainResult = null;
      this.explainError = '';
      this.showExplainModal = true;
      this.isExplaining = true;
      try {
        const { data } = await AssistantAPI.explain(
          this.draft,
          this.explainExcerpt,
          this.inboxId
        );
        this.explainResult = data;
      } catch (error) {
        this.explainError = this.$t('TRACKING_ASSISTANT_VIEW.EXPLAIN_ERROR');
      } finally {
        this.isExplaining = false;
      }
    },
    // Fase E: la batería de tests sugeridos. Se anota contra qué versión del
    // borrador corrió, para avisar si después se editó.
    async runSuggestedTests() {
      if (this.isSuggesting || !this.draft.trim()) return;
      this.isSuggesting = true;
      this.suggestStage = null;
      const version = this.draftVersion;
      const turnId = this.startProgress(data => {
        this.suggestStage = data;
      });
      try {
        const { data } = await AssistantAPI.suggestedTests(
          this.draft,
          turnId,
          this.inboxId
        );
        this.suggestedTests = { ...data, version };
      } catch (error) {
        this.dryRunError =
          error?.response?.data?.error ||
          this.$t('TRACKING_ASSISTANT_VIEW.TESTS_ERROR');
      } finally {
        this.stopProgress();
        this.isSuggesting = false;
        this.suggestStage = null;
      }
    },
    // Volver a una versión anterior. Pasa a ser la base: lo que se cambie desde acá
    // es "a mano", y el próximo mensaje guarda como versión lo que había.
    restoreVersion({ number, draft }) {
      this.draft = draft;
      this.lastDelivered = draft;
      this.isBuilding = pendingCount(draft) > 0;
      this.manualConflict = null;
      this.rejected = null;
      this.draftTab = 'editor';
      this.reloadTrainingSections();
      this.validateDraft();
      useAlert(this.$t('TRACKING_ASSISTANT_VIEW.VERSION_RESTORED', { number }));
    },
    // Lo propuesto no ejecuta, pero la persona lo quiere igual —para terminar de
    // arreglarlo a mano, por ejemplo—. El comprobador sigue impidiendo guardarlo.
    useRejected() {
      if (!this.rejected) return;
      this.draft = this.rejected.draft;
      this.lastDelivered = this.rejected.draft;
      // Solo una ENTREGA puede ser rechazada: la entrevista ya había terminado.
      this.isBuilding = false;
      this.validation = this.rejected.validation;
      this.rejected = null;
    },
    // La persona prefiere lo que escribió el asistente en las piezas que había
    // editado a mano: se pierde su versión, que es justo lo que eligió.
    useAssistantVersion() {
      if (!this.manualConflict) return;
      this.draft = this.manualConflict.assistant_draft;
      this.lastDelivered = this.manualConflict.assistant_draft;
      this.manualConflict = null;
      this.validateDraft();
    },
    // Se revalida también cuando la persona edita a mano: el borrador del modelo
    // no es más confiable que el suyo, y ninguno de los dos se guarda sin pasar.
    // Pedido del usuario (25/09/2026): con el Entrenamiento VACÍO, pegar un prompt
    // pregunta si se analiza; al aceptar, el análisis arranca en el chat (y ahí mismo
    // se ofrece corregir lo que se arregla escribiendo). Con texto ya escrito, pegar
    // es editar: no se pregunta nada.
    async onDraftPaste(event) {
      if (this.draft.trim() || this.isThinking) return;
      const pegado = event.clipboardData?.getData('text') || '';
      if (pegado.trim().length < MIN_PASTE_TO_ANALYZE) return;
      // El texto entra con el evento `input`, después de este: se espera a que el
      // editor lo tenga (y onDraftInput lo marque como un agente que ya existe).
      await new Promise(resolve => {
        setTimeout(resolve, 0);
      });
      if (!this.draft.trim()) return;
      const analizar = await this.$refs.analyzePastedDialog.showConfirmation();
      if (analizar) await this.analyzeDraft();
    },
    // Análisis del Entrenamiento en pantalla, en el chat: lo que marca el comprobador,
    // la lectura del modelo y, si hay, el botón para corregir.
    async analyzeDraft() {
      if (!this.draft.trim() || this.isThinking) return;
      this.leftPanel = 'chat';
      await this.sendMessage(
        this.$t('TRACKING_ASSISTANT_VIEW.PASTE_ANALYZE_MESSAGE')
      );
    },
    onDraftInput() {
      // Un prompt pegado (o escrito) en un Asistente nuevo es un agente que ya existe,
      // no una entrevista a medias: se trata como uno cargado (loadTemplate) — cuenta
      // como entregado y no está en construcción. Sin esto, «observa y analiza el
      // prompt» contestaba preguntando los temas y si contesta o deriva (24/09/2026).
      // Solo si el Asistente todavía no entregó nada: sus borradores siguen su curso.
      if (!this.lastDelivered && this.draft.trim()) {
        this.lastDelivered = this.draft;
        this.isBuilding = pendingCount(this.draft) > 0;
      }
      clearTimeout(this.validateTimer);
      this.validateTimer = setTimeout(this.validateDraft, VALIDATE_DEBOUNCE_MS);
      clearTimeout(this.autosaveTimer);
      this.autosaveTimer = setTimeout(this.autosaveDraft, AUTOSAVE_DELAY_MS);
      // Editar no borra las pruebas: las envejece. Cada corrida guardó contra qué
      // versión se hizo, así que las anteriores quedan marcadas en vez de
      // desaparecer — y la comparación entre preguntas se conserva.
      this.draftVersion += 1;
    },
    async validateDraft() {
      if (!this.draft.trim()) {
        this.validation = null;
        this.adaptationItems = [];
        return;
      }
      this.fetchAdaptation();
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
    // proyecto@adaptar_prompts_publicados — qué le falta al texto en esta cuenta.
    // Se pide cada vez que se comprueba: el contador de la pestaña sigue al texto.
    async fetchAdaptation() {
      const texto = this.draft;
      if (!texto.trim()) return;
      this.isAdapting = true;
      try {
        const { data } = await AssistantAPI.getAdaptation(
          texto,
          this.editingTemplateId
        );
        // Una respuesta vieja (se siguió escribiendo) no pisa a la nueva.
        if (texto === this.draft) this.adaptationItems = data.items || [];
      } catch (error) {
        // Sin inventario, la pestaña se queda con lo último que supo.
      } finally {
        this.isAdapting = false;
      }
    },
    // Se volvió a esta pestaña del navegador: si faltaba algo, puede que se haya
    // creado en la otra (fuente, calendario, tipo de caso).
    onWindowFocus() {
      if (this.adaptationMissing > 0) this.onSourcesChanged();
    },
    // Lo aplicado en «Configurar» entra al editor como cualquier edición, pero queda
    // como su propia versión «Configurado», con qué se configuró.
    async onAdaptationApplied({ text, validation, items, notes }) {
      this.draft = text;
      this.validation = validation;
      this.adaptationItems = items || [];
      this.reloadTrainingSections();
      this.draftVersion += 1;
      clearTimeout(this.autosaveTimer);
      try {
        const { data } = await AssistantAPI.autosaveDraft(
          text,
          this.sessionId,
          { source: 'configured', notes }
        );
        this.lastAutosaved = text;
        this.sessionId = data.session_id || this.sessionId;
        if (data.session && !this.sessionMeta) this.sessionMeta = data.session;
        if (Array.isArray(data.versions)) this.versions = data.versions;
      } catch (error) {
        // Queda en el editor; se guarda con el próximo autoguardado o al guardar.
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
        // Lo que el comprobador no podía revisar sobre el borrador: directivas
        // que dependen de la configuración del AGENTE, que recién ahora existe.
        (data.warnings || []).forEach(warning => useAlert(warning.message));
        useAlert(this.$t('TRACKING_ASSISTANT_VIEW.PUBLISHED'));
        // feat/agentes_ia_unificado: se sigue en el mismo agente, ya publicado. La
        // conversación se cerró al guardar; lo que se edite ahora abre otra.
        await this.$store.dispatch('trackingTemplates/get');
        this.loadTemplate(
          this.templates.find(t => t.id === data.tracking_template_id)
        );
        this.$emit('saved', data.tracking_template_id);
      } catch (error) {
        const details = error?.response?.data?.details;
        this.saveError = Array.isArray(details)
          ? details.join(' · ')
          : this.$t('TRACKING_ASSISTANT_VIEW.ERROR_SAVE');
      } finally {
        this.isSaving = false;
      }
    },
  },
};
</script>

<template>
  <div class="flex flex-col flex-1 w-full h-full min-h-0 overflow-hidden">
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
        <div class="flex flex-col flex-1 min-h-0 gap-3">
          <!-- De qué conversación se trata y con qué canal se prueba. Están fuera
               de las dos columnas porque valen para toda la pantalla: el canal
               decide con qué modelo se clasifica y se contesta, y la tarjeta dice
               qué agente se está editando. Con el chat escondido, siguen acá. -->
          <!-- Una barra: a la izquierda qué se edita; a la derecha el canal (con qué
               modelos clasifica y contesta) y las acciones, con «Nuevo Agente IA» al
               final. En pantallas angostas, la derecha baja a otra línea. -->
          <div
            class="flex flex-wrap items-center justify-between gap-x-6 gap-y-3 px-4 py-3 bg-white border rounded-lg shrink-0 dark:bg-slate-800 border-slate-100 dark:border-slate-700"
          >
            <SessionCard
              class="flex-1 min-w-[16rem]"
              :session-meta="sessionMeta"
              :editing-template="editingTemplate"
              @rename="renameSession"
            />
            <div class="flex flex-wrap items-center gap-x-6 gap-y-3">
              <div class="flex flex-col gap-0.5 text-xs">
                <div class="flex items-center gap-2">
                  <label
                    for="assistant-inbox"
                    class="!m-0 text-slate-600 dark:text-slate-300"
                  >
                    {{ $t('TRACKING_ASSISTANT_VIEW.INBOX_LABEL') }}
                  </label>
                  <select
                    id="assistant-inbox"
                    class="!mb-0 !w-auto !py-1 text-xs"
                    :value="inboxId || ''"
                    @change="setInbox($event.target.value)"
                  >
                    <option value="">
                      {{ $t('TRACKING_ASSISTANT_VIEW.INBOX_NONE') }}
                    </option>
                    <option
                      v-for="inbox in inboxes"
                      :key="inbox.id"
                      :value="inbox.id"
                    >
                      {{ inbox.name }}
                    </option>
                  </select>
                </div>
                <span
                  v-if="inventory && inventory.models"
                  class="text-slate-500 dark:text-slate-400"
                  :title="$t('TRACKING_ASSISTANT_VIEW.INBOX_HINT')"
                >
                  {{
                    $t('TRACKING_ASSISTANT_VIEW.INBOX_MODELS', {
                      router: inventory.models.router,
                      conversational: inventory.models.conversational,
                    })
                  }}
                </span>
              </div>
              <div class="flex flex-wrap items-center gap-2">
                <woot-button
                  size="small"
                  variant="smooth"
                  color-scheme="secondary"
                  icon="attach"
                  @click="showBriefModal = true"
                >
                  {{ $t('TRACKING_ASSISTANT_VIEW.BRIEF_OPEN') }}
                </woot-button>
                <!-- proyecto@publicar_prompts — partir de un prompt que publicó otra
                     cuenta. Es la ÚNICA puerta para bajarlos (pedido del usuario). -->
                <woot-button
                  size="small"
                  variant="smooth"
                  color-scheme="secondary"
                  icon="globe"
                  @click="showPublishedPrompts = true"
                >
                  {{ $t('TRACKING_ASSISTANT_VIEW.GALLERY.OPEN') }}
                </woot-button>
                <!-- Un agente nuevo se empieza desde la lista («+ Nuevo agente»).
                     Aquí queda recargar los recursos de la cuenta (fuentes,
                     calendarios), que antes estaba en el encabezado. -->
                <woot-button
                  v-tooltip="$t('TRACKING_ASSISTANT_VIEW.REFRESH')"
                  size="small"
                  variant="clear"
                  color-scheme="secondary"
                  icon="arrow-clockwise"
                  :is-loading="isLoadingInventory"
                  @click="fetchInventory"
                />
              </div>
            </div>
          </div>

          <!-- proyecto@publicar_prompts (F7): el autor publicó una versión nueva del
               prompt del que salió este agente. Nunca se aplica sola. -->
          <div
            v-if="publishedUpdate"
            class="flex flex-wrap items-center justify-between gap-2 px-4 py-2 text-sm border rounded-lg shrink-0 bg-woot-25 dark:bg-woot-900/30 border-woot-100 dark:border-woot-800 text-slate-700 dark:text-slate-200"
          >
            <span>{{ publishedUpdateText }}</span>
            <woot-button
              size="small"
              variant="smooth"
              icon="arrow-clockwise"
              @click="showPublishedUpdate = true"
            >
              {{ $t('TRACKING_ASSISTANT_VIEW.GALLERY.UPDATE_VIEW') }}
            </woot-button>
          </div>

          <div class="grid flex-1 min-h-0 gap-4 md:grid-cols-2">
            <!-- La columna izquierda: la Estructura del Agente o la conversación,
                 una a la vez, con el selector arriba. -->
            <div class="flex flex-col min-h-0 gap-2">
              <div
                v-if="showChat"
                class="flex items-center gap-1 shrink-0"
                role="tablist"
              >
                <woot-button
                  v-for="panel in leftPanels"
                  :key="panel.id"
                  size="small"
                  :variant="leftPanel === panel.id ? 'smooth' : 'clear'"
                  :color-scheme="
                    leftPanel === panel.id ? 'primary' : 'secondary'
                  "
                  :icon="panel.icon"
                  role="tab"
                  :aria-selected="leftPanel === panel.id"
                  @click="leftPanel = panel.id"
                >
                  {{ panel.label }}
                </woot-button>
              </div>
              <!-- v-show y no v-if: la conversación se esconde, no se desmonta. Con
               v-if se perdería el scroll del hilo y lo tecleado sin enviar cada
               vez que se cambia a la Estructura y se vuelve. -->
              <section
                v-show="showChat && leftPanel === 'chat'"
                class="flex-1 p-4 bg-white rounded-lg dark:bg-slate-800 border border-slate-100 dark:border-slate-700 flex flex-col min-h-0"
              >
                <InterviewPanel
                  :messages="messages"
                  :is-thinking="isThinking"
                  :options="interviewOptions"
                  :is-editing="Boolean(draft.trim())"
                  :stage="turnStage"
                  @send="sendMessage"
                />
              </section>

              <!-- Las instrucciones iniciales que se llenan conversando. -->
              <section
                v-if="showChat"
                v-show="leftPanel === 'instructions'"
                class="flex flex-col flex-1 min-h-0 p-4 bg-white rounded-lg dark:bg-slate-800 border border-slate-100 dark:border-slate-700"
              >
                <InstructionsPanel
                  v-model="instructions"
                  :busy="isSendingInstructions || isWritingBrief"
                  @create="createFromInstructions"
                  @download="downloadInstructions"
                />
              </section>

              <!-- SECCIONES · el formulario, a la izquierda. Es donde se arma el
                 Entrenamiento: cada cambio vuelve a armar el texto en el backend y
                 se ve al instante en la columna de la derecha. -->
              <section
                v-show="!showChat || leftPanel === 'structure'"
                class="flex flex-col flex-1 min-h-0 p-4 bg-white rounded-lg dark:bg-slate-800 border border-slate-100 dark:border-slate-700"
              >
                <h3
                  v-if="!showChat"
                  class="mb-2 text-sm font-semibold shrink-0 text-slate-800 dark:text-slate-100"
                >
                  {{ $t('TRACKING_ASSISTANT_VIEW.TREE_TITLE') }}
                </h3>
                <AgentStructure
                  class="flex-1 min-h-0"
                  :value="trainingStructure"
                  :definition="proposal"
                  :titles="sectionTitles"
                  :route-options="routeOptions"
                  :issues="nodeIssues"
                  :inbox-id="inboxId"
                  :can-explain="canExplainTraining"
                  @input="onSectionsInput"
                  @updateDefinition="updateDefinition"
                  @explain="explainFragment"
                />
              </section>
            </div>

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
                :dry-run="lastDryRun"
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
                    <button
                      class="mr-3 pb-0.5 border-b-2"
                      :class="
                        draftTab === 'editor'
                          ? 'border-woot-500'
                          : 'border-transparent font-normal text-slate-500 dark:text-slate-400'
                      "
                      @click="draftTab = 'editor'"
                    >
                      {{ $t('TRACKING_ASSISTANT_VIEW.DRAFT_TAB_EDITOR') }}
                    </button>
                    <!-- proyecto@adaptar_prompts_publicados: lo que usa de la cuenta.
                         Siempre a la vista: aunque no falte nada, ahí se cambia una
                         fuente por otra y la IA busca datos de otro negocio. -->
                    <button
                      class="mr-3 pb-0.5 border-b-2"
                      :class="
                        draftTab === 'configure'
                          ? 'border-woot-500'
                          : 'border-transparent font-normal text-slate-500 dark:text-slate-400'
                      "
                      @click="draftTab = 'configure'"
                    >
                      {{ $t('TRACKING_ASSISTANT_VIEW.DRAFT_TAB_CONFIGURE') }}
                      <span
                        v-if="adaptationMissing"
                        class="font-normal text-amber-700 dark:text-amber-400"
                      >
                        {{
                          $t('TRACKING_ASSISTANT_VIEW.DRAFT_TAB_COUNT', {
                            count: adaptationMissing,
                          })
                        }}
                      </span>
                    </button>
                    <button
                      v-if="showHistoryTabs"
                      class="pb-0.5 border-b-2"
                      :class="
                        draftTab === 'versions'
                          ? 'border-woot-500'
                          : 'border-transparent font-normal text-slate-500 dark:text-slate-400'
                      "
                      @click="draftTab = 'versions'"
                    >
                      {{ $t('TRACKING_ASSISTANT_VIEW.DRAFT_TAB_VERSIONS') }}
                      <span v-if="versions.length" class="font-normal">
                        {{
                          $t('TRACKING_ASSISTANT_VIEW.DRAFT_TAB_COUNT', {
                            count: versions.length,
                          })
                        }}
                      </span>
                    </button>
                    <button
                      v-if="showHistoryTabs"
                      class="ml-3 pb-0.5 border-b-2"
                      :class="
                        draftTab === 'log'
                          ? 'border-woot-500'
                          : 'border-transparent font-normal text-slate-500 dark:text-slate-400'
                      "
                      @click="draftTab = 'log'"
                    >
                      {{ $t('TRACKING_ASSISTANT_VIEW.DRAFT_TAB_LOG') }}
                    </button>
                    <span
                      v-if="hasManualEdits && draft.trim()"
                      class="ml-2 px-1.5 py-0.5 text-xs font-normal rounded bg-slate-100 text-slate-600 dark:bg-slate-700 dark:text-slate-300"
                      :title="$t('TRACKING_ASSISTANT_VIEW.MANUAL_BADGE_HINT')"
                    >
                      {{ $t('TRACKING_ASSISTANT_VIEW.MANUAL_BADGE') }}
                    </span>
                  </h3>
                  <!-- Fase E: explicar lo seleccionado. Aparece solo con algo
                     seleccionado en el editor: sin selección no hay qué explicar. -->
                  <woot-button
                    v-if="draftTab === 'editor' && draftSelection"
                    variant="clear"
                    size="tiny"
                    color-scheme="secondary"
                    icon="info"
                    @click="explainSelection"
                  >
                    {{ $t('TRACKING_ASSISTANT_VIEW.EXPLAIN_CTA') }}
                  </woot-button>
                  <!-- El resumen del comprobador: revalida en cada tecla y es el
                     botón que abre el informe. El detalle ya no ocupa el 40% del
                     alto de la columna: ese espacio es del texto. -->
                  <button
                    type="button"
                    class="mr-2"
                    :title="$t('TRACKING_ASSISTANT_VIEW.REPORT_TITLE')"
                    @click="showReportModal = true"
                  >
                    <ValidationBadge
                      :validation="validation"
                      :is-checking="isChecking"
                      :pending-count="draftPendingCount"
                    />
                  </button>
                </div>
                <ChangeLog
                  v-if="draftTab === 'log'"
                  :versions="versions"
                  :title="(sessionMeta && sessionMeta.title) || ''"
                />
                <ConfigureTab
                  v-else-if="draftTab === 'configure'"
                  :items="adaptationItems"
                  :draft="draft"
                  :template-id="editingTemplateId"
                  :loading="isAdapting"
                  @applied="onAdaptationApplied"
                />
                <VersionsPanel
                  v-else-if="draftTab === 'versions'"
                  :versions="versions"
                  :session-id="sessionId"
                  :current-draft="draft"
                  @restore="restoreVersion"
                />
                <template v-else>
                  <ManualConflictNotice
                    v-if="manualConflict"
                    :conflict="manualConflict"
                    @keep="manualConflict = null"
                    @useAssistant="useAssistantVersion"
                  />
                  <!-- Lo propuesto que no se aplicó. Arriba del texto y no en un
                     modal: hay que poder leer el Entrenamiento conservado mientras
                     se decide. -->
                  <div
                    v-if="rejected"
                    class="flex flex-col gap-2 p-3 mb-2 text-xs border rounded shrink-0 border-amber-300 bg-amber-50 text-amber-900 dark:bg-amber-900/30 dark:text-amber-800"
                  >
                    <p class="!m-0 font-semibold">
                      {{ $t('TRACKING_ASSISTANT_VIEW.REJECTED_TITLE') }}
                    </p>
                    <p class="!m-0">
                      {{
                        $t('TRACKING_ASSISTANT_VIEW.REJECTED_HINT', {
                          count: rejectedBlockingCount,
                        })
                      }}
                    </p>
                    <div class="flex gap-2">
                      <woot-button
                        size="tiny"
                        variant="smooth"
                        color-scheme="warning"
                        @click="useRejected"
                      >
                        {{ $t('TRACKING_ASSISTANT_VIEW.REJECTED_USE') }}
                      </woot-button>
                      <woot-button
                        size="tiny"
                        variant="clear"
                        color-scheme="secondary"
                        @click="rejected = null"
                      >
                        {{ $t('TRACKING_ASSISTANT_VIEW.REJECTED_DISCARD') }}
                      </woot-button>
                    </div>
                  </div>
                  <!-- resize-none: el alto lo decide el contenedor, no el navegador;
                     arrastrarlo a mano volvería a empujar todo lo de abajo.
                     readonly mientras el asistente trabaja: trabaja sobre el texto
                     que se le mandó, y lo que se escribiera en esos segundos se
                     perdería al llegar la respuesta. -->
                  <!-- Las líneas con hallazgos se pintan DETRÁS del texto
                       (DraftLineMarks): rojo lo que no se ejecuta, ámbar lo que
                       funciona mal. El textarea va transparente encima. -->
                  <div
                    class="relative flex flex-1 min-h-0 bg-white rounded-md dark:bg-slate-900"
                  >
                    <DraftLineMarks
                      :text="draft"
                      :marks="draftLineMarks"
                      :messages="draftLineMessages"
                      :target="draftEditorEl"
                    />
                    <textarea
                      ref="draftEditor"
                      v-model="draft"
                      class="relative flex-1 min-h-0 w-full h-full font-mono text-xs resize-none !mb-0 !bg-transparent focus:!bg-transparent"
                      :placeholder="
                        $t('TRACKING_ASSISTANT_VIEW.DRAFT_PLACEHOLDER')
                      "
                      :readonly="isThinking"
                      @select="onDraftSelect"
                      @keyup="onDraftSelect"
                      @mouseup="onDraftSelect"
                      @input="onDraftInput"
                      @paste="onDraftPaste"
                    />
                  </div>
                </template>
              </div>
            </section>
          </div>
        </div>

        <!-- GUARDAR — vive fuera de los paneles porque es la salida de la
             pestaña Asistente, no de uno de sus bloques. Queda apagado mientras
             el comprobador encuentre algo bloqueante: guardar un agente que no
             ejecuta nada es exactamente el problema que este módulo vino a
             arreglar. -->
        <div class="flex justify-end gap-2 pt-4 shrink-0">
          <!-- Probar va ANTES de guardar, y en ese orden se lee: el comprobador
               dice si se ejecuta, esto dice si rutea bien, y recién después se
               guarda. -->
          <!-- Analizar: lo mismo que aceptar el modal al pegar, para quien dijo
               «solo pegarlo» o quiere volver a revisar después de editar. -->
          <woot-button
            variant="clear"
            color-scheme="secondary"
            :is-disabled="!draft.trim() || isThinking"
            @click="analyzeDraft"
          >
            {{ $t('TRACKING_ASSISTANT_VIEW.ANALYZE_CTA') }}
          </woot-button>
          <woot-button
            variant="clear"
            color-scheme="secondary"
            :is-disabled="!draft.trim()"
            @click="showDryRunModal = true"
          >
            {{ $t('TRACKING_ASSISTANT_VIEW.DRY_RUN_TITLE') }}
          </woot-button>
          <woot-button
            v-if="editingTemplate"
            variant="clear"
            color-scheme="secondary"
            @click="showTestBattery = true"
          >
            {{ $t('TRACKING_ASSISTANT_VIEW.BATTERY_CTA') }}
          </woot-button>
          <woot-button
            variant="clear"
            color-scheme="secondary"
            :is-disabled="!draft.trim()"
            @click="showOptimizeModal = true"
          >
            {{ $t('TRACKING_ASSISTANT_VIEW.OPTIMIZE_CTA') }}
          </woot-button>
          <woot-button :is-disabled="!canSave" @click="showSaveModal = true">
            {{ saveLabel }}
          </woot-button>
        </div>
      </template>
    </div>

    <OptimizeModal
      :show="showOptimizeModal"
      :result="optimizeResult"
      :is-running="isOptimizing"
      :error="optimizeError"
      :draft="draft"
      :draft-version="draftVersion"
      @close="showOptimizeModal = false"
      @run="runOptimize"
      @apply="applyOptimization"
    />
    <woot-confirm-modal
      ref="analyzePastedDialog"
      :title="$t('TRACKING_ASSISTANT_VIEW.PASTE_ANALYZE_TITLE')"
      :description="$t('TRACKING_ASSISTANT_VIEW.PASTE_ANALYZE_DESCRIPTION')"
      :confirm-label="$t('TRACKING_ASSISTANT_VIEW.PASTE_ANALYZE_YES')"
      :cancel-label="$t('TRACKING_ASSISTANT_VIEW.PASTE_ANALYZE_NO')"
    />
    <PublishedPromptsModal
      :show="showPublishedPrompts"
      @close="showPublishedPrompts = false"
      @installed="onPromptInstalled"
    />
    <PublishedUpdateModal
      :show="showPublishedUpdate"
      :update="publishedUpdate"
      :template-id="editingTemplate ? editingTemplate.id : null"
      :draft="draft"
      @close="showPublishedUpdate = false"
      @load="loadPublishedVersion"
      @seen="$store.dispatch('trackingTemplates/get')"
    />
    <BriefModal
      :show="showBriefModal"
      :initial-brief="chatBrief"
      :session-id="sessionId"
      :labels="(inventory && inventory.labels) || []"
      :writing="isWritingBrief"
      :has-draft="Boolean(draft.trim())"
      @close="showBriefModal = false"
      @write="writeFromBrief"
      @applyGroup="applyCannedGroup"
    />
    <ReportModal
      :show="showReportModal"
      :validation="validation"
      :is-checking="isChecking"
      :pending-count="draftPendingCount"
      :unsupported="unsupported"
      @close="showReportModal = false"
      @gotoRoute="goToRoute"
      @gotoLine="goToLine"
    />
    <ExplainModal
      :show="showExplainModal"
      :excerpt="explainExcerpt"
      :result="explainResult"
      :is-running="isExplaining"
      :error="explainError"
      @close="showExplainModal = false"
    />
    <TestBatteryModal
      v-if="editingTemplate"
      :show="showTestBattery"
      :template-id="editingTemplate.id"
      :template-name="editingTemplate.name"
      :brief-id="batteryBriefId"
      @close="showTestBattery = false"
    />
    <DryRunModal
      :show="showDryRunModal"
      :draft="draft"
      :history="dryRunHistory"
      :draft-version="draftVersion"
      :is-running="isDryRunning"
      :error="dryRunError"
      :suggested="suggestedTests"
      :is-suggesting="isSuggesting"
      :suggest-stage="suggestStage"
      @close="showDryRunModal = false"
      @run="runDryRun"
      @suggest="runSuggestedTests"
    />

    <SaveModal
      :show="showSaveModal"
      :templates="templates"
      :inboxes="inboxes"
      :default-inbox-id="inboxId"
      :is-saving="isSaving"
      :proposal="proposal"
      :editing-template="editingTemplate"
      :error="saveError"
      :needs-calendar="usesCalendar"
      :calendar-integrations="calendarIntegrations"
      @close="showSaveModal = false"
      @save="saveDraft"
    />
  </div>
</template>
