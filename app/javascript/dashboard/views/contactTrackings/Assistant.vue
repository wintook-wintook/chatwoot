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
import TableFooter from 'dashboard/components/widgets/TableFooter.vue';
import { sortRows, nextOrder, NUMBER, DATE, TEXT } from './assistant/tableSort';
import { findRouteLine, lineRange } from './assistant/draftNavigation';
import { pendingCount } from './assistant/pendingMarkers';
import InterviewPanel from './assistant/InterviewPanel.vue';
import SessionCard from './assistant/SessionCard.vue';
import SortableTh from './assistant/SortableTh.vue';
import ProgressStrip from './assistant/ProgressStrip.vue';
import CopyChip from './assistant/CopyChip.vue';
import ValidationBadge from './assistant/ValidationBadge.vue';
import ReportModal from './assistant/ReportModal.vue';
import BriefModal from './assistant/BriefModal.vue';
import ManualConflictNotice from './assistant/ManualConflictNotice.vue';
import VersionsPanel from './assistant/VersionsPanel.vue';
// La Estructura del Agente: el árbol con sus modales (docs/estructura_agente_arbol_plan.md).
import AgentStructure from './assistant/AgentStructure.vue';
import trainingSectionsMixin from './assistant/trainingSectionsMixin';
import OptimizeModal from './assistant/OptimizeModal.vue';
import ExplainModal from './assistant/ExplainModal.vue';
import DryRunModal from './assistant/DryRunModal.vue';
import SaveModal from './assistant/SaveModal.vue';

// El teclado va más rápido que un request: se espera a que la persona pare.
const VALIDATE_DEBOUNCE_MS = 400;
// Cada cuánto se pregunta en qué etapa está el turno. Las etapas duran de 1 a 58 s:
// más seguido no muestra nada nuevo.
const PROGRESS_POLL_MS = 1500;
const OPTIMIZE_MAX_WAIT_MS = 5 * 60 * 1000;
const INBOX_STORAGE_KEY = 'tracking_assistant_inbox_id';

// El chat del Asistente, escondido a pedido del usuario (17/09/2026): el
// Entrenamiento se arma en el formulario de secciones, que se lleva todo el ancho.
// No se borra nada — la entrevista sigue entera detrás de esta bandera, y volver a
// mostrarla es ponerla en true.
const SHOW_CHAT = false;

// La pestaña Conversaciones, escondida a pedido del usuario (18/09/2026): lista las
// conversaciones del chat, y el chat no se usa. La tabla y el retomar siguen enteros
// detrás de esta bandera; empezar de cero está en el botón "Nuevo Agente IA".
const SHOW_SESSIONS_TAB = false;

// El backend devuelve hasta 50 conversaciones (TrackingAssistantSession::LIST_LIMIT),
// así que el paginado es sobre lo que ya está en memoria: no hay una segunda página
// que pedir. Diez por pantalla entran sin scroll en una laptop.
const SESSIONS_PER_PAGE = 10;
// La auditoría recorre TODOS los agentes de la cuenta —28 en esta— así que sin
// paginar la pestaña era un scroll largo sin forma de comparar dos.
const AGENTS_PER_PAGE = 10;

// El tipo de cada columna ordenable, por tabla. Esta declaración ES la lista de
// lo ordenable: una columna sin declarar no se ordena (ver tableSort.js).
const SESSION_COLUMNS = {
  id: NUMBER,
  status: TEXT,
  title: TEXT,
  creator: TEXT,
  template_name: TEXT,
  routes: NUMBER,
  created_at: DATE,
  updated_at: DATE,
};
const AGENT_COLUMNS = {
  status: TEXT,
  name: TEXT,
  routes: NUMBER,
  defects: NUMBER,
  degrading: NUMBER,
};

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
    CopyChip,
    TableFooter,
    EmptyState,
    Spinner,
    InterviewPanel,
    SessionCard,
    SortableTh,
    ProgressStrip,
    ValidationBadge,
    ReportModal,
    BriefModal,
    ManualConflictNotice,
    VersionsPanel,
    AgentStructure,
    OptimizeModal,
    ExplainModal,
    DryRunModal,
    SaveModal,
  },
  mixins: [trainingSectionsMixin],
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
      activeTab: 0,
      audit: [],
      isAuditing: false,
      sessions: [],
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
      // Modo ancho: esconde la conversación y deja el Entrenamiento a todo el
      // ancho. Para los 6 agentes de la cuenta que pasan de 370 líneas.
      isWideEditor: !SHOW_CHAT,
      sessionsPage: 1,
      SESSIONS_PER_PAGE,
      // El orden arranca donde lo dejó el backend (recent_first): así el primer
      // pintado y el que se ve después de tocar un encabezado son coherentes.
      sessionsSort: { key: 'updated_at', order: 'desc' },
      agentsPage: 1,
      AGENTS_PER_PAGE,
      // Los roto primero: es la pestaña a la que se entra para arreglar algo.
      agentsSort: { key: 'defects', order: 'desc' },
    };
  },
  computed: {
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
    showSessionsTab() {
      return SHOW_SESSIONS_TAB;
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
    // Los encabezados salen de una lista y no repetidos en el markup: trece
    // columnas ordenables entre las dos tablas es donde a una se le olvida el
    // @sort y queda muerta sin que nada falle.
    sessionHeaders() {
      return [
        { key: 'id', label: 'TRACKING_ASSISTANT_VIEW.SESSIONS_COL_ID' },
        { key: 'status', label: 'TRACKING_ASSISTANT_VIEW.SESSIONS_COL_STATUS' },
        { key: 'title', label: 'TRACKING_ASSISTANT_VIEW.SESSIONS_COL_TITLE' },
        {
          key: 'creator',
          label: 'TRACKING_ASSISTANT_VIEW.SESSIONS_COL_CREATOR',
        },
        {
          key: 'template_name',
          label: 'TRACKING_ASSISTANT_VIEW.SESSIONS_COL_TEMPLATE',
        },
        { key: 'routes', label: 'TRACKING_ASSISTANT_VIEW.SESSIONS_COL_ROUTES' },
        {
          key: 'created_at',
          label: 'TRACKING_ASSISTANT_VIEW.SESSIONS_COL_CREATED',
        },
        {
          key: 'updated_at',
          label: 'TRACKING_ASSISTANT_VIEW.SESSIONS_COL_UPDATED',
        },
      ];
    },
    agentHeaders() {
      return [
        { key: 'status', label: 'TRACKING_ASSISTANT_VIEW.AGENTS_COL_STATUS' },
        { key: 'name', label: 'TRACKING_ASSISTANT_VIEW.AGENTS_COL_NAME' },
        {
          key: 'routes',
          label: 'TRACKING_ASSISTANT_VIEW.AGENTS_COL_ROUTES',
          right: true,
        },
        {
          key: 'defects',
          label: 'TRACKING_ASSISTANT_VIEW.AGENTS_COL_DEFECTS',
          right: true,
        },
        {
          key: 'degrading',
          label: 'TRACKING_ASSISTANT_VIEW.AGENTS_COL_DEGRADING',
          right: true,
        },
        {
          key: 'headline',
          label: 'TRACKING_ASSISTANT_VIEW.AGENTS_COL_HEADLINE',
        },
      ];
    },
    // El último resultado, para la tira de hitos: "Probado" se apaga cuando el
    // borrador cambió después de la prueba.
    lastDryRun() {
      const ultima = this.dryRunHistory[this.dryRunHistory.length - 1];
      return ultima && ultima.version === this.draftVersion
        ? ultima.result
        : null;
    },
    sortedSessions() {
      return sortRows(this.sessions, this.sessionsSort, SESSION_COLUMNS);
    },
    pagedSessions() {
      const start = (this.sessionsPage - 1) * SESSIONS_PER_PAGE;
      return this.sortedSessions.slice(start, start + SESSIONS_PER_PAGE);
    },
    sortedAgents() {
      return sortRows(this.audit, this.agentsSort, AGENT_COLUMNS);
    },
    pagedAgents() {
      const start = (this.agentsPage - 1) * AGENTS_PER_PAGE;
      return this.sortedAgents.slice(start, start + AGENTS_PER_PAGE);
    },
    // Las cuatro piezas que se pueden nombrar en un Entrenamiento, cada una con
    // la cadena EXACTA que hay que escribir. El texto del chip no es una etiqueta
    // bonita: es lo que el parser busca, y por eso se copia tal cual.
    resourceBlocks() {
      if (!this.inventory) return [];

      const t = key => this.$t(`TRACKING_ASSISTANT_VIEW.${key}`);
      return [
        {
          key: 'sources',
          title: t('SOURCES_TITLE'),
          hint: t('SOURCES_HINT'),
          empty: t('SOURCES_EMPTY'),
          // La directiva la arma el backend desde SEARCH_DIRECTIVES: es la misma
          // cadena que el motor va a detectar al atender un turno.
          items: (this.inventory.sources || []).map(source => ({
            text: source.directive,
            note: source.name,
          })),
        },
        {
          key: 'groups',
          title: t('GROUPS_TITLE'),
          hint: t('GROUPS_HINT'),
          empty: t('GROUPS_EMPTY'),
          items: (this.inventory.canned_groups || []).map(group => ({
            text: `@buscar_predefinidas(${group.prefix})`,
            note: String(group.count),
          })),
        },
        {
          key: 'caseTypes',
          title: t('CASE_TYPES_TITLE'),
          hint: t('CASE_TYPES_HINT'),
          empty: t('CASE_TYPES_EMPTY'),
          items: (this.inventory.case_types || []).map(name => ({
            text: `@crear_ticket(tipo=${name})`,
            note: '',
          })),
        },
        {
          key: 'actions',
          title: t('ACTIONS_TITLE'),
          hint: t('ACTIONS_HINT'),
          empty: '',
          // `note` acá no es contexto decorativo: dice que la directiva NO va a
          // ejecutar. @agendar_calendar parsea bien y no agenda nada si la cuenta
          // no tiene calendario conectado, así que si el chip no lo avisa, la
          // pantalla ofrece algo que no funciona.
          items: (this.inventory.actions || []).map(action => ({
            text: action.directive,
            note: action.available ? '' : t('ACTIONS_UNAVAILABLE'),
          })),
        },
        {
          key: 'labels',
          title: t('LABELS_TITLE'),
          hint: t('LABELS_HINT'),
          empty: t('LABELS_EMPTY'),
          items: (this.inventory.labels || []).map(name => ({
            text: `#${name}`,
            note: '',
          })),
        },
      ];
    },
  },
  watch: {
    // Descartar la última conversación de la página dejaba la tabla en blanco
    // con el paginado marcando una página que ya no existe.
    sessions(list) {
      const pages = Math.max(1, Math.ceil(list.length / SESSIONS_PER_PAGE));
      if (this.sessionsPage > pages) this.sessionsPage = pages;
    },
    audit(list) {
      const pages = Math.max(1, Math.ceil(list.length / AGENTS_PER_PAGE));
      if (this.agentsPage > pages) this.agentsPage = pages;
    },
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
    this.$store.dispatch('inboxes/get');
    // Se espera la lista antes de resolver el ?template_id de la URL: si no, se
    // entraría desde Agentes IA con el panel vacío y sin decir por qué.
    await this.$store.dispatch('trackingTemplates/get');
    this.fetchAudit();
    this.fetchSessions();
    // El ?template_id manda sobre la conversación guardada: si se entró desde un
    // agente concreto, es a ese al que se vino, no a lo que quedó a medias.
    if (!this.loadTemplateFromRoute()) await this.resumeSession();
    // Sin nada que retomar, el formulario igual tiene que estar listo (los nombres
    // de sección que ofrece "Agregar sección" salen del backend).
    this.reloadTrainingSections();
  },
  // ⚠ Era `beforeUnmount`, que en Vue 2.7 con la Options API no existe: el
  // temporizador de validación nunca se limpiaba al salir de la pantalla.
  beforeDestroy() {
    clearTimeout(this.validateTimer);
    clearInterval(this.progressTimer);
  },
  methods: {
    // Entrada desde Agentes IA: /tracking-dashboard/assistant?template_id=123
    // o ?nuevo=1 para armar uno nuevo, sin retomar lo que quedó a medias.
    loadTemplateFromRoute() {
      if (this.$route.query.nuevo) {
        this.startFresh();
        return true;
      }
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

        this.applySession(data);
        if (data.tracking_template_id) {
          this.loadEditingFrom(data.tracking_template_id);
        }
      } catch (error) {
        this.sessionId = null;
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
        this.applySession(data);
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
      this.isBuilding = true;
      this.versions = [];
      this.draftTab = 'editor';
      this.reloadTrainingSections();
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
    // Tocar un encabezado vuelve a la primera página: quedarse en la página 3
    // después de reordenar muestra filas del medio y se lee como un error.
    sortSessionsBy(key) {
      this.sessionsSort = nextOrder(this.sessionsSort, key);
      this.sessionsPage = 1;
    },
    sortAgentsBy(key) {
      this.agentsSort = nextOrder(this.agentsSort, key);
      this.agentsPage = 1;
    },
    // El idioma sale del navegador y no de un 'es-MX' fijo: el Asistente ahora
    // habla los dos idiomas, así que una fecha clavada en español le saldría en
    // español a una cuenta en inglés.
    formatDate(value) {
      if (!value) return '—';

      return new Date(value).toLocaleString(undefined, {
        day: '2-digit',
        month: '2-digit',
        year: 'numeric',
        hour: '2-digit',
        minute: '2-digit',
      });
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
    // Cargar un agente roto en el panel lo deja listo para corregir y reemplazar:
    // el arreglo pasa por el mismo comprobador y el mismo guardado que uno nuevo.
    auditLabel(status) {
      return AUDIT_STATUS_LABEL[status] || AUDIT_STATUS_LABEL.empty;
    },
    openInAssistant(row) {
      this.loadTemplate(this.templates.find(t => t.id === row.id));
    },
    // Partir de un agente SANO para hacer otra versión. Distinto de "arreglarlo
    // acá": ahí se corrige el que está roto y se lo reemplaza; acá el original
    // sigue andando en producción y lo que se guarda es un agente nuevo.
    //
    // Por eso NO se marca editingTemplate: con él puesto, el modal abre en
    // "reemplazar" y guardar pisaría justo el agente que se quería conservar.
    // Se deja el borrador y una propuesta de nombre libre, y el modal abre en
    // "crear nuevo".
    duplicateInAssistant(row) {
      const template = this.templates.find(t => t.id === row.id);
      if (!template) return;

      this.startFresh();
      this.draft = template.complementary_prompt || '';
      if (template.inbox_id) this.setInbox(template.inbox_id);
      this.lastDelivered = this.draft;
      this.isBuilding = false;
      this.versions = [];
      this.draftTab = 'editor';
      this.reloadTrainingSections();
      this.proposal = {
        name: this.nextVersionName(template.name),
        objective: template.objective || '',
        ai_context: template.ai_context || '',
      };
      this.validateDraft();
    },
    // "Soporte" → "Soporte v2", y si ese ya existe → v3. El nombre es único por
    // cuenta: proponer uno tomado hace fallar el guardado con un error del
    // modelo, que es peor que resolverlo acá.
    nextVersionName(base) {
      const taken = new Set(
        this.templates.map(t => (t.name || '').trim().toLowerCase())
      );
      for (let version = 2; version < 100; version += 1) {
        const candidate = `${base} v${version}`;
        if (!taken.has(candidate.toLowerCase())) return candidate;
      }
      return `${base} v100`;
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
      this.activeTab = 0;
      this.validateDraft();
    },
    async sendMessage(content) {
      this.messages.push({ role: 'user', content });
      this.isThinking = true;
      const turnId = this.startProgress();
      try {
        const { data } = await AssistantAPI.interview(
          this.messages,
          this.inboxId,
          {
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
            : this.$t('TRACKING_ASSISTANT_VIEW.ERROR_GENERIC');
        this.messages.push({ role: 'assistant', content: reason });
      } finally {
        this.stopProgress();
        this.isThinking = false;
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
      const deadline = Date.now() + OPTIMIZE_MAX_WAIT_MS;
      while (Date.now() < deadline) {
        // eslint-disable-next-line no-await-in-loop
        await new Promise(resolve => {
          setTimeout(resolve, PROGRESS_POLL_MS);
        });
        // eslint-disable-next-line no-await-in-loop
        const { status, data } = await AssistantAPI.getOptimizeResult(turnId);
        if (status === 200) return data;
      }
      throw new Error('optimize timeout');
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
    onDraftInput() {
      clearTimeout(this.validateTimer);
      this.validateTimer = setTimeout(this.validateDraft, VALIDATE_DEBOUNCE_MS);
      // Editar no borra las pruebas: las envejece. Cada corrida guardó contra qué
      // versión se hizo, así que las anteriores quedan marcadas en vez de
      // desaparecer — y la comparación entre preguntas se conserva.
      this.draftVersion += 1;
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
        this.sessionMeta = null;
        this.dryRunHistory = [];
        this.suggestedTests = null;
        // Lo que el comprobador no podía revisar sobre el borrador: directivas
        // que dependen de la configuración del AGENTE, que recién ahora existe.
        // El aviso se muestra ANTES de navegar a propósito: la pantalla a la que
        // se llega es justo donde se asigna el calendario.
        (data.warnings || []).forEach(warning => useAlert(warning.message));
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
          <!-- El `index` de cada pestaña es explícito, así que esconder esta no
               corre las otras. -->
          <woot-tabs-item
            v-if="showSessionsTab"
            :index="1"
            :name="$t('TRACKING_ASSISTANT_VIEW.TAB_SESSIONS')"
            :count="sessions.length"
          />
          <woot-tabs-item
            :index="2"
            :name="$t('TRACKING_ASSISTANT_VIEW.TAB_AUDIT')"
            :count="brokenAgents.length"
          />
          <woot-tabs-item
            :index="3"
            :name="$t('TRACKING_ASSISTANT_VIEW.TAB_INVENTORY')"
            :show-badge="false"
          />
        </woot-tabs>

        <div
          v-show="activeTab === 0"
          class="flex flex-col flex-1 min-h-0 gap-3"
        >
          <!-- De qué conversación se trata y con qué canal se prueba. Están fuera
               de las dos columnas porque valen para toda la pantalla: el canal
               decide con qué modelo se clasifica y se contesta, y la tarjeta dice
               qué agente se está editando. Con el chat escondido, siguen acá. -->
          <div class="flex flex-wrap items-center gap-x-4 gap-y-2 shrink-0">
            <SessionCard
              :session-meta="sessionMeta"
              :editing-template="editingTemplate"
            />
            <!-- Empezar de cero. Estaba solo en la pestaña Conversaciones, donde
                 nadie lo encontraba: es la puerta para armar un agente nuevo. -->
            <woot-button
              size="small"
              variant="smooth"
              color-scheme="success"
              icon="add"
              @click="startFresh"
            >
              {{ $t('TRACKING_ASSISTANT_VIEW.NEW_AGENT') }}
            </woot-button>
            <woot-button
              size="small"
              variant="smooth"
              color-scheme="secondary"
              icon="attach"
              @click="showBriefModal = true"
            >
              {{ $t('TRACKING_ASSISTANT_VIEW.BRIEF_OPEN') }}
            </woot-button>
            <div class="flex flex-wrap items-center gap-2 text-xs shrink-0">
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
          </div>

          <div
            class="grid flex-1 min-h-0 gap-4"
            :class="
              showChat && !isWideEditor ? 'md:grid-cols-3' : 'md:grid-cols-2'
            "
          >
            <!-- v-show y no v-if: la conversación se esconde, no se desmonta. Con
               v-if se perdería el scroll del hilo y lo tecleado sin enviar cada
               vez que alguien entra y sale del modo ancho. -->
            <section
              v-show="showChat && !isWideEditor"
              class="p-4 bg-white rounded-lg dark:bg-slate-800 border border-slate-100 dark:border-slate-700 flex flex-col min-h-0"
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

            <!-- SECCIONES · el formulario, a la izquierda. Es donde se arma el
                 Entrenamiento: cada cambio vuelve a armar el texto en el backend y
                 se ve al instante en la columna de la derecha. -->
            <section
              class="flex flex-col min-h-0 p-4 bg-white rounded-lg dark:bg-slate-800 border border-slate-100 dark:border-slate-700"
            >
              <h3
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
                    <button
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
                  <!-- Para los Entrenamientos largos: 38 líneas siguen siendo poco
                     para uno de 645. Mientras se edita un texto así no hace falta
                     ver el chat; al volver, sigue donde estaba. -->
                  <woot-button
                    v-if="showChat"
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
                <VersionsPanel
                  v-if="draftTab === 'versions'"
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
                    class="flex flex-col gap-2 p-3 mb-2 text-xs border rounded shrink-0 border-amber-300 bg-amber-50 text-amber-900 dark:bg-amber-900/30 dark:text-amber-100"
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
                  <textarea
                    ref="draftEditor"
                    v-model="draft"
                    class="flex-1 min-h-0 w-full font-mono text-xs resize-none !mb-0"
                    :placeholder="
                      $t('TRACKING_ASSISTANT_VIEW.DRAFT_PLACEHOLDER')
                    "
                    :readonly="isThinking"
                    @select="onDraftSelect"
                    @keyup="onDraftSelect"
                    @mouseup="onDraftSelect"
                    @input="onDraftInput"
                  />
                </template>
              </div>
            </section>
          </div>
        </div>

        <!-- RECURSOS — la paleta de piezas de la cuenta.
             Antes esto era una referencia: cuatro bloques de texto separados por
             puntos, con lo que la cuenta tiene. El problema es que el motor
             reconoce estas cadenas con patrones EXACTOS y falla en silencio si
             no coinciden, así que había que retipearlas —y una @ruta con la
             fuente mal escrita parsea perfecto y no consulta nada.
             Ahora cada pieza se muestra como la cadena que hay que escribir, y
             tocarla la copia. La pestaña deja de ser una referencia y pasa a ser
             la paleta desde la que se arma el Entrenamiento. -->
        <div v-show="activeTab === 3" class="flex-1 min-h-0 overflow-y-auto">
          <p class="mb-3 text-xs text-slate-500 dark:text-slate-400">
            {{ $t('TRACKING_ASSISTANT_VIEW.RESOURCES_HINT') }}
          </p>

          <div class="grid gap-4 md:grid-cols-2">
            <!-- Cada bloque dice PARA QUÉ sirve la pieza, no solo cómo se llama:
                 sin eso, "grupos" y "etiquetas" son dos listas indistinguibles
                 para quien nunca escribió una @ruta. -->
            <section
              v-for="block in resourceBlocks"
              :key="block.key"
              class="p-4 bg-white border rounded-lg dark:bg-slate-800 border-slate-100 dark:border-slate-700"
            >
              <h3
                class="text-sm font-semibold text-slate-800 dark:text-slate-100"
              >
                {{ block.title }}
              </h3>
              <p class="mt-0.5 mb-3 text-xs text-slate-500 dark:text-slate-400">
                {{ block.hint }}
              </p>

              <div v-if="block.items.length" class="flex flex-wrap gap-1.5">
                <CopyChip
                  v-for="item in block.items"
                  :key="item.text"
                  :text="item.text"
                  :note="item.note"
                />
              </div>
              <p v-else class="text-xs text-slate-400 dark:text-slate-500">
                {{ block.empty }}
              </p>
            </section>
          </div>

          <!-- Las frases van ÚLTIMAS y aparte: son las únicas que no se escriben
               en el Entrenamiento. Son el material con el que el asistente
               redacta las descripciones de rama, y lo único de esta pantalla que
               sale hacia OpenAI. -->
          <section
            class="p-4 mt-4 bg-white border rounded-lg dark:bg-slate-800 border-slate-100 dark:border-slate-700"
          >
            <h3
              class="mb-1 text-sm font-semibold text-slate-800 dark:text-slate-100"
            >
              {{ $t('TRACKING_ASSISTANT_VIEW.PHRASES_TITLE') }}
            </h3>
            <p class="mb-3 text-xs text-slate-500 dark:text-slate-400">
              {{ $t('TRACKING_ASSISTANT_VIEW.PHRASES_HINT') }}
            </p>
            <ul class="grid gap-1 md:grid-cols-2">
              <li
                v-for="phrase in inventory.customer_phrases"
                :key="phrase"
                class="text-xs text-slate-600 dark:text-slate-400"
              >
                · {{ phrase }}
              </li>
              <li
                v-if="!inventory.customer_phrases.length"
                class="text-xs text-slate-400 dark:text-slate-500"
              >
                {{ $t('TRACKING_ASSISTANT_VIEW.PHRASES_EMPTY') }}
              </li>
            </ul>
          </section>
        </div>

        <!-- AGENTES IA — los ya cargados, pasados por el mismo comprobador.
             En tabla y no como tarjetas: son 28 en esta cuenta, y como lista
             había que scrollear todo para encontrar los roto. Ordenable por
             encabezado y paginada, igual que Conversaciones. -->
        <div v-show="activeTab === 2" class="flex flex-col flex-1 min-h-0">
          <p class="mb-3 text-xs shrink-0 text-slate-500 dark:text-slate-400">
            {{ $t('TRACKING_ASSISTANT_VIEW.AUDIT_HINT') }}
          </p>

          <div
            v-if="isAuditing"
            class="text-xs text-slate-500 dark:text-slate-400 py-4"
          >
            {{ $t('TRACKING_ASSISTANT_VIEW.REPORT_CHECKING') }}
          </div>

          <template v-else>
            <div
              class="flex-1 min-h-0 overflow-auto bg-white border rounded-lg dark:bg-slate-800 border-slate-100 dark:border-slate-700"
            >
              <table class="w-full text-sm">
                <thead class="sticky top-0 z-10 bg-white dark:bg-slate-800">
                  <tr
                    class="text-left border-b text-slate-500 dark:text-slate-400 border-slate-100 dark:border-slate-700"
                  >
                    <SortableTh
                      v-for="col in agentHeaders"
                      :key="col.key"
                      :label="$t(col.label)"
                      :sort-key="col.key"
                      :sort="agentsSort"
                      :align-right="col.right"
                      @sort="sortAgentsBy"
                    />
                    <th
                      class="p-3 w-44"
                      :aria-label="
                        $t('TRACKING_ASSISTANT_VIEW.SESSIONS_COL_ACTIONS')
                      "
                    />
                  </tr>
                </thead>
                <tbody>
                  <tr
                    v-for="row in pagedAgents"
                    :key="row.id"
                    class="border-b border-slate-50 dark:border-slate-700/50 hover:bg-slate-50 dark:hover:bg-slate-700/30"
                  >
                    <td class="p-3">
                      <span
                        class="text-xs font-medium px-2 py-0.5 rounded whitespace-nowrap"
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
                    </td>
                    <td
                      class="p-3 font-medium text-slate-800 dark:text-slate-100"
                    >
                      {{ row.name }}
                    </td>
                    <td
                      class="p-3 text-right text-slate-500 dark:text-slate-400"
                    >
                      {{ row.routes }}
                    </td>
                    <td class="p-3 text-right">
                      <span
                        :class="
                          row.defects
                            ? 'text-red-700 dark:text-red-300 font-medium'
                            : 'text-slate-400 dark:text-slate-500'
                        "
                      >
                        {{ row.defects }}
                      </span>
                    </td>
                    <td class="p-3 text-right">
                      <span
                        :class="
                          row.degrading
                            ? 'text-amber-700 dark:text-amber-400'
                            : 'text-slate-400 dark:text-slate-500'
                        "
                      >
                        {{ row.degrading }}
                      </span>
                    </td>
                    <!-- El primer defecto, truncado: alcanza para decidir si vale
                         la pena abrirlo. El detalle sale al cargarlo. -->
                    <td
                      class="p-3 text-xs max-w-xs text-red-700 dark:text-red-300"
                    >
                      <span class="block truncate" :title="row.headline || ''">
                        {{ row.headline || '—' }}
                      </span>
                    </td>
                    <td class="p-3">
                      <!-- Cada estado tiene su acción, y NINGUNO se queda sin
                           una. El que no tiene Entrenamiento es el más inerte de
                           todos —contesta sin ninguna configuración— y era
                           justamente el único al que la pantalla no le ofrecía
                           nada: se lo veía en rojo y ahí terminaba.

                           Roto  -> arreglarlo y reemplazarlo.
                           Vacío -> escribirle el Entrenamiento que no tiene.
                           Sano  -> partir de él para otra versión, sin tocar el
                                    que está andando en producción. -->
                      <woot-button
                        v-if="row.status === 'broken'"
                        size="small"
                        variant="clear"
                        @click="openInAssistant(row)"
                      >
                        {{ $t('TRACKING_ASSISTANT_VIEW.AUDIT_FIX') }}
                      </woot-button>
                      <woot-button
                        v-else-if="row.status === 'empty'"
                        size="small"
                        variant="clear"
                        color-scheme="secondary"
                        icon="wand"
                        @click="openInAssistant(row)"
                      >
                        {{ $t('TRACKING_ASSISTANT_VIEW.AUDIT_WRITE') }}
                      </woot-button>
                      <woot-button
                        v-else
                        size="small"
                        variant="clear"
                        color-scheme="secondary"
                        icon="copy"
                        @click="duplicateInAssistant(row)"
                      >
                        {{ $t('TRACKING_ASSISTANT_VIEW.AUDIT_NEW_VERSION') }}
                      </woot-button>
                    </td>
                  </tr>
                </tbody>
              </table>
            </div>

            <TableFooter
              class="border-t shrink-0 border-slate-75 dark:border-slate-700/50"
              :current-page="agentsPage"
              :total-count="audit.length"
              :page-size="AGENTS_PER_PAGE"
              @pageChange="agentsPage = $event"
            />
          </template>
        </div>

        <!-- Las conversaciones: un Entrenamiento bueno rara vez sale de una
             sentada, así que hay que poder volver a una y comparar intentos.
             En tabla y con el paginado nativo —el mismo de Campañas y del
             listado de seguimientos—: como lista de tarjetas, 50 conversaciones
             eran 50 pantallazos de scroll y no había forma de comparar dos. -->
        <div v-show="activeTab === 1" class="flex flex-col flex-1 min-h-0">
          <div class="flex items-center justify-between mb-3 shrink-0">
            <p class="text-xs text-slate-500 dark:text-slate-400">
              {{ $t('TRACKING_ASSISTANT_VIEW.SESSIONS_HINT') }}
            </p>
            <woot-button variant="clear" size="small" @click="startFresh">
              {{ $t('TRACKING_ASSISTANT_VIEW.SESSIONS_NEW') }}
            </woot-button>
          </div>

          <div
            v-if="!sessions.length"
            class="text-xs text-slate-500 dark:text-slate-400 py-4"
          >
            {{ $t('TRACKING_ASSISTANT_VIEW.SESSIONS_EMPTY') }}
          </div>

          <template v-else>
            <div
              class="flex-1 min-h-0 overflow-auto bg-white border rounded-lg dark:bg-slate-800 border-slate-100 dark:border-slate-700"
            >
              <table class="w-full text-sm">
                <thead class="sticky top-0 z-10 bg-white dark:bg-slate-800">
                  <tr
                    class="text-left border-b text-slate-500 dark:text-slate-400 border-slate-100 dark:border-slate-700"
                  >
                    <SortableTh
                      v-for="col in sessionHeaders"
                      :key="col.key"
                      :label="$t(col.label)"
                      :sort-key="col.key"
                      :sort="sessionsSort"
                      @sort="sortSessionsBy"
                    />
                    <th
                      class="w-24 p-3"
                      :aria-label="
                        $t('TRACKING_ASSISTANT_VIEW.SESSIONS_COL_ACTIONS')
                      "
                    />
                  </tr>
                </thead>
                <tbody>
                  <tr
                    v-for="row in pagedSessions"
                    :key="row.id"
                    class="border-b cursor-pointer border-slate-50 dark:border-slate-700/50 hover:bg-slate-50 dark:hover:bg-slate-700/30"
                    @click="openSession(row.id)"
                  >
                    <!-- El identificador es el id de la fila y nada más: esta
                         tabla no tiene folio ni serie. Se muestra igual porque
                         es lo único con lo que dos conversaciones del mismo día
                         y el mismo agente se pueden distinguir al hablar de
                         ellas. -->
                    <td
                      class="p-3 font-mono text-xs text-slate-400 dark:text-slate-500"
                    >
                      #{{ row.id }}
                    </td>
                    <td class="p-3">
                      <span
                        class="text-xs font-medium px-2 py-0.5 rounded whitespace-nowrap"
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
                    </td>
                    <td
                      class="p-3 font-medium text-slate-800 dark:text-slate-100"
                    >
                      {{
                        row.title ||
                        $t('TRACKING_ASSISTANT_VIEW.SESSIONS_UNTITLED')
                      }}
                    </td>
                    <!-- De quién es: desde que las conversaciones se comparten
                         entre administradores, el listado tiene trabajo de
                         varias personas. -->
                    <td class="p-3 text-slate-500 dark:text-slate-400">
                      {{
                        row.mine
                          ? $t('TRACKING_ASSISTANT_VIEW.SESSIONS_MINE')
                          : row.creator ||
                            $t('TRACKING_ASSISTANT_VIEW.SESSIONS_NO_CREATOR')
                      }}
                    </td>
                    <td class="p-3 text-slate-500 dark:text-slate-400">
                      {{ row.template_name || '—' }}
                    </td>
                    <td class="p-3 text-slate-500 dark:text-slate-400">
                      {{ row.routes }}
                    </td>
                    <!-- Creación y última modificación son dos preguntas
                         distintas: cuándo se empezó a armar este agente, y
                         cuándo se lo tocó por última vez. En una entrevista que
                         se retoma tres días después, la diferencia es el dato. -->
                    <td
                      class="p-3 text-slate-500 dark:text-slate-400 whitespace-nowrap"
                    >
                      {{ formatDate(row.created_at) }}
                    </td>
                    <td
                      class="p-3 text-slate-500 dark:text-slate-400 whitespace-nowrap"
                    >
                      {{ formatDate(row.updated_at) }}
                    </td>
                    <td class="p-3">
                      <div class="flex items-center justify-end gap-1">
                        <woot-button
                          size="small"
                          variant="clear"
                          @click.stop="openSession(row.id)"
                        >
                          {{ $t('TRACKING_ASSISTANT_VIEW.SESSIONS_RESUME') }}
                        </woot-button>
                        <woot-button
                          size="small"
                          variant="clear"
                          color-scheme="alert"
                          icon="delete"
                          @click.stop="discardSession(row.id)"
                        />
                      </div>
                    </td>
                  </tr>
                </tbody>
              </table>
            </div>

            <TableFooter
              class="border-t shrink-0 border-slate-75 dark:border-slate-700/50"
              :current-page="sessionsPage"
              :total-count="sessions.length"
              :page-size="SESSIONS_PER_PAGE"
              @pageChange="sessionsPage = $event"
            />
          </template>
        </div>
        <!-- GUARDAR — vive fuera de los paneles porque es la salida de la
             pestaña Asistente, no de uno de sus bloques. Queda apagado mientras
             el comprobador encuentre algo bloqueante: guardar un agente que no
             ejecuta nada es exactamente el problema que este módulo vino a
             arreglar. -->
        <div
          v-show="activeTab === 0"
          class="flex justify-end gap-2 pt-4 shrink-0"
        >
          <!-- Probar va ANTES de guardar, y en ese orden se lee: el comprobador
               dice si se ejecuta, esto dice si rutea bien, y recién después se
               guarda. -->
          <woot-button
            variant="clear"
            color-scheme="secondary"
            :is-disabled="!draft.trim()"
            @click="showDryRunModal = true"
          >
            {{ $t('TRACKING_ASSISTANT_VIEW.DRY_RUN_TITLE') }}
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
            {{ $t('TRACKING_ASSISTANT_VIEW.SAVE_CTA') }}
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
    <BriefModal
      :show="showBriefModal"
      :session-id="sessionId"
      @close="showBriefModal = false"
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
      @close="showSaveModal = false"
      @save="saveDraft"
    />
  </div>
</template>
