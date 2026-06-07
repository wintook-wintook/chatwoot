<!--
  @tickets_cases
  Vista de detalle de un CaseTicket — timeline + acciones. Tailwind + dark mode.
-->
<script>
import { mapGetters } from 'vuex';
import JourneyView from './JourneyView.vue';

export default {
  name: 'TicketDetail',
  components: { JourneyView },
  props: {
    ticketId: { type: Number, required: true },
  },
  data() {
    return {
      showTransitionMenu: false,
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
    }),
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
      return this.ticket?.can_transition_to || [];
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
  },
  methods: {
    loadTicket() {
      if (!this.ticket) {
        this.$store.dispatch('caseTickets/fetchTicket', this.ticketId);
      }
      this.$store.dispatch('caseTickets/fetchEvents', {
        ticketId: this.ticketId,
      });
      this.$store.dispatch('caseTickets/fetchRelations', this.ticketId);
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
    priorityLabel(key) {
      return this.$t(`CASE_TICKETS.PRIORITIES.${key}`) || key;
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
          <div class="flex flex-wrap gap-1">
            <span
              v-if="ticket.case_type"
              class="px-1.5 py-0.5 text-[11px] font-medium uppercase tracking-wide rounded text-white"
              :style="{ backgroundColor: ticket.case_type.color }"
              >{{ ticket.case_type.name }}</span
            >
            <span
              class="px-1.5 py-0.5 text-[11px] font-medium uppercase tracking-wide rounded bg-slate-100 text-slate-800 dark:bg-slate-700 dark:text-slate-300"
              >{{ statusLabel(ticket.status) }}</span
            >
            <span
              class="px-1.5 py-0.5 text-[11px] font-medium uppercase tracking-wide rounded"
              :class="priorityBadge(ticket.priority)"
              >{{ priorityLabel(ticket.priority) }}</span
            >
            <span
              class="px-1.5 py-0.5 text-[11px] font-medium uppercase tracking-wide rounded"
              :class="slaBadge(ticket.sla_status)"
              >SLA: {{ slaText }}</span
            >
            <span
              class="px-1.5 py-0.5 text-[11px] font-medium uppercase tracking-wide rounded bg-purple-100 text-purple-800 dark:bg-purple-900 dark:text-purple-300"
              :title="$t('CASE_TICKETS.ESCALATION.LEVEL_TITLE')"
              >{{ escalationLabel }}</span
            >
          </div>
          <span
            v-if="ticket.folio"
            class="font-mono text-xs text-slate-400 dark:text-slate-500"
            >{{ ticket.folio }}</span
          >
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

        <!-- Acciones -->
        <div class="relative flex flex-shrink-0 gap-2">
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
            @click="showTransitionMenu = !showTransitionMenu"
          >
            Cambiar estado ▾
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
      </div>
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
          <woot-button size="small" icon="checkmark" @click="applyAiSuggestion">
            {{ $t('CASE_TICKETS.AI.SUGGESTION.APPLY') }}
          </woot-button>
        </div>
      </div>

      <!-- Información -->
      <div
        class="p-4 bg-white border rounded-lg dark:bg-slate-800 border-slate-75 dark:border-slate-700"
      >
        <h3
          class="mb-4 text-base font-semibold text-slate-800 dark:text-slate-100"
        >
          Información
        </h3>
        <div class="grid grid-cols-2 gap-4">
          <div class="flex flex-col gap-0.5">
            <span
              class="text-xs tracking-wide uppercase text-slate-400 dark:text-slate-500"
              >Tipo</span
            >
            <span
              class="text-sm font-medium text-slate-700 dark:text-slate-200"
              >{{ ticket.case_type ? ticket.case_type.name : '—' }}</span
            >
          </div>
          <div class="flex flex-col gap-0.5">
            <span
              class="text-xs tracking-wide uppercase text-slate-400 dark:text-slate-500"
              >Prioridad</span
            >
            <span
              class="text-sm font-medium text-slate-700 dark:text-slate-200"
              >{{ priorityLabel(ticket.priority) }}</span
            >
          </div>
          <div class="flex flex-col gap-0.5">
            <span
              class="text-xs tracking-wide uppercase text-slate-400 dark:text-slate-500"
              >Estado</span
            >
            <span
              class="text-sm font-medium text-slate-700 dark:text-slate-200"
              >{{ statusLabel(ticket.status) }}</span
            >
          </div>
          <div class="flex flex-col gap-0.5">
            <span
              class="text-xs tracking-wide uppercase text-slate-400 dark:text-slate-500"
              >SLA</span
            >
            <span
              class="text-sm font-medium"
              :class="slaInfoColor(ticket.sla_status)"
              >{{ slaText }}</span
            >
          </div>
          <div class="flex flex-col gap-0.5">
            <span
              class="text-xs tracking-wide uppercase text-slate-400 dark:text-slate-500"
              >Creado</span
            >
            <span
              class="text-sm font-medium text-slate-700 dark:text-slate-200"
              >{{ formatDate(ticket.created_at) }}</span
            >
          </div>
          <div v-if="ticket.resolved_at" class="flex flex-col gap-0.5">
            <span
              class="text-xs tracking-wide uppercase text-slate-400 dark:text-slate-500"
              >Resuelto</span
            >
            <span
              class="text-sm font-medium text-slate-700 dark:text-slate-200"
              >{{ formatDate(ticket.resolved_at) }}</span
            >
          </div>
        </div>
      </div>

      <!-- Campos personalizados (2K) -->
      <div
        v-if="customFieldRows.length"
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
                changeAttrs.risk_level ? riskLabel(changeAttrs.risk_level) : '—'
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

      <!-- Tickets relacionados (2E) -->
      <div
        class="p-4 bg-white border rounded-lg dark:bg-slate-800 border-slate-75 dark:border-slate-700"
      >
        <div class="flex items-center justify-between mb-4">
          <h3
            class="m-0 text-base font-semibold text-slate-800 dark:text-slate-100"
          >
            {{ $t('CASE_TICKETS.RELATIONS.TITLE') }}
          </h3>
          <woot-button
            size="tiny"
            variant="smooth"
            color-scheme="secondary"
            icon="link"
            @click="openRelationModal"
          >
            {{ $t('CASE_TICKETS.RELATIONS.ADD') }}
          </woot-button>
        </div>

        <div
          v-if="!relations.length"
          class="text-sm text-slate-400 dark:text-slate-500"
        >
          {{ $t('CASE_TICKETS.RELATIONS.EMPTY') }}
        </div>
        <ul v-else class="flex flex-col gap-2 p-0 m-0 list-none">
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

      <!-- Respuesta sugerida desde KB (3C) -->
      <div
        v-if="replyEnabled"
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
            <div class="flex justify-end mt-3">
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

      <!-- Avance del ticket (2L) — 3 vistas conmutables -->
      <JourneyView
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
