<!--
  @tickets_cases — Plan-Clase-Orden-de-Trabajo F2a
  Franja «Orden de trabajo» del detalle: dirección, horas estimadas y reales y
  facturable (editables en línea, se guardan juntos con PATCH /case_tickets/:id;
  el backend deja `work_order_changed`), la lista de materiales con su importe y,
  cerrada, la conformidad (quién recibió, cuándo, nota). Cerrada = solo lectura.
  F2b — la próxima visita (o el aviso de una vencida) y «Programar visita», que
  emite `schedule`: la ficha abre el alta de reunión precargada con la orden.
-->
<script>
import { mapGetters } from 'vuex';
import CaseTicketsAPI from 'dashboard/api/caseTickets';
import { formatMoney } from 'dashboard/helper/caseCommercial';
import { formatHours, workOrderPayload } from 'dashboard/helper/caseWorkOrder';
import CatalogPicker from '../catalog/CatalogPicker.vue'; // Plan-Catalogo-Cotizaciones

const FIELDS = ['work_address', 'estimated_hours', 'actual_hours', 'billable'];
const emptyItem = () => ({
  description: '',
  quantity: 1,
  unit: '',
  unit_cost: '',
});

export default {
  name: 'WorkOrderPanel',
  components: { CatalogPicker },
  props: {
    ticket: { type: Object, required: true },
    // Dentro de la pestaña «Conceptos» de la ficha: tarjeta en vez de franja.
    asTab: { type: Boolean, default: false },
  },
  emits: ['updated', 'schedule'],
  data() {
    return {
      draft: this.fromTicket(),
      newItem: emptyItem(),
      isSaving: false,
      isSavingItem: false,
    };
  },
  computed: {
    ...mapGetters({ caseSettings: 'caseTickets/getCaseSettings' }),
    isFrozen() {
      return !!this.ticket.is_frozen;
    },
    isDirty() {
      const original = this.fromTicket();
      return FIELDS.some(f => String(this.draft[f]) !== String(original[f]));
    },
    items() {
      return this.ticket.work_order_items || [];
    },
    currency() {
      return this.caseSettings?.default_currency || 'MXN';
    },
    hasCosts() {
      return this.items.some(i => i.unit_cost !== null);
    },
  },
  watch: {
    // Otro cambio (mover de etapa, cerrar, reabrir) trae datos nuevos.
    ticket() {
      this.draft = this.fromTicket();
    },
  },
  methods: {
    fromTicket() {
      const t = this.ticket || {};
      return {
        work_address: t.work_address || '',
        estimated_hours: t.estimated_hours ?? '',
        actual_hours: t.actual_hours ?? '',
        billable: !!t.billable,
      };
    },
    hours(value) {
      return formatHours(value);
    },
    money(value) {
      return value === null || value === undefined
        ? '—'
        : formatMoney(value, this.currency);
    },
    when(value) {
      return value ? new Date(value).toLocaleString() : '—';
    },
    toastError(e, fallbackKey) {
      const error = e.response?.data?.error;
      this.$emitter.emit('newToastMessage', {
        message: Array.isArray(error)
          ? error.join(', ')
          : error || this.$t(fallbackKey),
        type: 'error',
      });
    },
    discard() {
      this.draft = this.fromTicket();
    },
    async save() {
      this.isSaving = true;
      try {
        await this.$store.dispatch('caseTickets/updateWorkOrderData', {
          ticketId: this.ticket.id,
          data: workOrderPayload(this.draft, { clear: true }),
        });
        this.$emitter.emit('newToastMessage', {
          message: this.$t('CASE_TICKETS.WORK_ORDER.PANEL.SAVED'),
        });
        this.$emit('updated');
      } catch (e) {
        this.toastError(e, 'CASE_TICKETS.WORK_ORDER.PANEL.SAVE_ERROR');
      } finally {
        this.isSaving = false;
      }
    },
    itemPayload(item) {
      return {
        description: String(item.description || '').trim(),
        quantity: item.quantity,
        unit: String(item.unit || '').trim() || null,
        unit_cost:
          item.unit_cost === '' || item.unit_cost === null
            ? null
            : item.unit_cost,
        catalog_item_id: item.catalog_item_id || null,
      };
    },
    // Plan-Catalogo-Cotizaciones — un producto o refacción del catálogo se agrega
    // directo con su unidad y su precio.
    async addFromCatalog(entry) {
      this.newItem = {
        description: entry.name,
        quantity: 1,
        unit: entry.unit || '',
        unit_cost: entry.price,
        catalog_item_id: entry.id,
      };
      await this.addItem();
    },
    async addItem() {
      if (!String(this.newItem.description).trim()) return;
      this.isSavingItem = true;
      try {
        await CaseTicketsAPI.createWorkOrderItem(
          this.ticket.id,
          this.itemPayload(this.newItem)
        );
        this.newItem = emptyItem();
        this.$emit('updated');
      } catch (e) {
        this.toastError(e, 'CASE_TICKETS.WORK_ORDER.ITEMS.ERROR');
      } finally {
        this.isSavingItem = false;
      }
    },
    // Se guarda al salir del campo; un valor inválido lo rechaza el backend y
    // el refresco regresa el valor guardado.
    async updateItem(item, field, value) {
      if (String(item[field] ?? '') === String(value)) return;
      try {
        await CaseTicketsAPI.updateWorkOrderItem(
          this.ticket.id,
          item.id,
          this.itemPayload({ ...item, [field]: value })
        );
      } catch (e) {
        this.toastError(e, 'CASE_TICKETS.WORK_ORDER.ITEMS.ERROR');
      } finally {
        this.$emit('updated');
      }
    },
    async deleteItem(item) {
      try {
        await CaseTicketsAPI.deleteWorkOrderItem(this.ticket.id, item.id);
        this.$emit('updated');
      } catch (e) {
        this.toastError(e, 'CASE_TICKETS.WORK_ORDER.ITEMS.ERROR');
      }
    },
  },
};
</script>

<template>
  <div
    class="flex flex-col flex-shrink-0 gap-3"
    :class="
      asTab
        ? 'p-4 bg-white border rounded-lg dark:bg-slate-800 border-slate-75 dark:border-slate-700'
        : 'px-6 py-3 border-b bg-teal-50 dark:bg-slate-800/50 border-slate-50 dark:border-slate-800/50'
    "
  >
    <div class="flex flex-wrap items-center gap-2">
      <span
        class="text-xs font-semibold tracking-wide uppercase text-teal-700 dark:text-teal-300"
      >
        {{ $t('CASE_TICKETS.WORK_ORDER.PANEL.TITLE') }}
      </span>
      <span
        v-if="ticket.billable"
        class="inline-flex items-center px-2 py-0.5 text-[11px] font-medium rounded-full bg-emerald-100 text-emerald-800 dark:bg-emerald-900/40 dark:text-emerald-300"
      >
        {{ $t('CASE_TICKETS.WORK_ORDER.FIELDS.BILLABLE') }}
      </span>
      <span
        v-if="ticket.visit_overdue"
        class="inline-flex items-center px-2 py-0.5 text-[11px] font-medium rounded-full bg-red-100 text-red-800 dark:bg-red-900/40 dark:text-red-300"
      >
        {{ $t('CASE_TICKETS.WORK_ORDER.VISIT.OVERDUE') }}
      </span>
      <span class="ml-auto text-sm text-slate-600 dark:text-slate-300">
        <span class="text-xs uppercase text-slate-400 dark:text-slate-500">
          {{ $t('CASE_TICKETS.WORK_ORDER.VISIT.NEXT') }}
        </span>
        {{
          ticket.next_visit_at
            ? when(ticket.next_visit_at)
            : $t('CASE_TICKETS.WORK_ORDER.VISIT.NONE')
        }}
      </span>
      <woot-button
        v-if="!isFrozen"
        size="small"
        variant="smooth"
        icon="calendar"
        type="button"
        @click="$emit('schedule')"
      >
        {{ $t('CASE_TICKETS.WORK_ORDER.VISIT.SCHEDULE') }}
      </woot-button>
    </div>

    <!-- Cerrada: solo lectura + conformidad -->
    <div v-if="isFrozen" class="flex flex-wrap items-start gap-x-8 gap-y-2">
      <div class="flex flex-col min-w-[12rem]">
        <span class="text-xs uppercase text-slate-400 dark:text-slate-500">
          {{ $t('CASE_TICKETS.WORK_ORDER.FIELDS.ADDRESS') }}
        </span>
        <span class="text-sm text-slate-700 dark:text-slate-200">
          {{ ticket.work_address || '—' }}
        </span>
      </div>
      <div class="flex flex-col">
        <span class="text-xs uppercase text-slate-400 dark:text-slate-500">
          {{ $t('CASE_TICKETS.WORK_ORDER.FIELDS.HOURS') }}
        </span>
        <span class="text-sm tabular-nums text-slate-700 dark:text-slate-200">
          {{ hours(ticket.actual_hours) }} /
          {{ hours(ticket.estimated_hours) }}
        </span>
      </div>
      <div class="flex flex-col">
        <span class="text-xs uppercase text-slate-400 dark:text-slate-500">
          {{ $t('CASE_TICKETS.WORK_ORDER.FIELDS.RECEIVED_BY') }}
        </span>
        <span class="text-sm font-semibold text-slate-800 dark:text-slate-100">
          {{ ticket.received_by || '—' }}
        </span>
      </div>
      <div class="flex flex-col">
        <span class="text-xs uppercase text-slate-400 dark:text-slate-500">
          {{ $t('CASE_TICKETS.WORK_ORDER.FIELDS.RECEIVED_AT') }}
        </span>
        <span class="text-sm text-slate-700 dark:text-slate-200">
          {{ when(ticket.received_at) }}
        </span>
      </div>
      <div
        v-if="ticket.conformity_note"
        class="flex flex-col flex-1 min-w-[12rem]"
      >
        <span class="text-xs uppercase text-slate-400 dark:text-slate-500">
          {{ $t('CASE_TICKETS.WORK_ORDER.FIELDS.NOTE') }}
        </span>
        <span class="text-sm text-slate-700 dark:text-slate-200">
          {{ ticket.conformity_note }}
        </span>
      </div>
    </div>

    <!-- Abierta: edición en línea -->
    <form
      v-else
      class="flex flex-wrap items-end gap-3 [&_input]:!mb-0"
      @submit.prevent="save"
    >
      <label class="flex flex-col flex-1 gap-1 min-w-[16rem]">
        <span class="text-xs uppercase text-slate-400 dark:text-slate-500">
          {{ $t('CASE_TICKETS.WORK_ORDER.FIELDS.ADDRESS') }}
        </span>
        <input
          v-model="draft.work_address"
          type="text"
          maxlength="255"
          class="h-8 text-sm"
          :placeholder="$t('CASE_TICKETS.WORK_ORDER.FORM.ADDRESS_PLACEHOLDER')"
        />
      </label>
      <label class="flex flex-col w-28 gap-1">
        <span class="text-xs uppercase text-slate-400 dark:text-slate-500">
          {{ $t('CASE_TICKETS.WORK_ORDER.FIELDS.ESTIMATED_HOURS') }}
        </span>
        <input
          v-model="draft.estimated_hours"
          type="number"
          min="0"
          step="0.25"
          class="h-8 text-sm"
        />
      </label>
      <label class="flex flex-col w-28 gap-1">
        <span class="text-xs uppercase text-slate-400 dark:text-slate-500">
          {{ $t('CASE_TICKETS.WORK_ORDER.FIELDS.ACTUAL_HOURS') }}
        </span>
        <input
          v-model="draft.actual_hours"
          type="number"
          min="0"
          step="0.25"
          class="h-8 text-sm"
        />
      </label>
      <label class="flex items-center h-8 gap-2">
        <input v-model="draft.billable" type="checkbox" class="!mb-0" />
        <span class="text-sm text-slate-700 dark:text-slate-200">
          {{ $t('CASE_TICKETS.WORK_ORDER.FIELDS.BILLABLE') }}
        </span>
      </label>
      <div v-if="isDirty" class="flex gap-2 ml-auto">
        <woot-button
          size="small"
          variant="clear"
          color-scheme="secondary"
          type="button"
          @click="discard"
        >
          {{ $t('CASE_TICKETS.WORK_ORDER.PANEL.CANCEL') }}
        </woot-button>
        <woot-button size="small" type="submit" :is-loading="isSaving">
          {{ $t('CASE_TICKETS.WORK_ORDER.PANEL.SAVE') }}
        </woot-button>
      </div>
    </form>

    <!-- Materiales -->
    <div class="flex flex-col gap-1">
      <span class="text-xs uppercase text-slate-400 dark:text-slate-500">
        {{ $t('CASE_TICKETS.WORK_ORDER.ITEMS.TITLE') }}
      </span>
      <table
        v-if="items.length || !isFrozen"
        class="w-full text-sm border-collapse [&_input]:!mb-0 [&_input]:h-8"
      >
        <thead>
          <tr
            class="text-xs text-left text-slate-500 dark:text-slate-400 [&_th]:py-1 [&_th]:pr-2 [&_th]:font-medium"
          >
            <th>{{ $t('CASE_TICKETS.WORK_ORDER.ITEMS.DESCRIPTION') }}</th>
            <th class="w-24">
              {{ $t('CASE_TICKETS.WORK_ORDER.ITEMS.QUANTITY') }}
            </th>
            <th class="w-24">{{ $t('CASE_TICKETS.WORK_ORDER.ITEMS.UNIT') }}</th>
            <th class="w-32">
              {{ $t('CASE_TICKETS.WORK_ORDER.ITEMS.UNIT_COST') }}
            </th>
            <th class="w-32 text-right">
              {{ $t('CASE_TICKETS.WORK_ORDER.ITEMS.TOTAL') }}
            </th>
            <th v-if="!isFrozen" class="w-8" />
          </tr>
        </thead>
        <tbody>
          <tr
            v-for="item in items"
            :key="item.id"
            class="[&_td]:py-1 [&_td]:pr-2 text-slate-700 dark:text-slate-200"
          >
            <template v-if="isFrozen">
              <td>{{ item.description }}</td>
              <td class="tabular-nums">{{ item.quantity }}</td>
              <td>{{ item.unit || '—' }}</td>
              <td class="tabular-nums">{{ money(item.unit_cost) }}</td>
            </template>
            <template v-else>
              <td>
                <input
                  type="text"
                  maxlength="200"
                  class="w-full text-sm"
                  :value="item.description"
                  @change="updateItem(item, 'description', $event.target.value)"
                />
              </td>
              <td>
                <input
                  type="number"
                  min="0.01"
                  step="0.01"
                  class="w-full text-sm"
                  :value="item.quantity"
                  @change="updateItem(item, 'quantity', $event.target.value)"
                />
              </td>
              <td>
                <input
                  type="text"
                  maxlength="30"
                  class="w-full text-sm"
                  :value="item.unit"
                  @change="updateItem(item, 'unit', $event.target.value)"
                />
              </td>
              <td>
                <input
                  type="number"
                  min="0"
                  step="0.01"
                  class="w-full text-sm"
                  :value="item.unit_cost"
                  @change="updateItem(item, 'unit_cost', $event.target.value)"
                />
              </td>
            </template>
            <td class="font-semibold text-right tabular-nums">
              {{ money(item.total) }}
            </td>
            <td v-if="!isFrozen">
              <woot-button
                size="tiny"
                variant="clear"
                color-scheme="alert"
                icon="delete"
                :title="$t('CASE_TICKETS.WORK_ORDER.ITEMS.DELETE')"
                @click="deleteItem(item)"
              />
            </td>
          </tr>
          <!-- Alta de un material -->
          <tr v-if="!isFrozen" class="[&_td]:py-1 [&_td]:pr-2">
            <td>
              <input
                v-model="newItem.description"
                type="text"
                maxlength="200"
                class="w-full text-sm"
                :placeholder="
                  $t('CASE_TICKETS.WORK_ORDER.ITEMS.DESCRIPTION_PLACEHOLDER')
                "
                @keydown.enter.prevent="addItem"
              />
            </td>
            <td>
              <input
                v-model="newItem.quantity"
                type="number"
                min="0.01"
                step="0.01"
                class="w-full text-sm"
              />
            </td>
            <td>
              <input
                v-model="newItem.unit"
                type="text"
                maxlength="30"
                class="w-full text-sm"
              />
            </td>
            <td>
              <input
                v-model="newItem.unit_cost"
                type="number"
                min="0"
                step="0.01"
                class="w-full text-sm"
              />
            </td>
            <td colspan="2" class="text-right">
              <woot-button
                size="small"
                variant="smooth"
                icon="add"
                type="button"
                :is-loading="isSavingItem"
                :disabled="!String(newItem.description).trim()"
                @click="addItem"
              >
                {{ $t('CASE_TICKETS.WORK_ORDER.ITEMS.ADD') }}
              </woot-button>
            </td>
          </tr>
        </tbody>
        <tfoot v-if="hasCosts">
          <tr class="border-t border-slate-200 dark:border-slate-700">
            <td
              colspan="4"
              class="py-1 pr-2 text-xs text-right uppercase text-slate-500 dark:text-slate-400"
            >
              {{ $t('CASE_TICKETS.WORK_ORDER.ITEMS.GRAND_TOTAL') }}
            </td>
            <td
              class="py-1 pr-2 font-semibold text-right tabular-nums text-slate-800 dark:text-slate-100"
            >
              {{ money(ticket.work_order_total) }}
            </td>
            <td v-if="!isFrozen" />
          </tr>
        </tfoot>
      </table>
      <!-- Plan-Catalogo-Cotizaciones — agregar desde el catálogo -->
      <div v-if="!isFrozen" class="mt-2 md:w-1/2">
        <CatalogPicker :allow-free="false" @select="addFromCatalog" />
      </div>
      <p v-else class="m-0 text-sm text-slate-400 dark:text-slate-500">
        {{ $t('CASE_TICKETS.WORK_ORDER.ITEMS.EMPTY') }}
      </p>
    </div>
  </div>
</template>
