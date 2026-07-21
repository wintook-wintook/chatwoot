<!--
  @tickets_cases
  Vista de detalle de un CaseTicket — timeline + acciones. Tailwind + dark mode.
-->
<script>
import { mapGetters } from 'vuex';
import JourneyView from './JourneyView.vue';
import TicketConversation from '../../components/contacts/CaseTicket/TicketConversation.vue';
import TicketTasks from '../../components/contacts/CaseTicket/TicketTasks.vue';
import MultiselectDropdown from 'shared/components/ui/MultiselectDropdown.vue';
import CaseTicketsAPI from 'dashboard/api/caseTickets';
import {
  SIMPLE_TRANSITION_TARGETS,
  toSimpleStatus,
} from '../../helper/caseSimpleStatus';

// @tickets_cases — pestaña activa del detalle, recordada por usuario.
const DETAIL_TAB_KEY = 'gestorTickets.detailTab';

export default {
  name: 'TicketDetail',
  components: {
    JourneyView,
    TicketConversation,
    TicketTasks,
    MultiselectDropdown,
  },
  props: {
    ticketId: { type: Number, required: true },
  },
  data() {
    return {
      // @tickets_cases — pestaña activa del detalle (Resumen / Avance / IA).
      activeDetailTab: localStorage.getItem(DETAIL_TAB_KEY) || 'journey',
      lockedAcquired: false, // @tickets_cases — este agente tomó el bloqueo
      showTransitionMenu: false,
      showPriorityMenu: false, // @tickets_cases P1 — prioridad inline
      showDueMenu: false, // @tickets_cases P4 — vencimiento inline
      dueDraft: '', // valor del input datetime-local
      taskCount: 0, // @tickets_cases P4 — total de tareas (badge del tab)
      showEscalateModal: false,
      escalateForm: { team_id: '', reason: '' },
      // 2E — relaciones entre tickets
      showRelationModal: false,
      showDeleteRelation: false,
      relationToDelete: null,
      relationForm: { relation_type: 'duplicate' },
      relationQuery: '',
      relationResults: [],
      relationSelected: null,
      isSearchingTickets: false,
      relationSearchTimer: null,
      // 2F — Problema / Cambio
      showDetailsModal: false,
      detailsForm: {},
      isSavingDetails: false,
      showRejectModal: false,
      rejectReason: '',
      showResolveProblemModal: false,
      propagateToIncidents: true,
      // 2G — cierre documentado
      showCloseModal: false,
      closeForm: {
        closure_type: 'resolved',
        closure_cause: '',
        closure_solution: '',
        customer_confirmed: false,
      },
      // 3C — respuesta sugerida desde KB
      replySuggestion: null,
      isSuggestingReply: false,
      replyCopied: false,
      // 3E — resumen + causa raíz
      summaryResult: null,
      isSummarizing: false,
      // 3D — detección de repetidos
      duplicateResult: null,
      isDetectingDuplicates: false,
      linkingDuplicateId: null,
      // 3F — seguimiento sugerido
      followUpResult: null,
      isFollowingUp: false,
      followUpCopied: false,
      // 2H — base de conocimiento
      showArticleModal: false,
      kbPortals: [],
      isGeneratingArticle: false,
      articleForm: {
        portal_id: '',
        category_id: '',
        title: '',
        content: '',
        published: false,
      },
    };
  },
  computed: {
    ...mapGetters({
      getTicketById: 'caseTickets/getTicketById',
      getTicketEvents: 'caseTickets/getTicketEvents',
      getTicketRelations: 'caseTickets/getTicketRelations',
      relationsUiFlags: 'caseTickets/getRelationsUIFlags',
      uiFlags: 'caseTickets/getUIFlags',
      teams: 'teams/getTeams',
      agents: 'agents/getAgents',
      itilEnabled: 'caseTickets/getItilEnabled', // modo simple/ITIL
      currentUserID: 'getCurrentUserID', // @tickets_cases — bloqueo de ticket
    }),
    // ¿Otro agente tiene bloqueado este ticket?
    lockedByOther() {
      const lb = this.ticket?.locked_by;
      return !!lb && lb.id !== this.currentUserID;
    },
    ticket() {
      return this.getTicketById(this.ticketId);
    },
    events() {
      return this.getTicketEvents(this.ticketId);
    },
    relations() {
      return this.getTicketRelations(this.ticketId);
    },
    relationTypeOptions() {
      return [
        'duplicate',
        'parent_child',
        'incident_problem',
        'incident_change',
        'change_problem',
      ];
    },
    // @tickets_cases 2F
    isProblem() {
      return this.ticket?.ticket_kind === 'problem';
    },
    isChange() {
      return this.ticket?.ticket_kind === 'change';
    },
    changeApprovalStatus() {
      return this.ticket?.change_approval_status || 'pending';
    },
    changeAttrs() {
      return this.ticket?.custom_attributes || {};
    },
    relatedIncidentsCount() {
      return this.relations.filter(
        r =>
          r.relation_type === 'incident_problem' && r.direction === 'incoming'
      ).length;
    },
    riskLevelOptions() {
      return ['low', 'medium', 'high'];
    },
    // @tickets_cases 2K — campos personalizados del tipo con su valor capturado.
    customFieldRows() {
      const defs = this.ticket?.case_type?.custom_fields || [];
      const attrs = this.ticket?.custom_attributes || {};
      return defs
        .filter(
          d => d.key in attrs && attrs[d.key] !== '' && attrs[d.key] !== null
        )
        .map(d => ({
          key: d.key,
          label: d.label,
          value:
            d.field_type === 'checkbox'
              ? this.$t(
                  attrs[d.key]
                    ? 'CASE_TICKETS.CUSTOM_FIELDS.YES'
                    : 'CASE_TICKETS.CUSTOM_FIELDS.NO'
                )
              : String(attrs[d.key]),
        }));
    },
    // @tickets_cases 3B — sugerencia de clasificación pendiente de aprobar.
    aiSuggestion() {
      const s = this.ticket?.ai_classification;
      if (!s || s.applied) return null;
      return s;
    },
    aiSuggestionRows() {
      const s = this.aiSuggestion;
      if (!s) return [];
      const rows = [];
      if (s.ticket_kind) {
        rows.push({
          label: this.$t('CASE_TICKETS.MODAL.TICKET_KIND_LABEL'),
          value: this.$t(`CASE_TICKETS.TICKET_KIND.${s.ticket_kind}`),
        });
      }
      if (s.impact) {
        rows.push({
          label: this.$t('CASE_TICKETS.MODAL.IMPACT_LABEL'),
          value: this.$t(`CASE_TICKETS.IMPACT.${s.impact}`),
        });
      }
      if (s.urgency) {
        rows.push({
          label: this.$t('CASE_TICKETS.MODAL.URGENCY_LABEL'),
          value: this.$t(`CASE_TICKETS.URGENCY.${s.urgency}`),
        });
      }
      if (s.affected_service_name) {
        rows.push({
          label: this.$t('CASE_TICKETS.MODAL.AFFECTED_SERVICE_LABEL'),
          value: s.affected_service_name,
        });
      }
      if (s.category_name) {
        rows.push({
          label: this.$t('CASE_TICKETS.MODAL.CATEGORY_LABEL'),
          value: s.category_name,
        });
      }
      return rows;
    },
    aiConfidencePct() {
      const c = this.aiSuggestion?.confidence;
      return c == null ? null : Math.round(c * 100);
    },
    // @tickets_cases 3C — ¿está activa la respuesta sugerida para este ticket?
    replyEnabled() {
      return !!this.ticket?.ai_actions?.reply;
    },
    // @tickets_cases 3E — ¿está activo el resumen/causa raíz?
    summarizeEnabled() {
      return !!this.ticket?.ai_actions?.summarize;
    },
    // @tickets_cases 3D — ¿está activa la detección de repetidos?
    duplicateEnabled() {
      return !!this.ticket?.ai_actions?.duplicate;
    },
    // @tickets_cases 3F — ¿está activo el seguimiento sugerido?
    followUpEnabled() {
      return !!this.ticket?.ai_actions?.follow_up;
    },
    // Seguimiento pendiente redactado por el job programado (si lo hay).
    pendingFollowUp() {
      return this.ticket?.ai_follow_up || null;
    },
    // Texto a mostrar: el generado on-demand, o el pendiente del job.
    followUpMessage() {
      return (
        this.followUpResult?.message || this.pendingFollowUp?.message || ''
      );
    },
    // @tickets_cases — ¿hay alguna acción de IA activa? (define la pestaña IA)
    hasAiCards() {
      return (
        this.replyEnabled ||
        this.summarizeEnabled ||
        this.duplicateEnabled ||
        this.followUpEnabled
      );
    },
    // @tickets_cases — pestañas del detalle (la de IA solo si hay acciones).
    detailTabs() {
      // @tickets_cases P2 — la conversación ahora vive en el propio Resumen
      // (columna izquierda), ya no como pestaña aparte.
      // @tickets_cases — Avance (Recorrido) es la pestaña principal y va primero.
      const tabs = [
        { key: 'journey', label: this.$t('CASE_TICKETS.DETAIL_TABS.JOURNEY') },
      ];
      // @tickets_cases P4 — Tareas como pestaña propia, con contador.
      tabs.push({
        key: 'tasks',
        label: this.$t('CASE_TICKETS.DETAIL_TABS.TASKS'),
        count: this.taskCount,
      });
      // @tickets_cases — el Resumen ya no muestra info (vive en el header); su
      // contenido real es la conversación, así que la pestaña se llama así.
      tabs.push({
        key: 'detail',
        label: this.$t('CASE_TICKETS.DETAIL_TABS.CONVERSATION'),
      });
      if (this.hasAiCards) {
        tabs.push({ key: 'ai', label: this.$t('CASE_TICKETS.DETAIL_TABS.AI') });
      }
      return tabs;
    },
    activeDetailTabIndex() {
      const idx = this.detailTabs.findIndex(
        t => t.key === this.activeDetailTab
      );
      return idx === -1 ? 0 : idx;
    },
    // Clave de la pestaña realmente visible (autocorrige si la guardada ya no existe).
    currentTabKey() {
      return this.detailTabs[this.activeDetailTabIndex]?.key || 'detail';
    },
    // @tickets_cases 2G
    isClosed() {
      return this.ticket?.status === 'closed';
    },
    closureTypeOptions() {
      return ['resolved', 'duplicate', 'not_applicable', 'cancelled'];
    },
    closeFormValid() {
      const f = this.closeForm;
      return !!(
        f.closure_type &&
        f.closure_cause.trim() &&
        f.closure_solution.trim()
      );
    },
    // @tickets_cases 2H
    selectedPortalCategories() {
      const p = this.kbPortals.find(x => x.id === this.articleForm.portal_id);
      return p?.categories || [];
    },
    isFetchingList() {
      return this.uiFlags.isFetchingList;
    },
    isFetchingEvents() {
      return this.uiFlags.isFetchingEvents;
    },
    isTransitioning() {
      return this.uiFlags.isTransitioning;
    },
    validTransitions() {
      const all = this.ticket?.can_transition_to || [];
      // Modo simple (osTicket): solo se ofrecen los estados destino simples.
      if (this.itilEnabled) return all;
      return all.filter(s => SIMPLE_TRANSITION_TARGETS.includes(s));
    },
    // @tickets_cases 2D — nivel y disponibilidad de escalamiento.
    escalationLabel() {
      const lvl = (this.ticket?.escalation_level || 0) + 1;
      return `N${lvl}`;
    },
    canEscalate() {
      const t = this.ticket;
      if (!t) return false;
      return (
        t.escalation_level < 2 && !['closed', 'cancelled'].includes(t.status)
      );
    },
    // @tickets_cases P1 — prioridades para el dropdown rápido.
    priorityOptions() {
      return ['low', 'medium', 'high', 'urgent'];
    },
    // @tickets_cases — asignación con el dropdown nativo de Chatwoot (avatar + buscador).
    agentsList() {
      return [
        { id: 0, name: this.$t('CASE_TICKETS.ASSIGN.NONE') },
        ...this.agents,
      ];
    },
    teamsList() {
      return [
        { id: 0, name: this.$t('CASE_TICKETS.ASSIGN.NONE') },
        ...this.teams,
      ];
    },
    assignedAgentItem() {
      return this.agents.find(a => a.id === this.ticket?.assignee_id) || {};
    },
    assignedTeamItem() {
      return this.teams.find(t => t.id === this.ticket?.team_id) || {};
    },
    // @tickets_cases P4 — etiqueta corta del vencimiento efectivo para el botón inline.
    dueLabel() {
      const iso = this.ticket?.effective_due_at;
      if (!iso) return this.$t('CASE_TICKETS.DUE_QUICK.NONE');
      return new Date(iso).toLocaleString(undefined, {
        day: '2-digit',
        month: '2-digit',
        hour: '2-digit',
        minute: '2-digit',
      });
    },
    // @tickets_cases P1 — "Tomar": disponible si el ticket no es ya mío y está abierto.
    canClaim() {
      const t = this.ticket;
      if (!t) return false;
      if (['closed', 'cancelled'].includes(t.status)) return false;
      return t.assignee_id !== this.currentUserID;
    },
    slaText() {
      const t = this.ticket;
      if (!t) return '';
      if (t.sla_status === 'overdue')
        return this.$t('CASE_TICKETS.SLA_OVERDUE');
      const target = t.first_response_at
        ? t.resolution_time_target
        : t.first_response_time_target;
      if (!target) return '—';
      const elapsed = (Date.now() - new Date(t.created_at).getTime()) / 60000;
      const remaining = Math.max(0, target - elapsed);
      const h = Math.floor(remaining / 60);
      const m = Math.floor(remaining % 60);
      return h > 0 ? `${h}h ${m}min` : `${m}min`;
    },
  },
  watch: {
    ticketId() {
      this.loadTicket();
    },
  },
  mounted() {
    this.loadTicket();
    this.$store.dispatch('teams/get');
    this.$store.dispatch('agents/get');
    this.$store.dispatch('caseTickets/fetchSettings'); // modo simple/ITIL
    this.acquireLock();
  },
  beforeDestroy() {
    this.releaseLock();
  },
  methods: {
    // @tickets_cases — toma el bloqueo del ticket al abrir; si lo tiene otro, no
    // lo toma (el banner avisará). Refresca el ticket para reflejar el estado.
    async acquireLock() {
      try {
        await CaseTicketsAPI.lock(this.ticketId);
        this.lockedAcquired = true;
      } catch (e) {
        this.lockedAcquired = false; // 409: lo tiene otro agente
      } finally {
        this.$store.dispatch('caseTickets/fetchTicket', this.ticketId);
      }
    },
    releaseLock() {
      if (!this.lockedAcquired) return;
      this.lockedAcquired = false;
      CaseTicketsAPI.unlock(this.ticketId).catch(() => {});
    },
    onDetailTabChange(index) {
      const tab = this.detailTabs[index];
      if (!tab) return;
      this.activeDetailTab = tab.key;
      localStorage.setItem(DETAIL_TAB_KEY, tab.key);
    },
    loadTicket() {
      if (!this.ticket) {
        this.$store.dispatch('caseTickets/fetchTicket', this.ticketId);
      }
      this.$store.dispatch('caseTickets/fetchEvents', {
        ticketId: this.ticketId,
      });
      this.$store.dispatch('caseTickets/fetchRelations', this.ticketId);
    },
    // @tickets_cases — cierra los menús inline (Prioridad/Vence/Estado) al hacer
    // clic fuera de la barra de acciones (v-on-clickaway).
    closeActionMenus() {
      this.showPriorityMenu = false;
      this.showDueMenu = false;
      this.showTransitionMenu = false;
    },
    async transitionTo(status) {
      this.showTransitionMenu = false;
      // 2G — cerrar exige documentar el cierre (modal obligatorio).
      if (status === 'closed') {
        this.closeForm = {
          closure_type: 'resolved',
          closure_cause: '',
          closure_solution: '',
          customer_confirmed: false,
        };
        this.showCloseModal = true;
        return;
      }
      // 2F — resolver un problema con incidentes vinculados pregunta si propagar.
      if (
        status === 'resolved' &&
        this.isProblem &&
        this.relatedIncidentsCount
      ) {
        this.propagateToIncidents = true;
        this.showResolveProblemModal = true;
        return;
      }
      await this.runTransition(status);
    },
    // @tickets_cases 2G — confirmar cierre documentado
    async confirmClose() {
      if (!this.closeFormValid) return;
      await this.runTransition('closed', {
        closure: {
          closure_type: this.closeForm.closure_type,
          closure_cause: this.closeForm.closure_cause.trim(),
          closure_solution: this.closeForm.closure_solution.trim(),
          customer_confirmed: this.closeForm.customer_confirmed,
        },
      });
      this.showCloseModal = false;
    },
    closureTypeLabel(t) {
      return this.$t(`CASE_TICKETS.CLOSURE.TYPES.${t}`) || t;
    },
    // @tickets_cases 3B — aplicar / descartar la sugerencia de clasificación de IA
    async applyAiSuggestion() {
      try {
        await this.$store.dispatch('caseTickets/applyAiSuggestion', {
          ticketId: this.ticketId,
        });
        this.$store.dispatch('caseTickets/fetchEvents', {
          ticketId: this.ticketId,
        });
        this.$emitter.emit('newToastMessage', {
          message: this.$t('CASE_TICKETS.AI.SUGGESTION.APPLIED'),
        });
      } catch (e) {
        this.$emitter.emit('newToastMessage', {
          message: this.$t('CASE_TICKETS.AI.SUGGESTION.ERROR'),
        });
      }
    },
    async dismissAiSuggestion() {
      try {
        await this.$store.dispatch(
          'caseTickets/dismissAiSuggestion',
          this.ticketId
        );
      } catch (e) {
        this.$emitter.emit('newToastMessage', {
          message: this.$t('CASE_TICKETS.AI.SUGGESTION.ERROR'),
        });
      }
    },
    // @tickets_cases 3C — generar respuesta sugerida desde la KB
    async generateReply() {
      this.isSuggestingReply = true;
      this.replyCopied = false;
      try {
        this.replySuggestion = await this.$store.dispatch(
          'caseTickets/suggestReply',
          this.ticketId
        );
      } catch (e) {
        this.$emitter.emit('newToastMessage', {
          message: this.$t('CASE_TICKETS.AI.REPLY.ERROR'),
        });
      } finally {
        this.isSuggestingReply = false;
      }
    },
    async copyReply() {
      if (!this.replySuggestion?.reply) return;
      try {
        await navigator.clipboard.writeText(this.replySuggestion.reply);
        this.replyCopied = true;
        this.$emitter.emit('newToastMessage', {
          message: this.$t('CASE_TICKETS.AI.REPLY.COPIED'),
        });
      } catch (e) {
        this.replyCopied = false;
      }
    },
    // @tickets_cases P2 — lleva la sugerencia de la IA a la caja de respuesta del
    // hilo (cambia al Resumen, donde ahora vive la conversación, y precarga el texto).
    useReplyInConversation() {
      const text = this.replySuggestion?.reply;
      if (!text) return;
      this.activeDetailTab = 'detail';
      localStorage.setItem(DETAIL_TAB_KEY, 'detail');
      this.$nextTick(() => this.$refs.ticketConversation?.setReply(text));
    },
    // @tickets_cases 3E — generar resumen + causa raíz
    async generateSummary() {
      this.isSummarizing = true;
      try {
        this.summaryResult = await this.$store.dispatch(
          'caseTickets/summarizeTicket',
          this.ticketId
        );
      } catch (e) {
        this.$emitter.emit('newToastMessage', {
          message: this.$t('CASE_TICKETS.AI.SUMMARY.ERROR'),
        });
      } finally {
        this.isSummarizing = false;
      }
    },
    // @tickets_cases 3D — detección de incidentes repetidos
    async detectDuplicates() {
      this.isDetectingDuplicates = true;
      try {
        this.duplicateResult = await this.$store.dispatch(
          'caseTickets/detectDuplicates',
          this.ticketId
        );
      } catch (e) {
        this.$emitter.emit('newToastMessage', {
          message: this.$t('CASE_TICKETS.AI.DUPLICATE.ERROR'),
        });
      } finally {
        this.isDetectingDuplicates = false;
      }
    },
    // Vincula un match como duplicado (reusa las relaciones 2E).
    async linkDuplicate(match) {
      this.linkingDuplicateId = match.id;
      try {
        await this.$store.dispatch('caseTickets/createRelation', {
          ticketId: this.ticketId,
          relatedTicketId: match.id,
          relationType: 'duplicate',
        });
        // quita el match ya vinculado de la lista
        this.duplicateResult = {
          ...this.duplicateResult,
          matches: this.duplicateResult.matches.filter(m => m.id !== match.id),
        };
        this.$emitter.emit('newToastMessage', {
          message: this.$t('CASE_TICKETS.AI.DUPLICATE.LINKED'),
        });
      } catch (e) {
        this.$emitter.emit('newToastMessage', {
          message: this.$t('CASE_TICKETS.AI.DUPLICATE.ERROR'),
        });
      } finally {
        this.linkingDuplicateId = null;
      }
    },
    goToTicket(id) {
      this.$router.push({
        name: 'gestorTickets_detail',
        params: { id },
      });
    },
    // @tickets_cases 3F — generar seguimiento sugerido
    async generateFollowUp() {
      this.isFollowingUp = true;
      this.followUpCopied = false;
      try {
        this.followUpResult = await this.$store.dispatch(
          'caseTickets/followUp',
          this.ticketId
        );
      } catch (e) {
        this.$emitter.emit('newToastMessage', {
          message: this.$t('CASE_TICKETS.AI.FOLLOWUP.ERROR'),
        });
      } finally {
        this.isFollowingUp = false;
      }
    },
    async copyFollowUp() {
      if (!this.followUpMessage) return;
      try {
        await navigator.clipboard.writeText(this.followUpMessage);
        this.followUpCopied = true;
        this.$emitter.emit('newToastMessage', {
          message: this.$t('CASE_TICKETS.AI.FOLLOWUP.COPIED'),
        });
      } catch (e) {
        this.followUpCopied = false;
      }
    },
    // @tickets_cases 3E — prellena el modal de cierre con causa raíz + solución de la IA
    async suggestCloseWithAi() {
      this.isSummarizing = true;
      try {
        const res = await this.$store.dispatch(
          'caseTickets/summarizeTicket',
          this.ticketId
        );
        if (res?.root_cause) this.closeForm.closure_cause = res.root_cause;
        if (res?.suggested_solution) {
          this.closeForm.closure_solution = res.suggested_solution;
        }
      } catch (e) {
        this.$emitter.emit('newToastMessage', {
          message: this.$t('CASE_TICKETS.AI.SUMMARY.ERROR'),
        });
      } finally {
        this.isSummarizing = false;
      }
    },
    // @tickets_cases 2H — base de conocimiento
    buildArticleContent() {
      const t = this.ticket || {};
      const parts = [];
      if (t.description) parts.push(`## Síntoma\n\n${t.description}`);
      if (t.closure_cause) parts.push(`## Causa\n\n${t.closure_cause}`);
      if (t.closure_solution)
        parts.push(`## Solución\n\n${t.closure_solution}`);
      return parts.join('\n\n');
    },
    async openArticleModal() {
      this.kbPortals = await this.$store.dispatch('caseTickets/fetchKbPortals');
      this.articleForm = {
        portal_id: this.kbPortals[0]?.id || '',
        category_id: '',
        title: this.ticket?.title || '',
        content: this.buildArticleContent(),
        published: false,
      };
      this.showArticleModal = true;
    },
    async confirmGenerateArticle() {
      if (!this.articleForm.portal_id) {
        this.$emitter.emit('newToastMessage', {
          message: this.$t('CASE_TICKETS.KB.NO_PORTAL'),
        });
        return;
      }
      this.isGeneratingArticle = true;
      try {
        await this.$store.dispatch('caseTickets/generateArticle', {
          ticketId: this.ticketId,
          portal_id: this.articleForm.portal_id,
          category_id: this.articleForm.category_id || undefined,
          title: this.articleForm.title.trim() || undefined,
          content: this.articleForm.content.trim() || undefined,
          published: this.articleForm.published,
        });
        this.showArticleModal = false;
        this.refetch();
        this.$emitter.emit('newToastMessage', {
          message: this.$t('CASE_TICKETS.KB.SUCCESS'),
        });
      } catch (e) {
        this.$emitter.emit('newToastMessage', {
          message: e.response?.data?.error || this.$t('CASE_TICKETS.KB.ERROR'),
        });
      } finally {
        this.isGeneratingArticle = false;
      }
    },
    articleStatusLabel(status) {
      return this.$t(`CASE_TICKETS.KB.STATUS.${status}`) || status;
    },
    async runTransition(status, extra = {}) {
      try {
        await this.$store.dispatch('caseTickets/transitionTicket', {
          ticketId: this.ticketId,
          contactId: this.ticket?.contact_id,
          status,
          ...extra,
        });
        this.refetch();
      } catch (e) {
        this.$emitter.emit('newToastMessage', {
          message: e.response?.data?.error || 'No se pudo cambiar el estado',
        });
      }
    },
    refetch() {
      this.$store.dispatch('caseTickets/fetchTicket', this.ticketId);
      this.$store.dispatch('caseTickets/fetchEvents', {
        ticketId: this.ticketId,
      });
    },
    // @tickets_cases 2F — Problema / Cambio
    openDetailsModal() {
      const a = this.changeAttrs;
      this.detailsForm = this.isProblem
        ? { workaround: a.workaround || '', root_cause: a.root_cause || '' }
        : {
            risk_level: a.risk_level || 'medium',
            requires_approval: !!a.requires_approval,
            rollback_plan: a.rollback_plan || '',
            scheduled_window: a.scheduled_window || '',
          };
      this.showDetailsModal = true;
    },
    async saveDetails() {
      this.isSavingDetails = true;
      try {
        await this.$store.dispatch('caseTickets/updateTicketDetails', {
          ticketId: this.ticketId,
          details: { ...this.detailsForm },
        });
        this.showDetailsModal = false;
      } finally {
        this.isSavingDetails = false;
      }
    },
    async approveChange() {
      try {
        await this.$store.dispatch('caseTickets/changeApproval', {
          ticketId: this.ticketId,
          status: 'approved',
        });
        this.refetch();
        this.$emitter.emit('newToastMessage', {
          message: this.$t('CASE_TICKETS.CHANGE.APPROVED_TOAST'),
        });
      } catch (e) {
        this.$emitter.emit('newToastMessage', {
          message:
            e.response?.data?.error || this.$t('CASE_TICKETS.CHANGE.ERROR'),
        });
      }
    },
    openRejectModal() {
      this.rejectReason = '';
      this.showRejectModal = true;
    },
    async confirmRejectChange() {
      try {
        await this.$store.dispatch('caseTickets/changeApproval', {
          ticketId: this.ticketId,
          status: 'rejected',
          reason: this.rejectReason.trim() || undefined,
        });
        this.showRejectModal = false;
        this.refetch();
        this.$emitter.emit('newToastMessage', {
          message: this.$t('CASE_TICKETS.CHANGE.REJECTED_TOAST'),
        });
      } catch (e) {
        this.$emitter.emit('newToastMessage', {
          message:
            e.response?.data?.error || this.$t('CASE_TICKETS.CHANGE.ERROR'),
        });
      }
    },
    async confirmResolveProblem() {
      this.showResolveProblemModal = false;
      await this.runTransition('resolved', {
        propagateToIncidents: this.propagateToIncidents,
      });
      this.$store.dispatch('caseTickets/fetchRelations', this.ticketId);
    },
    riskLabel(level) {
      return this.$t(`CASE_TICKETS.CHANGE.RISK.${level}`) || level;
    },
    approvalLabel(status) {
      return this.$t(`CASE_TICKETS.CHANGE.APPROVAL.${status}`) || status;
    },
    approvalBadge(status) {
      return (
        {
          pending:
            'bg-yellow-100 text-yellow-800 dark:bg-yellow-900 dark:text-yellow-300',
          approved:
            'bg-green-100 text-green-800 dark:bg-green-900 dark:text-green-300',
          rejected: 'bg-red-100 text-red-800 dark:bg-red-900 dark:text-red-300',
        }[status] || 'bg-slate-100 text-slate-700'
      );
    },
    // @tickets_cases P1 — cambio de prioridad inline (acción rápida estilo osTicket).
    async setPriority(priority) {
      this.showPriorityMenu = false;
      if (priority === this.ticket?.priority) return;
      try {
        await this.$store.dispatch('caseTickets/updatePriority', {
          ticketId: this.ticketId,
          contactId: this.ticket?.contact_id,
          priority,
        });
        this.refetch();
        this.$emitter.emit('newToastMessage', {
          message: this.$t('CASE_TICKETS.PRIORITY_QUICK.SUCCESS'),
        });
      } catch (e) {
        this.$emitter.emit('newToastMessage', {
          message:
            e.response?.data?.error ||
            this.$t('CASE_TICKETS.PRIORITY_QUICK.ERROR'),
        });
      }
    },
    // @tickets_cases P4 — vencimiento inline (osTicket "Due Date").
    openDueMenu() {
      this.showPriorityMenu = false;
      this.showTransitionMenu = false;
      // Precarga el input con la fecha efectiva (manual o estimada por SLA), en hora local.
      this.dueDraft = this.toDatetimeLocal(this.ticket?.effective_due_at);
      this.showDueMenu = !this.showDueMenu;
    },
    async saveDueAt() {
      // El input datetime-local da hora local → la mandamos en ISO (UTC) al backend.
      const dueAt = this.dueDraft
        ? new Date(this.dueDraft).toISOString()
        : null;
      await this.persistDueAt(dueAt);
    },
    async clearDueAt() {
      await this.persistDueAt(null);
    },
    async persistDueAt(dueAt) {
      this.showDueMenu = false;
      try {
        await this.$store.dispatch('caseTickets/updateDueAt', {
          ticketId: this.ticketId,
          contactId: this.ticket?.contact_id,
          dueAt,
        });
        this.refetch();
        this.$emitter.emit('newToastMessage', {
          message: this.$t('CASE_TICKETS.DUE_QUICK.SUCCESS'),
        });
      } catch (e) {
        this.$emitter.emit('newToastMessage', {
          message:
            e.response?.data?.error || this.$t('CASE_TICKETS.DUE_QUICK.ERROR'),
        });
      }
    },
    // Convierte un ISO a valor de input datetime-local (YYYY-MM-DDTHH:mm) en hora local.
    toDatetimeLocal(iso) {
      if (!iso) return '';
      const d = new Date(iso);
      const pad = n => String(n).padStart(2, '0');
      return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(
        d.getDate()
      )}T${pad(d.getHours())}:${pad(d.getMinutes())}`;
    },
    // @tickets_cases P1 — "Tomar": autoasignar el ticket al agente actual (1 clic).
    claimTicket() {
      this.assign({ assigneeId: this.currentUserID });
    },
    // @tickets_cases Fase A — asignación manual (agente y equipo coexisten).
    // @tickets_cases — selección desde el MultiselectDropdown (id 0 = Ninguno).
    onSelectAgent(item) {
      this.assign({ assigneeId: item && item.id ? item.id : null });
    },
    onSelectTeam(item) {
      this.assign({ teamId: item && item.id ? item.id : null });
    },
    async assign(payload) {
      try {
        await this.$store.dispatch('caseTickets/assignTicket', {
          ticketId: this.ticketId,
          contactId: this.ticket?.contact_id,
          ...payload,
        });
        // Refresca el ticket del detalle (getTicketById lee de ticketsList) y su timeline.
        this.$store.dispatch('caseTickets/fetchTicket', this.ticketId);
        this.$store.dispatch('caseTickets/fetchEvents', {
          ticketId: this.ticketId,
        });
        this.$emitter.emit('newToastMessage', {
          message: this.$t('CASE_TICKETS.ASSIGN.SUCCESS'),
        });
      } catch (e) {
        this.$emitter.emit('newToastMessage', {
          message:
            e.response?.data?.error || this.$t('CASE_TICKETS.ASSIGN.ERROR'),
        });
      }
    },
    // @tickets_cases 2D — escalamiento por niveles
    openEscalate() {
      this.escalateForm = { team_id: '', reason: '' };
      this.showEscalateModal = true;
    },
    async confirmEscalate() {
      try {
        await this.$store.dispatch('caseTickets/escalateTicket', {
          ticketId: this.ticketId,
          contactId: this.ticket?.contact_id,
          teamId: this.escalateForm.team_id || undefined,
          reason: this.escalateForm.reason.trim() || undefined,
        });
        this.showEscalateModal = false;
        this.$store.dispatch('caseTickets/fetchTicket', this.ticketId);
        this.$store.dispatch('caseTickets/fetchEvents', {
          ticketId: this.ticketId,
        });
        this.$emitter.emit('newToastMessage', {
          message: this.$t('CASE_TICKETS.ESCALATION.SUCCESS'),
        });
      } catch (e) {
        this.$emitter.emit('newToastMessage', {
          message:
            e.response?.data?.error || this.$t('CASE_TICKETS.ESCALATION.ERROR'),
        });
      }
    },
    // @tickets_cases 2E — relaciones entre tickets
    openRelationModal() {
      this.relationForm = { relation_type: 'duplicate' };
      this.relationQuery = '';
      this.relationResults = [];
      this.relationSelected = null;
      this.showRelationModal = true;
    },
    onRelationSearch() {
      clearTimeout(this.relationSearchTimer);
      const q = this.relationQuery.trim();
      this.relationSelected = null;
      if (q.length < 2) {
        this.relationResults = [];
        return;
      }
      this.relationSearchTimer = setTimeout(async () => {
        this.isSearchingTickets = true;
        try {
          const results = await this.$store.dispatch(
            'caseTickets/searchTickets',
            { q }
          );
          this.relationResults = results.filter(t => t.id !== this.ticketId);
        } finally {
          this.isSearchingTickets = false;
        }
      }, 300);
    },
    selectRelationResult(t) {
      this.relationSelected = t;
      this.relationResults = [];
      this.relationQuery = `${t.folio || t.title}`;
    },
    async confirmRelation() {
      if (!this.relationSelected) return;
      try {
        await this.$store.dispatch('caseTickets/createRelation', {
          ticketId: this.ticketId,
          relatedTicketId: this.relationSelected.id,
          relationType: this.relationForm.relation_type,
        });
        this.showRelationModal = false;
        this.$store.dispatch('caseTickets/fetchEvents', {
          ticketId: this.ticketId,
        });
        this.$emitter.emit('newToastMessage', {
          message: this.$t('CASE_TICKETS.RELATIONS.SUCCESS'),
        });
      } catch (e) {
        this.$emitter.emit('newToastMessage', {
          message:
            e.response?.data?.error || this.$t('CASE_TICKETS.RELATIONS.ERROR'),
        });
      }
    },
    openDeleteRelation(relation) {
      this.relationToDelete = relation;
      this.showDeleteRelation = true;
    },
    async confirmDeleteRelation() {
      try {
        await this.$store.dispatch('caseTickets/deleteRelation', {
          ticketId: this.ticketId,
          relationId: this.relationToDelete.id,
        });
        this.$emitter.emit('newToastMessage', {
          message: this.$t('CASE_TICKETS.RELATIONS.REMOVE_SUCCESS'),
        });
      } finally {
        this.showDeleteRelation = false;
        this.relationToDelete = null;
      }
    },
    relationLabel(relation) {
      return this.$t(
        `CASE_TICKETS.RELATION_TYPES.${relation.relation_type}.${relation.direction}`
      );
    },
    relationTypeLabel(type) {
      return this.$t(`CASE_TICKETS.RELATION_TYPES.${type}.outgoing`);
    },
    openRelatedTicket(id) {
      this.$router.push({
        name: 'gestorTickets_detail',
        params: { id: String(id) },
      });
    },
    priorityBadge(p) {
      return (
        {
          low: 'bg-slate-100 text-slate-700 dark:bg-slate-700 dark:text-slate-300',
          medium:
            'bg-blue-100 text-blue-800 dark:bg-blue-900 dark:text-blue-300',
          high: 'bg-yellow-100 text-yellow-800 dark:bg-yellow-900 dark:text-yellow-300',
          urgent: 'bg-red-100 text-red-800 dark:bg-red-900 dark:text-red-300',
        }[p] || 'bg-slate-100 text-slate-700'
      );
    },
    // @tickets_cases — esquema de color del botón "Prioridad" según la prioridad.
    priorityScheme(p) {
      return (
        {
          low: 'secondary',
          medium: 'primary',
          high: 'warning',
          urgent: 'alert',
        }[p] || 'secondary'
      );
    },
    // @tickets_cases P1 — punto de color por prioridad (para el dropdown rápido).
    priorityDot(p) {
      return (
        {
          low: 'bg-slate-400',
          medium: 'bg-blue-500',
          high: 'bg-yellow-500',
          urgent: 'bg-red-500',
        }[p] || 'bg-slate-400'
      );
    },
    slaBadge(sla) {
      return (
        {
          on_time:
            'bg-green-100 text-green-800 dark:bg-green-900 dark:text-green-300',
          at_risk:
            'bg-yellow-100 text-yellow-800 dark:bg-yellow-900 dark:text-yellow-300',
          overdue: 'bg-red-100 text-red-800 dark:bg-red-900 dark:text-red-300',
        }[sla] ||
        'bg-green-100 text-green-800 dark:bg-green-900 dark:text-green-300'
      );
    },
    slaInfoColor(sla) {
      return (
        {
          on_time: 'text-slate-700 dark:text-slate-200',
          at_risk: 'text-yellow-600 dark:text-yellow-400',
          overdue: 'text-red-600 dark:text-red-400',
        }[sla] || 'text-slate-700 dark:text-slate-200'
      );
    },
    statusLabel(key) {
      return this.$t(`CASE_TICKETS.STATUSES.${key}`) || key;
    },
    // Modo simple: colapsa el estado ITIL a su etiqueta simple para mostrar.
    displayStatus(status) {
      return this.itilEnabled ? status : toSimpleStatus(status);
    },
    priorityLabel(key) {
      return this.$t(`CASE_TICKETS.PRIORITIES.${key}`) || key;
    },
    // @tickets_cases — etiqueta del canal/origen del ticket
    originLabel(key) {
      return this.$t(`CASE_TICKETS.ORIGINS.${key}`) || key || '—';
    },
    formatDate(d) {
      if (!d) return '';
      return new Date(d).toLocaleString(undefined, {
        day: '2-digit',
        month: '2-digit',
        year: 'numeric',
        hour: '2-digit',
        minute: '2-digit',
      });
    },
  },
};
</script>

<template>
  <div
    class="flex flex-col flex-1 w-full h-full overflow-hidden bg-slate-25 dark:bg-slate-900"
  >
    <!-- Header -->
    <div
      class="flex flex-col flex-shrink-0 gap-2 px-6 py-4 bg-white border-b dark:bg-slate-900 border-slate-50 dark:border-slate-800/50"
    >
      <woot-button
        size="small"
        variant="clear"
        color-scheme="secondary"
        icon="arrow-left"
        class="self-start"
        @click="$router.push({ name: 'gestorTickets_index' })"
      >
        Volver
      </woot-button>

      <div v-if="ticket" class="flex items-start justify-between gap-4">
        <div class="flex flex-col gap-1 min-w-0">
          <!-- @tickets_cases — folio primero y prominente + contacto a su derecha -->
          <div class="flex items-baseline gap-2 min-w-0">
            <span
              v-if="ticket.folio"
              class="font-mono text-lg font-bold leading-none tracking-wider text-woot-600 dark:text-woot-300 flex-shrink-0"
              >#{{ ticket.folio }}</span
            >
            <span
              v-if="ticket.contact_name"
              class="text-base font-medium truncate text-slate-600 dark:text-slate-300"
              >· {{ ticket.contact_name }}</span
            >
          </div>
          <!-- @tickets_cases — cada badge lleva su etiqueta (Tipo/Estado/Prioridad/
               SLA/Nivel) para que se entienda qué representa cada valor. -->
          <div class="flex flex-wrap gap-1 mt-1">
            <span
              v-if="ticket.case_type"
              class="px-1.5 py-0.5 text-[11px] font-medium uppercase tracking-wide rounded text-white"
              :style="{ backgroundColor: ticket.case_type.color }"
              ><span class="font-normal opacity-75">Tipo:</span>
              {{ ticket.case_type.name }}</span
            >
            <span
              class="px-1.5 py-0.5 text-[11px] font-medium uppercase tracking-wide rounded bg-slate-100 text-slate-800 dark:bg-slate-700 dark:text-slate-300"
              ><span class="font-normal opacity-75">Estado:</span>
              {{ statusLabel(displayStatus(ticket.status)) }}</span
            >
            <!-- Prioridad no va aquí: ya se ve (con color) en el botón "Prioridad". -->
            <span
              class="px-1.5 py-0.5 text-[11px] font-medium uppercase tracking-wide rounded"
              :class="slaBadge(ticket.sla_status)"
              >{{
                ticket.sla_status === 'overdue' ? slaText : 'SLA: ' + slaText
              }}</span
            >
            <span
              class="px-1.5 py-0.5 text-[11px] font-medium uppercase tracking-wide rounded bg-purple-100 text-purple-800 dark:bg-purple-900 dark:text-purple-300"
              :title="$t('CASE_TICKETS.ESCALATION.LEVEL_TITLE')"
              ><span class="font-normal opacity-75">Nivel:</span>
              {{ escalationLabel }}</span
            >
          </div>
          <h2 class="m-0 text-xl font-bold text-slate-800 dark:text-slate-100">
            {{ ticket.title }}
          </h2>
          <p
            v-if="ticket.description"
            class="m-0 text-sm text-slate-600 dark:text-slate-300"
          >
            {{ ticket.description }}
          </p>
        </div>

        <!-- @tickets_cases — columna derecha: acciones arriba + fechas debajo -->
        <div class="flex flex-col items-end flex-shrink-0 gap-3">
          <!-- Acciones (barra accionable inline — estilo osTicket) -->
          <div
            v-on-clickaway="closeActionMenus"
            class="relative flex flex-wrap items-center justify-end gap-2"
          >
            <!-- Tomar (claim): autoasignar al agente actual en 1 clic -->
            <woot-button
              v-if="canClaim"
              size="small"
              variant="smooth"
              color-scheme="secondary"
              icon="person-add"
              :is-loading="isTransitioning"
              @click="claimTicket"
            >
              {{ $t('CASE_TICKETS.CLAIM.BUTTON') }}
            </woot-button>

            <!-- Prioridad: dropdown inline -->
            <div class="relative">
              <woot-button
                size="small"
                variant="smooth"
                :color-scheme="priorityScheme(ticket.priority)"
                icon="chevron-down"
                @click="
                  showPriorityMenu = !showPriorityMenu;
                  showTransitionMenu = false;
                "
              >
                {{ $t('CASE_TICKETS.PRIORITY_QUICK.LABEL') }}:
                {{ priorityLabel(ticket.priority) }}
              </woot-button>
              <ul
                v-if="showPriorityMenu"
                class="absolute right-0 z-50 py-1 mt-1 list-none bg-white border rounded-md shadow-md dark:bg-slate-800 border-slate-100 dark:border-slate-700 min-w-[160px]"
              >
                <li
                  v-for="p in priorityOptions"
                  :key="p"
                  class="flex items-center gap-2 px-4 py-2 text-sm cursor-pointer text-slate-600 dark:text-slate-300 hover:bg-slate-50 dark:hover:bg-slate-700"
                  @click="setPriority(p)"
                >
                  <span class="w-2 h-2 rounded-full" :class="priorityDot(p)" />
                  {{ priorityLabel(p) }}
                  <fluent-icon
                    v-if="p === ticket.priority"
                    icon="checkmark"
                    size="14"
                    class="ml-auto text-woot-500"
                  />
                </li>
              </ul>
            </div>

            <!-- @tickets_cases P4 — Vencimiento inline (osTicket "Due Date") -->
            <div class="relative">
              <woot-button
                size="small"
                variant="smooth"
                :color-scheme="ticket.due_overdue ? 'alert' : 'secondary'"
                icon="calendar-clock"
                @click="openDueMenu"
              >
                {{ $t('CASE_TICKETS.DUE_QUICK.LABEL') }}: {{ dueLabel }}
              </woot-button>
              <div
                v-if="showDueMenu"
                class="absolute right-0 z-50 p-3 mt-1 bg-white border rounded-md shadow-md dark:bg-slate-800 border-slate-100 dark:border-slate-700 min-w-[240px]"
              >
                <input
                  v-model="dueDraft"
                  type="datetime-local"
                  class="w-full mb-2 text-sm"
                />
                <div class="flex items-center justify-between gap-2">
                  <button
                    type="button"
                    class="text-xs text-red-600 hover:underline dark:text-red-400 disabled:opacity-40"
                    :disabled="!ticket.due_at"
                    @click="clearDueAt"
                  >
                    {{ $t('CASE_TICKETS.DUE_QUICK.CLEAR') }}
                  </button>
                  <woot-button
                    size="tiny"
                    color-scheme="primary"
                    @click="saveDueAt"
                  >
                    {{ $t('CASE_TICKETS.DUE_QUICK.SAVE') }}
                  </woot-button>
                </div>
                <p
                  class="mt-2 mb-0 text-[11px] text-slate-400 dark:text-slate-500"
                >
                  {{ $t('CASE_TICKETS.DUE_QUICK.HINT') }}
                </p>
              </div>
            </div>

            <!-- @tickets_cases — Vincular ticket, entre Vence y Escalar -->
            <woot-button
              size="small"
              variant="smooth"
              color-scheme="secondary"
              icon="link"
              @click="openRelationModal"
            >
              {{ $t('CASE_TICKETS.RELATIONS.ADD') }}
            </woot-button>

            <woot-button
              v-if="canEscalate"
              size="small"
              variant="smooth"
              color-scheme="warning"
              icon="arrow-trending-lines"
              @click="openEscalate"
            >
              {{ $t('CASE_TICKETS.ESCALATION.BUTTON') }}
            </woot-button>
            <woot-button
              size="small"
              color-scheme="primary"
              :is-loading="isTransitioning"
              @click="
                showTransitionMenu = !showTransitionMenu;
                showPriorityMenu = false;
              "
            >
              {{ $t('CASE_TICKETS.STATUS_QUICK.LABEL') }} ▾
            </woot-button>
            <ul
              v-if="showTransitionMenu"
              class="absolute right-0 z-50 py-1 mt-1 list-none bg-white border rounded-md shadow-md dark:bg-slate-800 border-slate-100 dark:border-slate-700 min-w-[180px]"
            >
              <li
                v-for="s in validTransitions"
                :key="s"
                class="px-4 py-2 text-sm cursor-pointer text-slate-600 dark:text-slate-300 hover:bg-slate-50 dark:hover:bg-slate-700"
                @click="transitionTo(s)"
              >
                {{ statusLabel(s) }}
              </li>
              <li
                v-if="!validTransitions.length"
                class="px-4 py-2 text-sm text-slate-400 dark:text-slate-500"
              >
                Sin transiciones disponibles
              </li>
            </ul>
          </div>
          <!-- Fechas + asignación: siempre visibles, son parte de la ficha del
               ticket (no dependen de la pestaña). 'Vence' no va aquí: ya está en
               el botón de vencimiento. -->
          <div class="flex flex-col items-end gap-3">
            <!-- Asignación con el dropdown nativo de Chatwoot (avatar + buscador) -->
            <div class="grid w-[28rem] max-w-full grid-cols-2 gap-x-4 gap-y-1">
              <div class="flex flex-col gap-1 text-left">
                <label
                  class="text-xs tracking-wide uppercase text-slate-400 dark:text-slate-500"
                  >{{ $t('CASE_TICKETS.ASSIGN.TEAM_LABEL') }}</label
                >
                <MultiselectDropdown
                  :options="teamsList"
                  :selected-item="assignedTeamItem"
                  :has-thumbnail="false"
                  :multiselector-title="$t('CASE_TICKETS.ASSIGN.TEAM_LABEL')"
                  :multiselector-placeholder="$t('CASE_TICKETS.ASSIGN.NONE')"
                  :no-search-result="
                    $t('AGENT_MGMT.MULTI_SELECTOR.SEARCH.NO_RESULTS.TEAM')
                  "
                  :input-placeholder="
                    $t('AGENT_MGMT.MULTI_SELECTOR.SEARCH.PLACEHOLDER.INPUT')
                  "
                  @click="onSelectTeam"
                />
              </div>
              <div class="flex flex-col gap-1 text-left">
                <label
                  class="text-xs tracking-wide uppercase text-slate-400 dark:text-slate-500"
                  >{{ $t('CASE_TICKETS.ASSIGN.AGENT_LABEL') }}</label
                >
                <MultiselectDropdown
                  :options="agentsList"
                  :selected-item="assignedAgentItem"
                  :multiselector-title="$t('CASE_TICKETS.ASSIGN.AGENT_LABEL')"
                  :multiselector-placeholder="$t('CASE_TICKETS.ASSIGN.NONE')"
                  :no-search-result="
                    $t('AGENT_MGMT.MULTI_SELECTOR.SEARCH.NO_RESULTS.AGENT')
                  "
                  :input-placeholder="
                    $t('AGENT_MGMT.MULTI_SELECTOR.SEARCH.PLACEHOLDER.AGENT')
                  "
                  @click="onSelectAgent"
                />
              </div>
            </div>
            <!-- Solicitante (tickets internos) -->
            <div
              v-if="ticket.is_internal && ticket.requester"
              class="flex flex-col gap-0.5 text-right"
            >
              <span
                class="text-xs tracking-wide uppercase text-slate-400 dark:text-slate-500"
                >{{ $t('CASE_TICKETS.INTERNAL.REQUESTER_LABEL') }}</span
              >
              <span
                class="text-sm font-medium text-slate-700 dark:text-slate-200"
                >{{ ticket.requester.name }}</span
              >
            </div>
          </div>
        </div>
      </div>
    </div>

    <!-- Pestañas del detalle (pinneadas, no scrollean) -->
    <!-- @tickets_cases — bloqueo: aviso si otro agente está trabajando el ticket -->
    <div
      v-if="ticket && lockedByOther"
      class="flex items-center gap-2 px-6 py-2 text-sm flex-shrink-0 bg-amber-50 text-amber-800 border-b border-amber-100 dark:bg-amber-900/30 dark:text-amber-200 dark:border-amber-900/50"
    >
      <fluent-icon icon="lock-closed" size="16" />
      <span>{{
        $t('CASE_TICKETS.LOCK.BANNER', { name: ticket.locked_by.name })
      }}</span>
    </div>

    <div
      v-if="ticket"
      class="flex-shrink-0 px-6 bg-white border-b dark:bg-slate-900 border-slate-50 dark:border-slate-800/50"
    >
      <woot-tabs :index="activeDetailTabIndex" @change="onDetailTabChange">
        <woot-tabs-item
          v-for="(t, i) in detailTabs"
          :key="t.key"
          :index="i"
          :name="t.label"
          :count="t.count || 0"
          :show-badge="!!t.count"
        />
      </woot-tabs>
    </div>

    <!-- Loading -->
    <div
      v-if="!ticket && isFetchingList"
      class="flex items-center justify-center flex-1 text-slate-400 dark:text-slate-500"
    >
      <span>Cargando ticket...</span>
    </div>

    <div
      v-else-if="ticket"
      class="flex flex-col flex-1 gap-6 p-6 overflow-y-auto"
    >
      <!-- ════ Pestaña Resumen (P2): conversación al frente + sidebar de datos ════ -->
      <div
        v-show="currentTabKey === 'detail'"
        class="flex flex-col gap-6 xl:flex-row xl:items-start"
      >
        <!-- Hilo de conversación (protagonista, sticky en pantallas anchas) -->
        <div
          v-if="ticket.conversation_display_id"
          class="xl:flex-1 xl:min-w-0 xl:sticky xl:top-0"
        >
          <div class="h-[60vh] xl:h-[calc(100vh-21rem)]">
            <TicketConversation
              ref="ticketConversation"
              :key="ticket.conversation_display_id"
              :conversation-id="ticket.conversation_display_id"
              class="h-full"
            />
          </div>
        </div>

        <!-- Sidebar: datos del ticket (toma todo el ancho si no hay conversación) -->
        <div
          class="flex flex-col min-w-0 gap-6"
          :class="
            ticket.conversation_display_id
              ? 'xl:w-[400px] xl:flex-shrink-0'
              : 'flex-1'
          "
        >
          <!-- Sugerencia de clasificación IA (3B, modo suggest) -->
          <div
            v-if="aiSuggestion"
            class="p-4 border rounded-lg bg-violet-50 border-violet-200 dark:bg-violet-900/20 dark:border-violet-800"
          >
            <div class="flex items-start justify-between gap-3 mb-3">
              <div class="flex items-center gap-2">
                <fluent-icon
                  icon="wand"
                  size="18"
                  class="text-violet-600 dark:text-violet-300"
                />
                <span
                  class="text-sm font-semibold text-violet-800 dark:text-violet-200"
                  >{{ $t('CASE_TICKETS.AI.SUGGESTION.TITLE') }}</span
                >
                <span
                  v-if="aiConfidencePct !== null"
                  class="px-1.5 py-0.5 text-[10px] font-medium rounded-full bg-violet-100 text-violet-700 dark:bg-violet-800 dark:text-violet-100"
                  >{{
                    $t('CASE_TICKETS.AI.SUGGESTION.CONFIDENCE', {
                      pct: aiConfidencePct,
                    })
                  }}</span
                >
              </div>
            </div>
            <div class="grid grid-cols-2 gap-x-4 gap-y-2 mb-3">
              <div
                v-for="row in aiSuggestionRows"
                :key="row.label"
                class="flex flex-col gap-0.5"
              >
                <span
                  class="text-xs tracking-wide uppercase text-violet-400 dark:text-violet-500"
                  >{{ row.label }}</span
                >
                <span
                  class="text-sm font-medium text-violet-800 dark:text-violet-100"
                  >{{ row.value }}</span
                >
              </div>
            </div>
            <p
              v-if="aiSuggestion.reasoning"
              class="m-0 mb-3 text-xs italic text-violet-600 dark:text-violet-300"
            >
              {{ aiSuggestion.reasoning }}
            </p>
            <div class="flex justify-end gap-2">
              <woot-button
                size="small"
                variant="clear"
                color-scheme="secondary"
                @click="dismissAiSuggestion"
              >
                {{ $t('CASE_TICKETS.AI.SUGGESTION.DISMISS') }}
              </woot-button>
              <woot-button
                size="small"
                icon="checkmark"
                @click="applyAiSuggestion"
              >
                {{ $t('CASE_TICKETS.AI.SUGGESTION.APPLY') }}
              </woot-button>
            </div>
          </div>

          <!-- Campos personalizados (2K) -->
          <div
            v-if="customFieldRows.length"
            v-show="currentTabKey === 'detail'"
            class="p-4 bg-white border rounded-lg dark:bg-slate-800 border-slate-75 dark:border-slate-700"
          >
            <h3
              class="mb-4 text-base font-semibold text-slate-800 dark:text-slate-100"
            >
              {{ $t('CASE_TICKETS.CUSTOM_FIELDS.DETAIL_TITLE') }}
            </h3>
            <div class="grid grid-cols-2 gap-4">
              <div
                v-for="row in customFieldRows"
                :key="row.key"
                class="flex flex-col gap-0.5"
              >
                <span
                  class="text-xs tracking-wide uppercase text-slate-400 dark:text-slate-500"
                  >{{ row.label }}</span
                >
                <span
                  class="text-sm font-medium text-slate-700 dark:text-slate-200"
                  >{{ row.value }}</span
                >
              </div>
            </div>
          </div>

          <!-- Cierre documentado (2G) -->
          <div
            v-if="isClosed"
            v-show="currentTabKey === 'detail'"
            class="p-4 bg-white border rounded-lg dark:bg-slate-800 border-slate-75 dark:border-slate-700"
          >
            <h3
              class="mb-4 text-base font-semibold text-slate-800 dark:text-slate-100"
            >
              {{ $t('CASE_TICKETS.CLOSURE.TITLE') }}
            </h3>
            <div class="grid grid-cols-2 gap-4">
              <div class="flex flex-col gap-0.5">
                <span
                  class="text-xs tracking-wide uppercase text-slate-400 dark:text-slate-500"
                  >{{ $t('CASE_TICKETS.CLOSURE.TYPE') }}</span
                >
                <span
                  class="text-sm font-medium text-slate-700 dark:text-slate-200"
                  >{{
                    ticket.closure_type
                      ? closureTypeLabel(ticket.closure_type)
                      : '—'
                  }}</span
                >
              </div>
              <div class="flex flex-col gap-0.5">
                <span
                  class="text-xs tracking-wide uppercase text-slate-400 dark:text-slate-500"
                  >{{ $t('CASE_TICKETS.CLOSURE.CUSTOMER_CONFIRMED') }}</span
                >
                <span
                  class="text-sm font-medium text-slate-700 dark:text-slate-200"
                  >{{
                    ticket.customer_confirmed
                      ? $t('CASE_TICKETS.CLOSURE.YES')
                      : $t('CASE_TICKETS.CLOSURE.NO')
                  }}</span
                >
              </div>
              <div class="flex flex-col col-span-2 gap-0.5">
                <span
                  class="text-xs tracking-wide uppercase text-slate-400 dark:text-slate-500"
                  >{{ $t('CASE_TICKETS.CLOSURE.CAUSE') }}</span
                >
                <span class="text-sm text-slate-700 dark:text-slate-200">{{
                  ticket.closure_cause || '—'
                }}</span>
              </div>
              <div class="flex flex-col col-span-2 gap-0.5">
                <span
                  class="text-xs tracking-wide uppercase text-slate-400 dark:text-slate-500"
                  >{{ $t('CASE_TICKETS.CLOSURE.SOLUTION') }}</span
                >
                <span class="text-sm text-slate-700 dark:text-slate-200">{{
                  ticket.closure_solution || '—'
                }}</span>
              </div>
            </div>

            <!-- 2H — artículo de base de conocimiento -->
            <div
              class="flex items-center justify-between pt-4 mt-4 border-t border-slate-75 dark:border-slate-700"
            >
              <div
                v-if="ticket.kb_article"
                class="flex items-center min-w-0 gap-2 text-sm"
              >
                <fluent-icon icon="book" size="16" class="text-woot-500" />
                <span
                  class="font-medium text-slate-700 dark:text-slate-200 truncate"
                  >{{ ticket.kb_article.title }}</span
                >
                <span
                  class="px-1.5 py-0.5 text-[11px] uppercase rounded bg-slate-100 text-slate-600 dark:bg-slate-700 dark:text-slate-300"
                  >{{ articleStatusLabel(ticket.kb_article.status) }}</span
                >
              </div>
              <span v-else class="text-sm text-slate-400 dark:text-slate-500">{{
                $t('CASE_TICKETS.KB.NONE')
              }}</span>
              <woot-button
                v-if="!ticket.kb_article"
                size="tiny"
                variant="smooth"
                color-scheme="secondary"
                icon="book"
                @click="openArticleModal"
              >
                {{ $t('CASE_TICKETS.KB.GENERATE') }}
              </woot-button>
            </div>
          </div>

          <!-- Detalles de Problema (2F) -->
          <div
            v-if="isProblem"
            v-show="currentTabKey === 'detail'"
            class="p-4 bg-white border rounded-lg dark:bg-slate-800 border-slate-75 dark:border-slate-700"
          >
            <div class="flex items-center justify-between mb-4">
              <h3
                class="m-0 text-base font-semibold text-slate-800 dark:text-slate-100"
              >
                {{ $t('CASE_TICKETS.PROBLEM.TITLE') }}
              </h3>
              <woot-button
                size="tiny"
                variant="smooth"
                color-scheme="secondary"
                icon="edit"
                @click="openDetailsModal"
              >
                {{ $t('CASE_TICKETS.PROBLEM.EDIT') }}
              </woot-button>
            </div>
            <div class="grid grid-cols-1 gap-4">
              <div class="flex flex-col gap-0.5">
                <span
                  class="text-xs tracking-wide uppercase text-slate-400 dark:text-slate-500"
                  >{{ $t('CASE_TICKETS.PROBLEM.ROOT_CAUSE') }}</span
                >
                <span class="text-sm text-slate-700 dark:text-slate-200">{{
                  changeAttrs.root_cause || '—'
                }}</span>
              </div>
              <div class="flex flex-col gap-0.5">
                <span
                  class="text-xs tracking-wide uppercase text-slate-400 dark:text-slate-500"
                  >{{ $t('CASE_TICKETS.PROBLEM.WORKAROUND') }}</span
                >
                <span class="text-sm text-slate-700 dark:text-slate-200">{{
                  changeAttrs.workaround || '—'
                }}</span>
              </div>
            </div>
          </div>

          <!-- Detalles de Cambio (2F) -->
          <div
            v-if="isChange"
            v-show="currentTabKey === 'detail'"
            class="p-4 bg-white border rounded-lg dark:bg-slate-800 border-slate-75 dark:border-slate-700"
          >
            <div class="flex items-center justify-between mb-4">
              <h3
                class="m-0 text-base font-semibold text-slate-800 dark:text-slate-100"
              >
                {{ $t('CASE_TICKETS.CHANGE.TITLE') }}
              </h3>
              <div class="flex gap-2">
                <woot-button
                  v-if="changeApprovalStatus !== 'approved'"
                  size="tiny"
                  variant="smooth"
                  color-scheme="success"
                  icon="checkmark"
                  @click="approveChange"
                >
                  {{ $t('CASE_TICKETS.CHANGE.APPROVE') }}
                </woot-button>
                <woot-button
                  v-if="changeApprovalStatus !== 'rejected'"
                  size="tiny"
                  variant="smooth"
                  color-scheme="alert"
                  icon="dismiss"
                  @click="openRejectModal"
                >
                  {{ $t('CASE_TICKETS.CHANGE.REJECT') }}
                </woot-button>
                <woot-button
                  size="tiny"
                  variant="smooth"
                  color-scheme="secondary"
                  icon="edit"
                  @click="openDetailsModal"
                >
                  {{ $t('CASE_TICKETS.CHANGE.EDIT') }}
                </woot-button>
              </div>
            </div>
            <div class="grid grid-cols-2 gap-4">
              <div class="flex flex-col gap-0.5">
                <span
                  class="text-xs tracking-wide uppercase text-slate-400 dark:text-slate-500"
                  >{{ $t('CASE_TICKETS.CHANGE.APPROVAL_STATUS') }}</span
                >
                <span
                  class="self-start px-1.5 py-0.5 text-[11px] font-medium uppercase tracking-wide rounded"
                  :class="approvalBadge(changeApprovalStatus)"
                  >{{ approvalLabel(changeApprovalStatus) }}</span
                >
              </div>
              <div class="flex flex-col gap-0.5">
                <span
                  class="text-xs tracking-wide uppercase text-slate-400 dark:text-slate-500"
                  >{{ $t('CASE_TICKETS.CHANGE.RISK_LEVEL') }}</span
                >
                <span
                  class="text-sm font-medium text-slate-700 dark:text-slate-200"
                  >{{
                    changeAttrs.risk_level
                      ? riskLabel(changeAttrs.risk_level)
                      : '—'
                  }}</span
                >
              </div>
              <div class="flex flex-col gap-0.5">
                <span
                  class="text-xs tracking-wide uppercase text-slate-400 dark:text-slate-500"
                  >{{ $t('CASE_TICKETS.CHANGE.SCHEDULED_WINDOW') }}</span
                >
                <span class="text-sm text-slate-700 dark:text-slate-200">{{
                  changeAttrs.scheduled_window || '—'
                }}</span>
              </div>
              <div class="flex flex-col gap-0.5">
                <span
                  class="text-xs tracking-wide uppercase text-slate-400 dark:text-slate-500"
                  >{{ $t('CASE_TICKETS.CHANGE.REQUIRES_APPROVAL') }}</span
                >
                <span class="text-sm text-slate-700 dark:text-slate-200">{{
                  changeAttrs.requires_approval
                    ? $t('CASE_TICKETS.CHANGE.YES')
                    : $t('CASE_TICKETS.CHANGE.NO')
                }}</span>
              </div>
              <div class="flex flex-col col-span-2 gap-0.5">
                <span
                  class="text-xs tracking-wide uppercase text-slate-400 dark:text-slate-500"
                  >{{ $t('CASE_TICKETS.CHANGE.ROLLBACK_PLAN') }}</span
                >
                <span class="text-sm text-slate-700 dark:text-slate-200">{{
                  changeAttrs.rollback_plan || '—'
                }}</span>
              </div>
            </div>
          </div>

          <!-- Tickets relacionados (2E) — solo si hay vínculos; vincular se hace
               desde el botón de la barra de acciones. -->
          <div
            v-if="relations.length"
            v-show="currentTabKey === 'detail'"
            class="p-4 bg-white border rounded-lg dark:bg-slate-800 border-slate-75 dark:border-slate-700"
          >
            <div class="mb-4">
              <h3
                class="m-0 text-base font-semibold text-slate-800 dark:text-slate-100"
              >
                {{ $t('CASE_TICKETS.RELATIONS.TITLE') }}
              </h3>
            </div>

            <ul class="flex flex-col gap-2 p-0 m-0 list-none">
              <li
                v-for="rel in relations"
                :key="rel.id"
                class="flex items-center justify-between gap-3 px-3 py-2 border rounded-md border-slate-75 dark:border-slate-700"
              >
                <div class="flex items-center min-w-0 gap-2">
                  <span
                    class="px-1.5 py-0.5 text-[11px] font-medium uppercase tracking-wide rounded bg-indigo-100 text-indigo-800 dark:bg-indigo-900 dark:text-indigo-300 flex-shrink-0"
                    >{{ relationLabel(rel) }}</span
                  >
                  <button
                    class="font-mono text-xs text-woot-500 hover:underline flex-shrink-0"
                    @click="openRelatedTicket(rel.ticket.id)"
                  >
                    {{ rel.ticket.folio || `#${rel.ticket.id}` }}
                  </button>
                  <span
                    class="text-sm truncate text-slate-600 dark:text-slate-300"
                    >{{ rel.ticket.title }}</span
                  >
                </div>
                <woot-button
                  size="tiny"
                  variant="clear"
                  color-scheme="secondary"
                  icon="dismiss"
                  @click="openDeleteRelation(rel)"
                />
              </li>
            </ul>
          </div>
          <!-- /tarjeta de tickets relacionados -->
        </div>
        <!-- /sidebar de datos -->
      </div>
      <!-- /Resumen: dos columnas -->

      <!-- ════ Pestaña IA: Respuesta sugerida desde KB (3C) ════ -->
      <div
        v-if="replyEnabled"
        v-show="currentTabKey === 'ai'"
        class="p-4 bg-white border rounded-lg dark:bg-slate-800 border-slate-75 dark:border-slate-700"
      >
        <div class="flex items-center justify-between gap-2 mb-3">
          <div class="flex items-center gap-2">
            <fluent-icon
              icon="wand"
              size="18"
              class="text-teal-600 dark:text-teal-300"
            />
            <h3
              class="m-0 text-base font-semibold text-slate-800 dark:text-slate-100"
            >
              {{ $t('CASE_TICKETS.AI.REPLY.TITLE') }}
            </h3>
          </div>
          <woot-button
            size="small"
            variant="smooth"
            icon="wand"
            :is-loading="isSuggestingReply"
            @click="generateReply"
          >
            {{
              replySuggestion
                ? $t('CASE_TICKETS.AI.REPLY.REGENERATE')
                : $t('CASE_TICKETS.AI.REPLY.GENERATE')
            }}
          </woot-button>
        </div>

        <p
          v-if="!replySuggestion && !isSuggestingReply"
          class="m-0 text-sm text-slate-400 dark:text-slate-500"
        >
          {{ $t('CASE_TICKETS.AI.REPLY.HINT') }}
        </p>

        <template v-if="replySuggestion">
          <p
            v-if="replySuggestion.no_context"
            class="m-0 text-sm text-amber-600 dark:text-amber-400"
          >
            {{ $t('CASE_TICKETS.AI.REPLY.NO_CONTEXT') }}
          </p>
          <template v-else>
            <div
              class="p-3 text-sm whitespace-pre-line rounded-lg bg-teal-50 text-slate-700 dark:bg-teal-900/20 dark:text-slate-200"
            >
              {{ replySuggestion.reply }}
            </div>
            <div
              v-if="replySuggestion.sources && replySuggestion.sources.length"
              class="flex flex-wrap items-center gap-1.5 mt-2"
            >
              <span class="text-xs text-slate-400 dark:text-slate-500"
                >{{ $t('CASE_TICKETS.AI.REPLY.SOURCES') }}:</span
              >
              <span
                v-for="(src, idx) in replySuggestion.sources"
                :key="idx"
                class="px-1.5 py-0.5 text-xs rounded bg-slate-100 text-slate-600 dark:bg-slate-700 dark:text-slate-300"
                >{{ src.title }}</span
              >
            </div>
            <div class="flex justify-end gap-2 mt-3">
              <woot-button
                v-if="ticket.conversation_display_id"
                size="small"
                variant="smooth"
                icon="arrow-reply"
                @click="useReplyInConversation"
              >
                {{ $t('CASE_TICKETS.AI.REPLY.USE_IN_CONVERSATION') }}
              </woot-button>
              <woot-button
                size="small"
                variant="clear"
                :icon="replyCopied ? 'checkmark' : 'copy'"
                @click="copyReply"
              >
                {{
                  replyCopied
                    ? $t('CASE_TICKETS.AI.REPLY.COPIED_BTN')
                    : $t('CASE_TICKETS.AI.REPLY.COPY')
                }}
              </woot-button>
            </div>
          </template>
        </template>
      </div>

      <!-- Resumen + causa raíz (3E) -->
      <div
        v-if="summarizeEnabled"
        v-show="currentTabKey === 'ai'"
        class="p-4 bg-white border rounded-lg dark:bg-slate-800 border-slate-75 dark:border-slate-700"
      >
        <div class="flex items-center justify-between gap-2 mb-3">
          <div class="flex items-center gap-2">
            <fluent-icon
              icon="wand"
              size="18"
              class="text-indigo-600 dark:text-indigo-300"
            />
            <h3
              class="m-0 text-base font-semibold text-slate-800 dark:text-slate-100"
            >
              {{ $t('CASE_TICKETS.AI.SUMMARY.TITLE') }}
            </h3>
          </div>
          <woot-button
            size="small"
            variant="smooth"
            icon="wand"
            :is-loading="isSummarizing"
            @click="generateSummary"
          >
            {{
              summaryResult
                ? $t('CASE_TICKETS.AI.SUMMARY.REGENERATE')
                : $t('CASE_TICKETS.AI.SUMMARY.GENERATE')
            }}
          </woot-button>
        </div>
        <p
          v-if="!summaryResult && !isSummarizing"
          class="m-0 text-sm text-slate-400 dark:text-slate-500"
        >
          {{ $t('CASE_TICKETS.AI.SUMMARY.HINT') }}
        </p>
        <div v-if="summaryResult" class="flex flex-col gap-3">
          <div v-if="summaryResult.summary" class="flex flex-col gap-1">
            <span
              class="text-xs tracking-wide uppercase text-slate-400 dark:text-slate-500"
              >{{ $t('CASE_TICKETS.AI.SUMMARY.SUMMARY_LABEL') }}</span
            >
            <p class="m-0 text-sm text-slate-700 dark:text-slate-200">
              {{ summaryResult.summary }}
            </p>
          </div>
          <div v-if="summaryResult.root_cause" class="flex flex-col gap-1">
            <span
              class="text-xs tracking-wide uppercase text-slate-400 dark:text-slate-500"
              >{{ $t('CASE_TICKETS.AI.SUMMARY.ROOT_CAUSE_LABEL') }}</span
            >
            <p class="m-0 text-sm text-slate-700 dark:text-slate-200">
              {{ summaryResult.root_cause }}
            </p>
          </div>
          <div
            v-if="summaryResult.suggested_solution"
            class="flex flex-col gap-1"
          >
            <span
              class="text-xs tracking-wide uppercase text-slate-400 dark:text-slate-500"
              >{{ $t('CASE_TICKETS.AI.SUMMARY.SOLUTION_LABEL') }}</span
            >
            <p class="m-0 text-sm text-slate-700 dark:text-slate-200">
              {{ summaryResult.suggested_solution }}
            </p>
          </div>
        </div>
      </div>

      <!-- Detección de repetidos (3D) -->
      <div
        v-if="duplicateEnabled"
        v-show="currentTabKey === 'ai'"
        class="p-4 bg-white border rounded-lg dark:bg-slate-800 border-slate-75 dark:border-slate-700"
      >
        <div class="flex items-center justify-between gap-2 mb-3">
          <div class="flex items-center gap-2">
            <fluent-icon
              icon="wand"
              size="18"
              class="text-rose-600 dark:text-rose-300"
            />
            <h3
              class="m-0 text-base font-semibold text-slate-800 dark:text-slate-100"
            >
              {{ $t('CASE_TICKETS.AI.DUPLICATE.TITLE') }}
            </h3>
          </div>
          <woot-button
            size="small"
            variant="smooth"
            icon="wand"
            :is-loading="isDetectingDuplicates"
            @click="detectDuplicates"
          >
            {{
              duplicateResult
                ? $t('CASE_TICKETS.AI.DUPLICATE.RESCAN')
                : $t('CASE_TICKETS.AI.DUPLICATE.SCAN')
            }}
          </woot-button>
        </div>
        <p
          v-if="!duplicateResult && !isDetectingDuplicates"
          class="m-0 text-sm text-slate-400 dark:text-slate-500"
        >
          {{ $t('CASE_TICKETS.AI.DUPLICATE.HINT') }}
        </p>
        <template v-if="duplicateResult">
          <p
            v-if="!duplicateResult.matches.length"
            class="m-0 text-sm text-slate-400 dark:text-slate-500"
          >
            {{ $t('CASE_TICKETS.AI.DUPLICATE.NONE') }}
          </p>
          <template v-else>
            <div
              v-if="duplicateResult.suggest_problem"
              class="flex items-start gap-2 p-2.5 mb-3 text-sm rounded-lg bg-rose-50 text-rose-700 dark:bg-rose-900/20 dark:text-rose-300"
            >
              <fluent-icon
                icon="warning"
                size="16"
                class="mt-0.5 flex-shrink-0"
              />
              <span>{{ $t('CASE_TICKETS.AI.DUPLICATE.SUGGEST_PROBLEM') }}</span>
            </div>
            <div class="flex flex-col gap-2">
              <div
                v-for="m in duplicateResult.matches"
                :key="m.id"
                class="flex items-center gap-3 p-2.5 border rounded-lg border-slate-75 dark:border-slate-700 bg-slate-25 dark:bg-slate-800"
              >
                <span
                  class="px-1.5 py-0.5 text-xs font-medium rounded-full bg-rose-100 text-rose-700 dark:bg-rose-800 dark:text-rose-100"
                  >{{ Math.round(m.similarity * 100) }}%</span
                >
                <button
                  type="button"
                  class="flex-1 min-w-0 text-left"
                  @click="goToTicket(m.id)"
                >
                  <span
                    class="font-mono text-xs text-slate-400 dark:text-slate-500"
                    >{{ m.folio }}</span
                  >
                  <span
                    class="block text-sm truncate text-slate-700 dark:text-slate-200"
                    >{{ m.title }}</span
                  >
                </button>
                <woot-button
                  size="tiny"
                  variant="smooth"
                  icon="link"
                  :is-loading="linkingDuplicateId === m.id"
                  @click="linkDuplicate(m)"
                >
                  {{ $t('CASE_TICKETS.AI.DUPLICATE.LINK') }}
                </woot-button>
              </div>
            </div>
          </template>
        </template>
      </div>

      <!-- Seguimiento sugerido (3F) -->
      <div
        v-if="followUpEnabled"
        v-show="currentTabKey === 'ai'"
        class="p-4 bg-white border rounded-lg dark:bg-slate-800 border-slate-75 dark:border-slate-700"
      >
        <div class="flex items-center justify-between gap-2 mb-3">
          <div class="flex items-center gap-2">
            <fluent-icon
              icon="wand"
              size="18"
              class="text-emerald-600 dark:text-emerald-300"
            />
            <h3
              class="m-0 text-base font-semibold text-slate-800 dark:text-slate-100"
            >
              {{ $t('CASE_TICKETS.AI.FOLLOWUP.TITLE') }}
            </h3>
            <span
              v-if="pendingFollowUp && !followUpResult"
              class="px-1.5 py-0.5 text-[10px] font-medium rounded-full bg-emerald-100 text-emerald-700 dark:bg-emerald-800 dark:text-emerald-100"
              >{{ $t('CASE_TICKETS.AI.FOLLOWUP.AUTO_BADGE') }}</span
            >
          </div>
          <woot-button
            size="small"
            variant="smooth"
            icon="wand"
            :is-loading="isFollowingUp"
            @click="generateFollowUp"
          >
            {{
              followUpMessage
                ? $t('CASE_TICKETS.AI.FOLLOWUP.REGENERATE')
                : $t('CASE_TICKETS.AI.FOLLOWUP.GENERATE')
            }}
          </woot-button>
        </div>
        <p
          v-if="!followUpMessage && !isFollowingUp"
          class="m-0 text-sm text-slate-400 dark:text-slate-500"
        >
          {{ $t('CASE_TICKETS.AI.FOLLOWUP.HINT') }}
        </p>
        <template v-if="followUpMessage">
          <div
            class="p-3 text-sm whitespace-pre-line rounded-lg bg-emerald-50 text-slate-700 dark:bg-emerald-900/20 dark:text-slate-200"
          >
            {{ followUpMessage }}
          </div>
          <div class="flex justify-end mt-3">
            <woot-button
              size="small"
              variant="clear"
              :icon="followUpCopied ? 'checkmark' : 'copy'"
              @click="copyFollowUp"
            >
              {{
                followUpCopied
                  ? $t('CASE_TICKETS.AI.FOLLOWUP.COPIED_BTN')
                  : $t('CASE_TICKETS.AI.FOLLOWUP.COPY')
              }}
            </woot-button>
          </div>
        </template>
      </div>

      <!-- ════ Pestaña Tareas (P4) — checklist a ancho completo ════ -->
      <TicketTasks
        v-show="currentTabKey === 'tasks'"
        :key="`tasks-${ticket.id}`"
        :ticket-id="ticket.id"
        @count="taskCount = $event"
      />

      <!-- ════ Pestaña Avance del ticket (2L) — 3 vistas conmutables ════ -->
      <JourneyView
        v-show="currentTabKey === 'journey'"
        :events="events"
        :ticket="ticket"
        :is-fetching="isFetchingEvents"
      />
    </div>

    <!-- Modal de escalamiento (2D) -->
    <woot-modal
      v-if="showEscalateModal"
      :show="showEscalateModal"
      :on-close="() => (showEscalateModal = false)"
      size="small"
    >
      <div class="flex flex-col h-auto overflow-auto">
        <woot-modal-header
          :header-title="
            $t('CASE_TICKETS.ESCALATION.TITLE', { level: escalationLabel })
          "
        />
        <form
          class="flex flex-col self-stretch w-full gap-4 pb-8"
          @submit.prevent="confirmEscalate"
        >
          <p class="m-0 text-sm text-slate-600 dark:text-slate-300">
            {{ $t('CASE_TICKETS.ESCALATION.HELP') }}
          </p>
          <label class="flex flex-col gap-1">
            <span
              class="text-sm font-medium text-slate-700 dark:text-slate-200"
              >{{ $t('CASE_TICKETS.ESCALATION.TEAM_LABEL') }}</span
            >
            <select v-model="escalateForm.team_id" class="input">
              <option value="">
                {{ $t('CASE_TICKETS.ESCALATION.NO_TEAM') }}
              </option>
              <option v-for="tm in teams" :key="tm.id" :value="tm.id">
                {{ tm.name }}
              </option>
            </select>
          </label>
          <label class="flex flex-col gap-1">
            <span
              class="text-sm font-medium text-slate-700 dark:text-slate-200"
              >{{ $t('CASE_TICKETS.ESCALATION.REASON_LABEL') }}</span
            >
            <textarea
              v-model="escalateForm.reason"
              class="input"
              rows="3"
              :placeholder="$t('CASE_TICKETS.ESCALATION.REASON_PLACEHOLDER')"
            />
          </label>
          <div class="flex justify-end gap-2 mt-2">
            <woot-button
              variant="clear"
              color-scheme="secondary"
              type="button"
              @click="showEscalateModal = false"
            >
              {{ $t('CASE_TICKETS.ESCALATION.CANCEL') }}
            </woot-button>
            <woot-button
              type="submit"
              color-scheme="warning"
              :is-loading="isTransitioning"
            >
              {{ $t('CASE_TICKETS.ESCALATION.CONFIRM') }}
            </woot-button>
          </div>
        </form>
      </div>
    </woot-modal>

    <!-- Modal de relación (2E) -->
    <woot-modal
      v-if="showRelationModal"
      :show="showRelationModal"
      :on-close="() => (showRelationModal = false)"
      size="small"
    >
      <div class="flex flex-col h-auto overflow-auto">
        <woot-modal-header
          :header-title="$t('CASE_TICKETS.RELATIONS.MODAL_TITLE')"
        />
        <form
          class="flex flex-col self-stretch w-full gap-4 pb-8"
          @submit.prevent="confirmRelation"
        >
          <label class="flex flex-col gap-1">
            <span
              class="text-sm font-medium text-slate-700 dark:text-slate-200"
              >{{ $t('CASE_TICKETS.RELATIONS.TYPE_LABEL') }}</span
            >
            <select v-model="relationForm.relation_type" class="input">
              <option v-for="rt in relationTypeOptions" :key="rt" :value="rt">
                {{ relationTypeLabel(rt) }}
              </option>
            </select>
          </label>

          <label class="flex flex-col gap-1">
            <span
              class="text-sm font-medium text-slate-700 dark:text-slate-200"
              >{{ $t('CASE_TICKETS.RELATIONS.SEARCH_LABEL') }}</span
            >
            <input
              v-model="relationQuery"
              type="text"
              class="input"
              :placeholder="$t('CASE_TICKETS.RELATIONS.SEARCH_PLACEHOLDER')"
              @input="onRelationSearch"
            />
          </label>

          <div
            v-if="isSearchingTickets"
            class="text-sm text-slate-400 dark:text-slate-500"
          >
            {{ $t('CASE_TICKETS.RELATIONS.SEARCHING') }}
          </div>
          <ul
            v-else-if="relationResults.length"
            class="flex flex-col gap-1 p-0 m-0 overflow-y-auto list-none max-h-48"
          >
            <li
              v-for="r in relationResults"
              :key="r.id"
              class="flex items-center gap-2 px-3 py-2 text-sm rounded-md cursor-pointer hover:bg-slate-50 dark:hover:bg-slate-700"
              @click="selectRelationResult(r)"
            >
              <span class="font-mono text-xs text-slate-400">{{
                r.folio || `#${r.id}`
              }}</span>
              <span class="truncate text-slate-700 dark:text-slate-200">{{
                r.title
              }}</span>
            </li>
          </ul>
          <div
            v-else-if="relationQuery.length >= 2 && !relationSelected"
            class="text-sm text-slate-400 dark:text-slate-500"
          >
            {{ $t('CASE_TICKETS.RELATIONS.NO_RESULTS') }}
          </div>

          <div
            v-if="relationSelected"
            class="px-3 py-2 text-sm rounded-md bg-slate-50 dark:bg-slate-700/50 text-slate-700 dark:text-slate-200"
          >
            {{ $t('CASE_TICKETS.RELATIONS.SELECTED') }}
            <strong>{{
              relationSelected.folio || `#${relationSelected.id}`
            }}</strong>
            — {{ relationSelected.title }}
          </div>

          <div class="flex justify-end gap-2 mt-2">
            <woot-button
              variant="clear"
              color-scheme="secondary"
              type="button"
              @click="showRelationModal = false"
            >
              {{ $t('CASE_TICKETS.RELATIONS.CANCEL') }}
            </woot-button>
            <woot-button
              type="submit"
              color-scheme="primary"
              :disabled="!relationSelected"
              :is-loading="relationsUiFlags.isSaving"
            >
              {{ $t('CASE_TICKETS.RELATIONS.CONFIRM') }}
            </woot-button>
          </div>
        </form>
      </div>
    </woot-modal>

    <!-- Confirmar eliminación de relación (2E) -->
    <woot-delete-modal
      v-if="showDeleteRelation"
      :show="showDeleteRelation"
      :on-close="() => (showDeleteRelation = false)"
      :on-confirm="confirmDeleteRelation"
      :title="$t('CASE_TICKETS.RELATIONS.DELETE.TITLE')"
      :message="$t('CASE_TICKETS.RELATIONS.DELETE.MESSAGE')"
      :confirm-text="$t('CASE_TICKETS.RELATIONS.DELETE.YES')"
      :reject-text="$t('CASE_TICKETS.RELATIONS.DELETE.NO')"
    />

    <!-- Modal de detalles Problema/Cambio (2F) -->
    <woot-modal
      v-if="showDetailsModal"
      :show="showDetailsModal"
      :on-close="() => (showDetailsModal = false)"
      size="small"
    >
      <div class="flex flex-col h-auto overflow-auto">
        <woot-modal-header
          :header-title="
            isProblem
              ? $t('CASE_TICKETS.PROBLEM.MODAL_TITLE')
              : $t('CASE_TICKETS.CHANGE.MODAL_TITLE')
          "
        />
        <form
          class="flex flex-col self-stretch w-full gap-4 pb-8"
          @submit.prevent="saveDetails"
        >
          <!-- Problema -->
          <template v-if="isProblem">
            <label class="flex flex-col gap-1">
              <span
                class="text-sm font-medium text-slate-700 dark:text-slate-200"
                >{{ $t('CASE_TICKETS.PROBLEM.ROOT_CAUSE') }}</span
              >
              <textarea
                v-model="detailsForm.root_cause"
                class="input"
                rows="3"
              />
            </label>
            <label class="flex flex-col gap-1">
              <span
                class="text-sm font-medium text-slate-700 dark:text-slate-200"
                >{{ $t('CASE_TICKETS.PROBLEM.WORKAROUND') }}</span
              >
              <textarea
                v-model="detailsForm.workaround"
                class="input"
                rows="3"
              />
            </label>
          </template>
          <!-- Cambio -->
          <template v-else>
            <label class="flex flex-col gap-1">
              <span
                class="text-sm font-medium text-slate-700 dark:text-slate-200"
                >{{ $t('CASE_TICKETS.CHANGE.RISK_LEVEL') }}</span
              >
              <select v-model="detailsForm.risk_level" class="input">
                <option v-for="rl in riskLevelOptions" :key="rl" :value="rl">
                  {{ riskLabel(rl) }}
                </option>
              </select>
            </label>
            <label class="flex items-center gap-2">
              <input
                v-model="detailsForm.requires_approval"
                type="checkbox"
                class="m-0"
              />
              <span
                class="text-sm font-medium text-slate-700 dark:text-slate-200"
                >{{ $t('CASE_TICKETS.CHANGE.REQUIRES_APPROVAL') }}</span
              >
            </label>
            <label class="flex flex-col gap-1">
              <span
                class="text-sm font-medium text-slate-700 dark:text-slate-200"
                >{{ $t('CASE_TICKETS.CHANGE.SCHEDULED_WINDOW') }}</span
              >
              <input
                v-model="detailsForm.scheduled_window"
                type="text"
                class="input"
                :placeholder="
                  $t('CASE_TICKETS.CHANGE.SCHEDULED_WINDOW_PLACEHOLDER')
                "
              />
            </label>
            <label class="flex flex-col gap-1">
              <span
                class="text-sm font-medium text-slate-700 dark:text-slate-200"
                >{{ $t('CASE_TICKETS.CHANGE.ROLLBACK_PLAN') }}</span
              >
              <textarea
                v-model="detailsForm.rollback_plan"
                class="input"
                rows="3"
              />
            </label>
          </template>

          <div class="flex justify-end gap-2 mt-2">
            <woot-button
              variant="clear"
              color-scheme="secondary"
              type="button"
              @click="showDetailsModal = false"
            >
              {{ $t('CASE_TICKETS.PROBLEM.CANCEL') }}
            </woot-button>
            <woot-button
              type="submit"
              color-scheme="primary"
              :is-loading="isSavingDetails"
            >
              {{ $t('CASE_TICKETS.PROBLEM.SAVE') }}
            </woot-button>
          </div>
        </form>
      </div>
    </woot-modal>

    <!-- Modal rechazar cambio (2F) -->
    <woot-modal
      v-if="showRejectModal"
      :show="showRejectModal"
      :on-close="() => (showRejectModal = false)"
      size="small"
    >
      <div class="flex flex-col h-auto overflow-auto">
        <woot-modal-header
          :header-title="$t('CASE_TICKETS.CHANGE.REJECT_TITLE')"
        />
        <form
          class="flex flex-col self-stretch w-full gap-4 pb-8"
          @submit.prevent="confirmRejectChange"
        >
          <label class="flex flex-col gap-1">
            <span
              class="text-sm font-medium text-slate-700 dark:text-slate-200"
              >{{ $t('CASE_TICKETS.CHANGE.REJECT_REASON') }}</span
            >
            <textarea v-model="rejectReason" class="input" rows="3" />
          </label>
          <div class="flex justify-end gap-2 mt-2">
            <woot-button
              variant="clear"
              color-scheme="secondary"
              type="button"
              @click="showRejectModal = false"
            >
              {{ $t('CASE_TICKETS.CHANGE.CANCEL') }}
            </woot-button>
            <woot-button type="submit" color-scheme="alert">
              {{ $t('CASE_TICKETS.CHANGE.REJECT') }}
            </woot-button>
          </div>
        </form>
      </div>
    </woot-modal>

    <!-- Modal resolver problema con propagación (2F) -->
    <woot-modal
      v-if="showResolveProblemModal"
      :show="showResolveProblemModal"
      :on-close="() => (showResolveProblemModal = false)"
      size="small"
    >
      <div class="flex flex-col h-auto overflow-auto">
        <woot-modal-header
          :header-title="$t('CASE_TICKETS.PROBLEM.RESOLVE_TITLE')"
        />
        <form
          class="flex flex-col self-stretch w-full gap-4 pb-8"
          @submit.prevent="confirmResolveProblem"
        >
          <p class="m-0 text-sm text-slate-600 dark:text-slate-300">
            {{
              $t('CASE_TICKETS.PROBLEM.RESOLVE_HELP', {
                count: relatedIncidentsCount,
              })
            }}
          </p>
          <label class="flex items-center gap-2">
            <input v-model="propagateToIncidents" type="checkbox" class="m-0" />
            <span
              class="text-sm font-medium text-slate-700 dark:text-slate-200"
              >{{ $t('CASE_TICKETS.PROBLEM.PROPAGATE') }}</span
            >
          </label>
          <div class="flex justify-end gap-2 mt-2">
            <woot-button
              variant="clear"
              color-scheme="secondary"
              type="button"
              @click="showResolveProblemModal = false"
            >
              {{ $t('CASE_TICKETS.PROBLEM.CANCEL') }}
            </woot-button>
            <woot-button
              type="submit"
              color-scheme="success"
              :is-loading="isTransitioning"
            >
              {{ $t('CASE_TICKETS.PROBLEM.RESOLVE_CONFIRM') }}
            </woot-button>
          </div>
        </form>
      </div>
    </woot-modal>

    <!-- Modal de cierre documentado (2G) -->
    <woot-modal
      v-if="showCloseModal"
      :show="showCloseModal"
      :on-close="() => (showCloseModal = false)"
      size="small"
    >
      <div class="flex flex-col h-auto overflow-auto">
        <woot-modal-header
          :header-title="$t('CASE_TICKETS.CLOSURE.MODAL_TITLE')"
        />
        <form
          class="flex flex-col self-stretch w-full gap-4 pb-8"
          @submit.prevent="confirmClose"
        >
          <p class="m-0 text-sm text-slate-600 dark:text-slate-300">
            {{ $t('CASE_TICKETS.CLOSURE.HELP') }}
          </p>
          <woot-button
            v-if="summarizeEnabled"
            type="button"
            size="small"
            variant="smooth"
            icon="wand"
            class="self-start"
            :is-loading="isSummarizing"
            @click="suggestCloseWithAi"
          >
            {{ $t('CASE_TICKETS.AI.SUMMARY.SUGGEST_CLOSE') }}
          </woot-button>
          <label class="flex flex-col gap-1">
            <span class="text-sm font-medium text-slate-700 dark:text-slate-200"
              >{{ $t('CASE_TICKETS.CLOSURE.TYPE') }} *</span
            >
            <select v-model="closeForm.closure_type" class="input">
              <option v-for="ct in closureTypeOptions" :key="ct" :value="ct">
                {{ closureTypeLabel(ct) }}
              </option>
            </select>
          </label>
          <label class="flex flex-col gap-1">
            <span class="text-sm font-medium text-slate-700 dark:text-slate-200"
              >{{ $t('CASE_TICKETS.CLOSURE.CAUSE') }} *</span
            >
            <textarea
              v-model="closeForm.closure_cause"
              class="input"
              rows="2"
              :placeholder="$t('CASE_TICKETS.CLOSURE.CAUSE_PLACEHOLDER')"
            />
          </label>
          <label class="flex flex-col gap-1">
            <span class="text-sm font-medium text-slate-700 dark:text-slate-200"
              >{{ $t('CASE_TICKETS.CLOSURE.SOLUTION') }} *</span
            >
            <textarea
              v-model="closeForm.closure_solution"
              class="input"
              rows="3"
              :placeholder="$t('CASE_TICKETS.CLOSURE.SOLUTION_PLACEHOLDER')"
            />
          </label>
          <label class="flex items-center gap-2">
            <input
              v-model="closeForm.customer_confirmed"
              type="checkbox"
              class="m-0"
            />
            <span
              class="text-sm font-medium text-slate-700 dark:text-slate-200"
              >{{ $t('CASE_TICKETS.CLOSURE.CUSTOMER_CONFIRMED') }}</span
            >
          </label>
          <div class="flex justify-end gap-2 mt-2">
            <woot-button
              variant="clear"
              color-scheme="secondary"
              type="button"
              @click="showCloseModal = false"
            >
              {{ $t('CASE_TICKETS.CLOSURE.CANCEL') }}
            </woot-button>
            <woot-button
              type="submit"
              color-scheme="primary"
              :disabled="!closeFormValid"
              :is-loading="isTransitioning"
            >
              {{ $t('CASE_TICKETS.CLOSURE.CONFIRM') }}
            </woot-button>
          </div>
        </form>
      </div>
    </woot-modal>

    <!-- Modal generar artículo KB (2H) -->
    <woot-modal
      v-if="showArticleModal"
      :show="showArticleModal"
      :on-close="() => (showArticleModal = false)"
      size="medium"
    >
      <div class="flex flex-col h-auto overflow-auto">
        <woot-modal-header :header-title="$t('CASE_TICKETS.KB.MODAL_TITLE')" />
        <form
          class="flex flex-col self-stretch w-full gap-4 pb-8"
          @submit.prevent="confirmGenerateArticle"
        >
          <p
            v-if="!kbPortals.length"
            class="m-0 text-sm text-red-600 dark:text-red-400"
          >
            {{ $t('CASE_TICKETS.KB.NO_PORTAL') }}
          </p>
          <template v-else>
            <div class="flex gap-3">
              <label class="flex flex-col flex-1 gap-1">
                <span
                  class="text-sm font-medium text-slate-700 dark:text-slate-200"
                  >{{ $t('CASE_TICKETS.KB.PORTAL') }}</span
                >
                <select v-model="articleForm.portal_id" class="input">
                  <option v-for="p in kbPortals" :key="p.id" :value="p.id">
                    {{ p.name }}
                  </option>
                </select>
              </label>
              <label class="flex flex-col flex-1 gap-1">
                <span
                  class="text-sm font-medium text-slate-700 dark:text-slate-200"
                  >{{ $t('CASE_TICKETS.KB.CATEGORY') }}</span
                >
                <select v-model="articleForm.category_id" class="input">
                  <option value="">
                    {{ $t('CASE_TICKETS.KB.NO_CATEGORY') }}
                  </option>
                  <option
                    v-for="cat in selectedPortalCategories"
                    :key="cat.id"
                    :value="cat.id"
                  >
                    {{ cat.name }}
                  </option>
                </select>
              </label>
            </div>
            <label class="flex flex-col gap-1">
              <span
                class="text-sm font-medium text-slate-700 dark:text-slate-200"
                >{{ $t('CASE_TICKETS.KB.ARTICLE_TITLE') }}</span
              >
              <input v-model="articleForm.title" type="text" class="input" />
            </label>
            <label class="flex flex-col gap-1">
              <span
                class="text-sm font-medium text-slate-700 dark:text-slate-200"
                >{{ $t('CASE_TICKETS.KB.CONTENT') }}</span
              >
              <textarea v-model="articleForm.content" class="input" rows="8" />
            </label>
            <label class="flex items-center gap-2">
              <input
                v-model="articleForm.published"
                type="checkbox"
                class="m-0"
              />
              <span
                class="text-sm font-medium text-slate-700 dark:text-slate-200"
                >{{ $t('CASE_TICKETS.KB.PUBLISH') }}</span
              >
            </label>
          </template>
          <div class="flex justify-end gap-2 mt-2">
            <woot-button
              variant="clear"
              color-scheme="secondary"
              type="button"
              @click="showArticleModal = false"
            >
              {{ $t('CASE_TICKETS.KB.CANCEL') }}
            </woot-button>
            <woot-button
              type="submit"
              color-scheme="primary"
              :disabled="!kbPortals.length || !articleForm.portal_id"
              :is-loading="isGeneratingArticle"
            >
              {{ $t('CASE_TICKETS.KB.CONFIRM') }}
            </woot-button>
          </div>
        </form>
      </div>
    </woot-modal>
  </div>
</template>
