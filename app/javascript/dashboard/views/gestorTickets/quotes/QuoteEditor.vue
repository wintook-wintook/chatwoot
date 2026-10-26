<!--
  Plan-Catalogo-Cotizaciones V1 — una cotización: cliente, responsable, ligas
  (oportunidad y caso de origen), partidas del catálogo o libres con descuento e
  impuesto, totales, vigencia y condiciones. Arriba, su estado y las acciones:
  enviar al cliente (por su conversación), copiar o abrir el enlace, marcar
  ganada / perdida / pospuesta / cancelada, reabrir, nueva versión.
  Nueva: /tickets/quotes/new?contact_id=&opportunity_id=&origin_ticket_id=
-->
<script>
import { mapGetters } from 'vuex';
import { useAlert } from 'dashboard/composables';
import QuotesAPI from 'dashboard/api/quotes';
import ContactAPI from 'dashboard/api/contacts';
import CaseTicketsAPI from 'dashboard/api/caseTickets';
import Spinner from 'shared/components/Spinner.vue';
import CatalogPicker from '../catalog/CatalogPicker.vue';
import QuoteStatusChip from './QuoteStatusChip.vue';
import QuoteOutcomeModal from './QuoteOutcomeModal.vue';
import { formatMoney } from 'dashboard/helper/caseCommercial';
import { copyTextToClipboard } from 'shared/helpers/clipboard';
import { backKind, backPath, backQuery } from '../backLink';

const round = value => Math.round((Number(value) || 0) * 100) / 100;

export default {
  name: 'QuoteEditor',
  components: { Spinner, CatalogPicker, QuoteStatusChip, QuoteOutcomeModal },
  props: {
    quoteId: { type: Number, default: null },
  },
  data() {
    return {
      quote: null,
      loading: !!this.quoteId,
      saving: false,
      form: this.blankForm(),
      items: [],
      contactQuery: '',
      contactResults: [],
      openOpportunities: [],
      outcomeStatus: null,
      showMore: false,
      prompt: null,
    };
  },
  computed: {
    ...mapGetters({
      agents: 'agents/getAgents',
      caseSettings: 'caseTickets/getCaseSettings',
    }),
    isNew() {
      return !this.quoteId;
    },
    // Campo «Oportunidad»: '' = sin oportunidad, un id, o 'new' (crearla).
    // Ya cerrada (ganada, perdida, cancelada) solo se muestra: su monto y su
    // resultado ya pasaron a la oportunidad.
    opportunityLocked() {
      return (
        !!this.quote && ['won', 'lost', 'cancelled'].includes(this.quote.status)
      );
    },
    opportunityRequired() {
      return !!(
        this.caseSettings && this.caseSettings.quotes_require_opportunity
      );
    },
    opportunityOptions() {
      const list = [...this.openOpportunities];
      const current = this.quote && this.quote.opportunity;
      if (current && !list.some(opp => opp.id === current.id))
        list.unshift(current);
      return list;
    },
    // Abierta desde un caso o la conversación (`?back=`): «Volver» regresa ahí.
    returnPath() {
      return backPath(this.$route);
    },
    backRoute() {
      return (
        this.returnPath || {
          name: 'gestorTickets_quotes',
          params: { accountId: this.$route.params.accountId },
        }
      );
    },
    backLabel() {
      return this.returnPath
        ? this.$t(`CASE_TICKETS.BACK_TO.${backKind(this.returnPath)}`)
        : this.$t('QUOTES.TITLE');
    },
    // Se conserva al pasar a la cotización guardada o a su nueva versión.
    keepBack() {
      return this.returnPath ? { back: this.returnPath } : {};
    },
    editable() {
      return this.isNew || (this.quote && this.quote.editable);
    },
    amountsHidden() {
      return !!this.quote && this.quote.total === null;
    },
    totals() {
      let gross = 0;
      let net = 0;
      let tax = 0;
      this.items.forEach(item => {
        const lineGross =
          (Number(item.quantity) || 0) * (Number(item.unit_price) || 0);
        const lineNet = round(
          lineGross * (1 - (Number(item.discount_percent) || 0) / 100)
        );
        gross += lineGross;
        net += lineNet;
        tax += round((lineNet * (Number(item.tax_percent) || 0)) / 100);
      });
      return {
        subtotal: round(gross),
        discount: round(gross - net),
        tax: round(tax),
        total: round(net + tax),
      };
    },
    statusActions() {
      if (!this.quote) return [];
      const s = this.quote.status;
      const list = [];
      if (['draft', 'sent', 'postponed'].includes(s)) list.push('won', 'lost');
      if (['draft', 'sent'].includes(s)) list.push('postponed');
      if (['draft', 'sent', 'postponed'].includes(s)) list.push('cancelled');
      return list;
    },
    defaultTax() {
      return (this.caseSettings && this.caseSettings.default_tax_percent) || 0;
    },
  },
  watch: {
    quoteId: 'load',
  },
  mounted() {
    if (!this.agents.length) this.$store.dispatch('agents/get');
    this.$store.dispatch('caseTickets/fetchSettings');
    this.load();
  },
  methods: {
    blankForm() {
      return {
        contact: null,
        assignee_id: '',
        currency: '',
        valid_until: '',
        terms: '',
        notes: '',
        opportunity_id: '',
        origin_ticket_id: '',
      };
    },
    money(value) {
      if (value === null || value === undefined) return '—';
      const currency =
        this.form.currency ||
        (this.caseSettings && this.caseSettings.default_currency);
      return formatMoney(value, currency);
    },
    async load() {
      if (this.isNew) {
        await this.prefillNew();
        return;
      }
      this.loading = true;
      try {
        const { data } = await QuotesAPI.show(this.quoteId);
        this.apply(data.quote);
      } catch {
        useAlert(this.$t('QUOTES.EDITOR.ERROR'));
      } finally {
        this.loading = false;
      }
    },
    apply(quote) {
      this.quote = quote;
      this.form = {
        contact: quote.contact,
        assignee_id: quote.assignee ? quote.assignee.id : '',
        currency: quote.currency,
        valid_until: quote.valid_until || '',
        terms: quote.terms || '',
        notes: quote.notes || '',
        opportunity_id: quote.opportunity ? quote.opportunity.id : '',
        origin_ticket_id: quote.origin_ticket ? quote.origin_ticket.id : '',
      };
      this.items = (quote.items || []).map(item => ({ ...item }));
      if (quote.contact && !this.opportunityLocked)
        this.fetchOpenOpportunities(quote.contact.id);
    },
    async prefillNew() {
      const {
        contact_id: contactId,
        opportunity_id: oppId,
        origin_ticket_id: originId,
      } = this.$route.query;
      this.form = this.blankForm();
      this.items = [];
      this.quote = null;
      this.form.opportunity_id = oppId || '';
      this.form.origin_ticket_id = originId || '';
      if (contactId) {
        try {
          const { data } = await ContactAPI.show(contactId);
          this.form.contact = { id: data.payload.id, name: data.payload.name };
          this.fetchOpenOpportunities(data.payload.id);
          if (!oppId && this.opportunityRequired)
            this.form.opportunity_id = 'new';
        } catch {
          this.form.contact = null;
        }
      }
    },
    async fetchOpenOpportunities(contactId) {
      try {
        const { data } = await CaseTicketsAPI.getAll({
          contact_id: contactId,
          case_class: 'commercial',
          status: 'pending',
          per_page: 50,
        });
        this.openOpportunities = data.case_tickets || [];
      } catch {
        this.openOpportunities = [];
      }
    },
    async searchContacts() {
      const term = this.contactQuery.trim();
      if (term.length < 2) {
        this.contactResults = [];
        return;
      }
      try {
        const { data } = await ContactAPI.search(term, 1);
        this.contactResults = data.payload || [];
      } catch {
        this.contactResults = [];
      }
    },
    chooseContact(contact) {
      this.form.contact = { id: contact.id, name: contact.name };
      this.contactQuery = '';
      this.contactResults = [];
      this.form.opportunity_id = this.opportunityRequired ? 'new' : '';
      this.fetchOpenOpportunities(contact.id);
    },
    clearContact() {
      this.form.contact = null;
      this.form.opportunity_id = '';
      this.openOpportunities = [];
    },
    // Cotización ya guardada: el cambio se aplica al momento.
    changeOpportunity(value) {
      this.form.opportunity_id = value;
      if (this.isNew) return;
      if (value === 'new') this.linkOpportunity({ create: true });
      else this.linkOpportunity(value ? { opportunity_id: value } : {});
    },
    addCatalogItem(item) {
      this.items.push({
        catalog_item_id: item.id,
        description: item.name,
        kind: item.kind,
        unit: item.unit,
        quantity: 1,
        unit_price: item.price,
        discount_percent: 0,
        tax_percent: this.defaultTax,
      });
      if (!this.form.currency) this.form.currency = item.currency;
    },
    addFreeItem(text) {
      this.items.push({
        catalog_item_id: null,
        description: text,
        kind: null,
        unit: '',
        quantity: 1,
        unit_price: 0,
        discount_percent: 0,
        tax_percent: this.defaultTax,
      });
    },
    lineTotal(item) {
      const net = round(
        (Number(item.quantity) || 0) *
          (Number(item.unit_price) || 0) *
          (1 - (Number(item.discount_percent) || 0) / 100)
      );
      return round(net + (net * (Number(item.tax_percent) || 0)) / 100);
    },
    removeItem(index) {
      this.items.splice(index, 1);
    },
    payload() {
      const { contact, opportunity_id: opportunityId, ...rest } = this.form;
      const create = opportunityId === 'new';
      return {
        quote: {
          ...rest,
          contact_id: contact && contact.id,
          opportunity_id: create ? '' : opportunityId,
        },
        create_opportunity: create,
        items: this.items.map(item => ({
          catalog_item_id: item.catalog_item_id,
          description: item.description,
          kind: item.kind,
          unit: item.unit,
          quantity: item.quantity,
          unit_price: item.unit_price,
          discount_percent: item.discount_percent,
          tax_percent: item.tax_percent,
        })),
      };
    },
    async save() {
      if (!this.form.contact) {
        useAlert(this.$t('QUOTES.EDITOR.REQUIRE_CONTACT'));
        return null;
      }
      if (!this.items.length) {
        useAlert(this.$t('QUOTES.EDITOR.REQUIRE_ITEMS'));
        return null;
      }
      this.saving = true;
      try {
        const { data } = this.isNew
          ? await QuotesAPI.createQuote(this.payload())
          : await QuotesAPI.updateQuote(this.quoteId, this.payload());
        useAlert(this.$t('QUOTES.EDITOR.SAVED'));
        if (this.isNew) {
          this.$router.replace({
            name: 'gestorTickets_quote',
            params: {
              accountId: this.$route.params.accountId,
              id: data.quote.id,
            },
            query: this.keepBack,
          });
        } else {
          this.apply(data.quote);
        }
        return data.quote;
      } catch (error) {
        useAlert(
          error?.response?.data?.error || this.$t('QUOTES.EDITOR.ERROR')
        );
        return null;
      } finally {
        this.saving = false;
      }
    },
    async run(request, okMessage) {
      try {
        const { data } = await request();
        if (data.quote) this.apply(data.quote);
        if (okMessage) useAlert(okMessage);
        if (data.prompt === 'all_closed') this.prompt = data.prompt;
        return data;
      } catch (error) {
        useAlert(
          error?.response?.data?.error || this.$t('QUOTES.EDITOR.ERROR')
        );
        return null;
      }
    },
    deliver() {
      return this.run(
        () => QuotesAPI.deliver(this.quote.id),
        this.$t('QUOTES.ACTIONS.SENT_OK')
      );
    },
    markSent() {
      return this.run(() => QuotesAPI.transition(this.quote.id, 'sent'));
    },
    reopen() {
      return this.run(() => QuotesAPI.transition(this.quote.id, 'reopen'));
    },
    async copyLink() {
      await copyTextToClipboard(this.quote.public_url);
      useAlert(this.$t('QUOTES.ACTIONS.LINK_COPIED'));
    },
    openLink() {
      window.open(this.quote.public_url, '_blank', 'noopener');
    },
    async confirmOutcome(extra) {
      const status = this.outcomeStatus;
      this.outcomeStatus = null;
      await this.run(() => QuotesAPI.transition(this.quote.id, status, extra));
    },
    async newVersion() {
      this.showMore = false;
      const data = await this.run(() => QuotesAPI.newVersion(this.quote.id));
      if (data && data.quote) {
        this.$router.push({
          name: 'gestorTickets_quote',
          params: {
            accountId: this.$route.params.accountId,
            id: data.quote.id,
          },
          query: this.keepBack,
        });
      }
    },
    async removeDraft() {
      this.showMore = false;
      // eslint-disable-next-line no-alert
      if (!window.confirm(this.$t('QUOTES.ACTIONS.DELETE_CONFIRM'))) return;
      await QuotesAPI.delete(this.quote.id);
      this.$router.push(this.backRoute);
    },
    linkOpportunity(payload) {
      return this.run(() => QuotesAPI.linkOpportunity(this.quote.id, payload));
    },
    async closeOpportunity() {
      const opp = this.quote.opportunity;
      this.prompt = null;
      try {
        await CaseTicketsAPI.closeWithOutcome(opp.id, { outcome: 'lost' });
        this.load();
      } catch (error) {
        useAlert(
          error?.response?.data?.error || this.$t('QUOTES.EDITOR.ERROR')
        );
      }
    },
    ticketRoute(ticket) {
      return {
        name: 'gestorTickets_detail',
        params: { accountId: this.$route.params.accountId, id: ticket.id },
        // «Volver» del caso regresa a esta cotización.
        query: backQuery(this.$route),
      };
    },
  },
};
</script>

<template>
  <div
    class="flex flex-col flex-1 w-full h-full overflow-y-auto bg-slate-25 dark:bg-slate-900"
  >
    <Spinner v-if="loading" />
    <div v-else class="w-full max-w-5xl px-6 py-5 mx-auto">
      <!-- Encabezado: folio, estado y acciones -->
      <header class="flex flex-wrap items-start justify-between gap-3 mb-4">
        <div class="flex flex-col gap-1">
          <router-link :to="backRoute" class="text-sm text-woot-600">
            <fluent-icon icon="chevron-left" size="14" class="inline" />
            {{ backLabel }}
          </router-link>
          <div class="flex flex-wrap items-center gap-2">
            <h1
              class="m-0 text-xl font-bold text-slate-800 dark:text-slate-100"
            >
              {{ quote ? quote.folio : $t('QUOTES.EDITOR.NEW_TITLE') }}
            </h1>
            <QuoteStatusChip v-if="quote" :quote="quote" />
          </div>
          <p
            v-if="quote && quote.outcome_note"
            class="m-0 text-sm text-slate-600 dark:text-slate-300"
          >
            {{ quote.outcome_reason ? `${quote.outcome_reason.label} · ` : ''
            }}{{ quote.outcome_note }}
          </p>
        </div>
        <div v-if="quote" class="flex flex-wrap items-center gap-2">
          <woot-button
            v-if="quote.status === 'draft' || quote.status === 'sent'"
            size="small"
            icon="send"
            @click="deliver"
          >
            {{ $t('QUOTES.ACTIONS.SEND') }}
          </woot-button>
          <woot-button
            size="small"
            variant="smooth"
            color-scheme="secondary"
            icon="copy"
            @click="copyLink"
          >
            {{ $t('QUOTES.ACTIONS.COPY_LINK') }}
          </woot-button>
          <woot-button
            v-for="status in statusActions"
            :key="status"
            size="small"
            variant="smooth"
            :color-scheme="
              status === 'won'
                ? 'success'
                : status === 'lost'
                ? 'alert'
                : 'secondary'
            "
            @click="outcomeStatus = status"
          >
            {{ $t(`QUOTES.ACTIONS.${status.toUpperCase()}`) }}
          </woot-button>
          <woot-button
            v-if="quote.status === 'lost' || quote.status === 'cancelled'"
            size="small"
            variant="smooth"
            color-scheme="secondary"
            @click="reopen"
          >
            {{ $t('QUOTES.ACTIONS.REOPEN') }}
          </woot-button>
          <div v-on-clickaway="() => (showMore = false)" class="relative">
            <woot-button
              size="small"
              variant="smooth"
              color-scheme="secondary"
              icon="more-horizontal"
              @click="showMore = !showMore"
            >
              {{ $t('QUOTES.ACTIONS.MORE') }}
            </woot-button>
            <ul
              v-if="showMore"
              class="absolute right-0 z-50 w-56 p-1 m-0 mt-1 list-none bg-white border rounded-md shadow-xl top-full dark:bg-slate-800 border-slate-50 dark:border-slate-700"
            >
              <li>
                <button
                  type="button"
                  class="w-full px-3 py-2 text-sm text-left rounded-md hover:bg-slate-50 dark:hover:bg-slate-700"
                  @click="openLink"
                >
                  {{ $t('QUOTES.ACTIONS.OPEN_LINK') }}
                </button>
              </li>
              <li v-if="quote.status === 'draft'">
                <button
                  type="button"
                  class="w-full px-3 py-2 text-sm text-left rounded-md hover:bg-slate-50 dark:hover:bg-slate-700"
                  @click="markSent"
                >
                  {{ $t('QUOTES.ACTIONS.MARK_SENT') }}
                </button>
              </li>
              <li>
                <button
                  type="button"
                  class="w-full px-3 py-2 text-sm text-left rounded-md hover:bg-slate-50 dark:hover:bg-slate-700"
                  @click="newVersion"
                >
                  {{ $t('QUOTES.ACTIONS.NEW_VERSION') }}
                </button>
              </li>
              <li v-if="quote.status === 'draft'">
                <button
                  type="button"
                  class="w-full px-3 py-2 text-sm text-left text-red-600 rounded-md hover:bg-slate-50 dark:hover:bg-slate-700"
                  @click="removeDraft"
                >
                  {{ $t('QUOTES.ACTIONS.DELETE') }}
                </button>
              </li>
            </ul>
          </div>
        </div>
      </header>

      <!-- Todas cerradas: ¿se cierra la oportunidad? -->
      <div
        v-if="prompt === 'all_closed' && quote && quote.opportunity"
        class="flex flex-wrap items-center justify-between gap-3 p-3 mb-4 text-sm border rounded-lg bg-yellow-50 border-yellow-200 dark:bg-yellow-900/20 dark:border-yellow-800"
      >
        <span>{{
          $t('QUOTES.PROMPT.ALL_CLOSED', { folio: quote.opportunity.folio })
        }}</span>
        <span class="flex gap-2">
          <woot-button
            size="small"
            color-scheme="alert"
            @click="closeOpportunity"
          >
            {{ $t('QUOTES.PROMPT.CLOSE_OPP') }}
          </woot-button>
          <woot-button size="small" variant="clear" @click="prompt = null">
            {{ $t('QUOTES.PROMPT.KEEP_OPP') }}
          </woot-button>
        </span>
      </div>

      <p
        v-if="quote && !editable"
        class="p-3 mb-4 text-sm rounded-lg bg-slate-100 text-slate-700 dark:bg-slate-800 dark:text-slate-200"
      >
        {{ $t('QUOTES.EDITOR.NOT_EDITABLE') }}
      </p>

      <!-- Datos generales -->
      <section
        class="grid grid-cols-1 gap-4 p-4 mb-4 bg-white border rounded-lg md:grid-cols-2 dark:bg-slate-800 border-slate-75 dark:border-slate-700"
      >
        <div>
          <label class="mb-1">{{ $t('QUOTES.EDITOR.CONTACT') }}</label>
          <div v-if="form.contact" class="flex items-center gap-2 h-10">
            <span class="font-medium text-slate-800 dark:text-slate-100">{{
              form.contact.name
            }}</span>
            <woot-button
              v-if="isNew"
              size="tiny"
              variant="clear"
              icon="dismiss"
              @click="clearContact"
            />
          </div>
          <div v-else class="relative">
            <input
              v-model="contactQuery"
              type="search"
              class="!mb-0"
              :placeholder="$t('QUOTES.EDITOR.CONTACT_SEARCH')"
              @input="searchContacts"
            />
            <ul
              v-if="contactResults.length"
              class="absolute z-50 w-full p-1 m-0 mt-1 overflow-y-auto list-none bg-white border rounded-md shadow-xl max-h-60 dark:bg-slate-800 border-slate-50 dark:border-slate-700"
            >
              <li v-for="contact in contactResults" :key="contact.id">
                <button
                  type="button"
                  class="w-full px-3 py-2 text-sm text-left rounded-md hover:bg-slate-50 dark:hover:bg-slate-700"
                  @click="chooseContact(contact)"
                >
                  {{ contact.name }}
                  <span class="text-xs text-slate-500">{{
                    contact.phone_number || contact.email
                  }}</span>
                </button>
              </li>
            </ul>
          </div>
        </div>
        <label>
          {{ $t('QUOTES.EDITOR.ASSIGNEE') }}
          <select
            v-model="form.assignee_id"
            :disabled="!editable"
            class="!mb-0"
          >
            <option value="">—</option>
            <option v-for="agent in agents" :key="agent.id" :value="agent.id">
              {{ agent.name }}
            </option>
          </select>
        </label>
        <label>
          {{ $t('QUOTES.EDITOR.VALID_UNTIL') }}
          <input
            v-model="form.valid_until"
            type="date"
            :disabled="!editable"
            class="!mb-0"
          />
        </label>
        <label>
          {{ $t('QUOTES.EDITOR.CURRENCY') }}
          <input
            v-model="form.currency"
            type="text"
            maxlength="3"
            class="uppercase !mb-0"
            :disabled="!editable"
          />
        </label>

        <!-- Oportunidad: a qué venta del embudo suma esta cotización -->
        <div class="md:col-span-2">
          <label class="mb-1">{{ $t('QUOTES.EDITOR.OPPORTUNITY') }}</label>
          <div v-if="opportunityLocked" class="flex items-center h-10 text-sm">
            <router-link
              v-if="quote.opportunity"
              :to="ticketRoute(quote.opportunity)"
              class="text-woot-600"
            >
              {{ quote.opportunity.folio }} · {{ quote.opportunity.title }}
            </router-link>
            <span v-else class="text-slate-500">
              {{ $t('QUOTES.EDITOR.NO_OPPORTUNITY') }}
            </span>
          </div>
          <div v-else class="flex flex-wrap items-center gap-3">
            <select
              :value="form.opportunity_id"
              class="!mb-0 md:w-96"
              :disabled="!form.contact || saving"
              @change="changeOpportunity($event.target.value)"
            >
              <option v-if="!opportunityRequired" value="">
                {{ $t('QUOTES.EDITOR.NO_OPPORTUNITY_OPTION') }}
              </option>
              <option
                v-for="opp in opportunityOptions"
                :key="opp.id"
                :value="opp.id"
              >
                {{ opp.folio }} · {{ opp.title }}
              </option>
              <option value="new">
                {{ $t('QUOTES.EDITOR.CREATE_OPPORTUNITY_OPTION') }}
              </option>
            </select>
            <router-link
              v-if="quote && quote.opportunity"
              :to="ticketRoute(quote.opportunity)"
              class="text-sm text-woot-600"
            >
              {{ $t('QUOTES.EDITOR.OPEN_OPPORTUNITY') }}
            </router-link>
            <span class="text-xs text-slate-500 dark:text-slate-400">{{
              opportunityRequired
                ? $t('QUOTES.EDITOR.OPPORTUNITY_REQUIRED_HELP')
                : $t('QUOTES.EDITOR.OPPORTUNITY_HELP')
            }}</span>
          </div>
        </div>

        <!-- De qué caso sale (trabajo adicional de una orden, etc.) -->
        <div class="flex flex-col gap-1 text-sm md:col-span-2">
          <div v-if="quote && quote.origin_ticket">
            <span class="text-slate-500">{{ $t('QUOTES.EDITOR.ORIGIN') }}</span>
            <router-link
              :to="ticketRoute(quote.origin_ticket)"
              class="ml-1 text-woot-600"
            >
              {{ $t(`QUOTES.ORIGIN_CLASS.${quote.origin_ticket.case_class}`) }}
              {{ quote.origin_ticket.folio }} · {{ quote.origin_ticket.title }}
            </router-link>
          </div>
        </div>
      </section>

      <!-- Partidas -->
      <section
        class="p-4 mb-4 bg-white border rounded-lg dark:bg-slate-800 border-slate-75 dark:border-slate-700"
      >
        <h2
          class="m-0 mb-3 text-sm font-semibold text-slate-700 dark:text-slate-200"
        >
          {{ $t('QUOTES.EDITOR.ITEMS') }}
        </h2>
        <div class="overflow-x-auto">
          <table class="w-full text-sm">
            <thead>
              <tr class="text-left text-slate-500 dark:text-slate-400">
                <th class="py-1 pr-2 font-medium">
                  {{ $t('QUOTES.EDITOR.DESCRIPTION') }}
                </th>
                <th class="w-20 px-1 py-1 font-medium">
                  {{ $t('QUOTES.EDITOR.QUANTITY') }}
                </th>
                <th class="w-24 px-1 py-1 font-medium">
                  {{ $t('QUOTES.EDITOR.UNIT') }}
                </th>
                <th class="px-1 py-1 font-medium w-28">
                  {{ $t('QUOTES.EDITOR.PRICE') }}
                </th>
                <th class="w-20 px-1 py-1 font-medium">
                  {{ $t('QUOTES.EDITOR.DISCOUNT') }}
                </th>
                <th class="w-20 px-1 py-1 font-medium">
                  {{ $t('QUOTES.EDITOR.TAX') }}
                </th>
                <th class="py-1 pl-1 font-medium text-right w-28">
                  {{ $t('QUOTES.EDITOR.AMOUNT') }}
                </th>
                <th class="w-8" />
              </tr>
            </thead>
            <tbody>
              <tr v-for="(item, index) in items" :key="index" class="align-top">
                <td class="py-1 pr-2">
                  <input
                    v-model="item.description"
                    type="text"
                    class="!mb-0"
                    :disabled="!editable"
                  />
                </td>
                <td class="px-1 py-1">
                  <input
                    v-model="item.quantity"
                    type="number"
                    min="0"
                    step="0.01"
                    class="!mb-0"
                    :disabled="!editable"
                  />
                </td>
                <td class="px-1 py-1">
                  <input
                    v-model="item.unit"
                    type="text"
                    class="!mb-0"
                    :disabled="!editable"
                  />
                </td>
                <td class="px-1 py-1">
                  <input
                    v-if="!amountsHidden"
                    v-model="item.unit_price"
                    type="number"
                    min="0"
                    step="0.01"
                    class="!mb-0"
                    :disabled="!editable"
                  />
                  <span v-else class="leading-10">—</span>
                </td>
                <td class="px-1 py-1">
                  <input
                    v-model="item.discount_percent"
                    type="number"
                    min="0"
                    max="100"
                    step="0.01"
                    class="!mb-0"
                    :disabled="!editable"
                  />
                </td>
                <td class="px-1 py-1">
                  <input
                    v-model="item.tax_percent"
                    type="number"
                    min="0"
                    max="100"
                    step="0.01"
                    class="!mb-0"
                    :disabled="!editable"
                  />
                </td>
                <td class="py-1 pl-1 leading-10 text-right whitespace-nowrap">
                  {{ amountsHidden ? '—' : money(lineTotal(item)) }}
                </td>
                <td class="py-1 text-center">
                  <woot-button
                    v-if="editable"
                    size="tiny"
                    variant="clear"
                    color-scheme="secondary"
                    icon="dismiss"
                    @click="removeItem(index)"
                  />
                </td>
              </tr>
            </tbody>
          </table>
        </div>
        <div v-if="editable" class="mt-2 md:w-1/2">
          <CatalogPicker @select="addCatalogItem" @free="addFreeItem" />
        </div>
        <dl
          v-if="!amountsHidden"
          class="grid w-full max-w-xs grid-cols-2 gap-1 mt-4 ml-auto text-sm"
        >
          <dt class="text-slate-500">{{ $t('QUOTES.EDITOR.SUBTOTAL') }}</dt>
          <dd class="m-0 text-right">{{ money(totals.subtotal) }}</dd>
          <template v-if="totals.discount">
            <dt class="text-slate-500">
              {{ $t('QUOTES.EDITOR.DISCOUNT_TOTAL') }}
            </dt>
            <dd class="m-0 text-right">−{{ money(totals.discount) }}</dd>
          </template>
          <template v-if="totals.tax">
            <dt class="text-slate-500">{{ $t('QUOTES.EDITOR.TAX_TOTAL') }}</dt>
            <dd class="m-0 text-right">{{ money(totals.tax) }}</dd>
          </template>
          <dt
            class="pt-1 font-semibold border-t border-slate-75 dark:border-slate-700"
          >
            {{ $t('QUOTES.EDITOR.TOTAL') }}
          </dt>
          <dd
            class="pt-1 m-0 font-semibold text-right border-t border-slate-75 dark:border-slate-700"
          >
            {{ money(totals.total) }}
          </dd>
        </dl>
      </section>

      <!-- Condiciones y notas -->
      <section
        class="grid grid-cols-1 gap-4 p-4 mb-4 bg-white border rounded-lg md:grid-cols-2 dark:bg-slate-800 border-slate-75 dark:border-slate-700"
      >
        <label>
          {{ $t('QUOTES.EDITOR.TERMS') }}
          <textarea
            v-model="form.terms"
            rows="4"
            :placeholder="$t('QUOTES.EDITOR.TERMS_PLACEHOLDER')"
            :disabled="!editable"
          />
        </label>
        <label>
          {{ $t('QUOTES.EDITOR.NOTES') }}
          <textarea
            v-model="form.notes"
            rows="4"
            :placeholder="$t('QUOTES.EDITOR.NOTES_PLACEHOLDER')"
            :disabled="!editable"
          />
        </label>
      </section>

      <div v-if="editable" class="flex justify-end">
        <woot-button :is-loading="saving" @click="save">
          {{ $t('QUOTES.EDITOR.SAVE') }}
        </woot-button>
      </div>
    </div>

    <QuoteOutcomeModal
      v-if="outcomeStatus"
      show
      :status="outcomeStatus"
      @close="outcomeStatus = null"
      @confirm="confirmOutcome"
    />
  </div>
</template>
