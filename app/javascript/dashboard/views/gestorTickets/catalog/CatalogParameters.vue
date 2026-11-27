<!--
  Productos y servicios › Parámetros — las listas que se eligen en el producto, en una sola pestaña:
    Categorías          con subcategorías de un nivel (Refacciones › Frenos)
    Impuestos           el marcado es el de por omisión (productos sin impuesto propio y partidas libres)
    Retenciones         Ret. IVA, Ret. ISR…: el producto lleva las suyas; la cotización las resta si es persona moral
    Unidades de medida  nombre, abreviatura (la que sale en las partidas) y clave SAT opcional
  Se edita en el mismo renglón. Lo que está en uso no se borra: se desactiva (ya no se ofrece al elegir).
  Lo cambia quien edita el catálogo (canEdit); los demás solo lo ven.
-->
<script>
import { useAlert } from 'dashboard/composables';
import CatalogItemsAPI from 'dashboard/api/catalogItems';

const BLANK = {
  categories: () => ({ name: '' }),
  taxes: () => ({ name: '', percent: 16, exempt: false }),
  units: () => ({ name: '', abbreviation: '', sat_code: '' }),
};

export default {
  name: 'CatalogParameters',
  props: {
    params: { type: Object, required: true },
  },
  emits: ['update:params'],
  data() {
    // editing: { list, id, form } · adding: { list, parentId, form }
    return { editing: null, adding: null, saving: false };
  },
  computed: {
    canEdit() {
      return !!this.params.can_edit;
    },
    categories() {
      return this.params.categories || [];
    },
    taxes() {
      return this.params.taxes || [];
    },
    // Trasladados (IVA…) y retenciones (Ret. IVA, Ret. ISR…): dos bloques de la misma lista.
    taxGroups() {
      return [
        { kind: 'transfer', key: 'TAXES' },
        { kind: 'withholding', key: 'WITHHOLDINGS' },
      ].map(group => ({
        ...group,
        rows: this.taxes.filter(tax => (tax.kind || 'transfer') === group.kind),
      }));
    },
    units() {
      return this.params.units || [];
    },
  },
  methods: {
    t(key, values) {
      return this.$t(`CATALOG.PARAMS.${key}`, values);
    },
    isEditing(list, id) {
      return (
        this.editing && this.editing.list === list && this.editing.id === id
      );
    },
    isAdding(list, parentId = null) {
      return (
        this.adding &&
        this.adding.list === list &&
        this.adding.parentId === parentId
      );
    },
    startEdit(list, row) {
      const { id, items, children, path, ...form } = row;
      this.adding = null;
      this.editing = { list, id, form };
    },
    startAdd(list, parentId = null, extra = {}) {
      this.editing = null;
      this.adding = { list, parentId, form: { ...BLANK[list](), ...extra } };
    },
    cancel() {
      this.editing = null;
      this.adding = null;
    },
    async request(call) {
      this.saving = true;
      try {
        const { data } = await call();
        this.$emit('update:params', data);
        this.cancel();
        return true;
      } catch (error) {
        const message = error?.response?.data?.error;
        useAlert(Array.isArray(message) ? message.join(', ') : this.t('ERROR'));
        return false;
      } finally {
        this.saving = false;
      }
    },
    saveEdit() {
      const { list, id, form } = this.editing;
      return this.request(() => CatalogItemsAPI.saveParameter(list, form, id));
    },
    saveAdd() {
      const { list, parentId, form } = this.adding;
      if (!String(form.name || '').trim()) return null;
      const record = parentId ? { ...form, parent_id: parentId } : form;
      return this.request(() => CatalogItemsAPI.saveParameter(list, record));
    },
    toggle(list, row) {
      return this.request(() =>
        CatalogItemsAPI.saveParameter(list, { active: !row.active }, row.id)
      );
    },
    makeDefault(tax) {
      if (!this.canEdit || tax.is_default) return null;
      return this.request(() =>
        CatalogItemsAPI.saveParameter(
          'taxes',
          { is_default: true, active: true },
          tax.id
        )
      );
    },
    remove(list, row) {
      // eslint-disable-next-line no-alert
      if (!window.confirm(this.t('DELETE_CONFIRM', { name: row.name }))) {
        return null;
      }
      return this.request(() => CatalogItemsAPI.removeParameter(list, row.id));
    },
    removable(row) {
      return !row.items && !(row.children || []).length && !row.is_default;
    },
    count(items) {
      return this.$tc('CATALOG.PARAMS.ITEMS', items, { count: items });
    },
    percent(tax) {
      if (tax.exempt) return '—';
      // Hasta 4 decimales (Ret. IVA 10.6667 %), sin ceros de más.
      return `${Number(Number(tax.percent).toFixed(4))} %`;
    },
  },
};
</script>

<template>
  <div class="flex flex-col max-w-4xl gap-4">
    <p class="m-0 text-sm text-slate-600 dark:text-slate-300">
      {{ t('HINT') }}
    </p>

    <!-- Categorías -->
    <section class="param-box">
      <header class="flex items-start justify-between gap-2">
        <div>
          <h2 class="param-title">{{ t('CATEGORIES.TITLE') }}</h2>
          <p class="param-hint">{{ t('CATEGORIES.HINT') }}</p>
        </div>
        <woot-button
          v-if="canEdit"
          size="small"
          variant="smooth"
          icon="add"
          @click="startAdd('categories')"
        >
          {{ t('ADD') }}
        </woot-button>
      </header>
      <form
        v-if="isAdding('categories')"
        class="param-row"
        @submit.prevent="saveAdd"
      >
        <input
          v-model="adding.form.name"
          type="text"
          maxlength="80"
          class="param-input flex-1"
          :placeholder="t('CATEGORIES.NAME')"
        />
        <woot-button size="small" :is-loading="saving">
          {{ t('SAVE') }}
        </woot-button>
        <woot-button size="small" variant="clear" type="button" @click="cancel">
          {{ t('CANCEL') }}
        </woot-button>
      </form>
      <p v-if="!categories.length" class="param-hint">
        {{ t('CATEGORIES.EMPTY') }}
      </p>
      <template v-for="category in categories">
        <div
          :key="`c${category.id}`"
          class="param-row"
          :class="{ 'opacity-60': !category.active }"
        >
          <form
            v-if="isEditing('categories', category.id)"
            class="flex items-center flex-1 gap-2"
            @submit.prevent="saveEdit"
          >
            <input
              v-model="editing.form.name"
              type="text"
              maxlength="80"
              class="param-input flex-1"
            />
            <woot-button size="small" :is-loading="saving">
              {{ t('SAVE') }}
            </woot-button>
            <woot-button
              size="small"
              variant="clear"
              type="button"
              @click="cancel"
            >
              {{ t('CANCEL') }}
            </woot-button>
          </form>
          <template v-else>
            <span class="flex-1 min-w-0 truncate font-medium">
              {{ category.name }}
              <span v-if="!category.active" class="param-tag">
                {{ t('INACTIVE') }}
              </span>
            </span>
            <span class="param-count">
              {{ count(category.items) }}
            </span>
            <div v-if="canEdit" class="param-actions">
              <woot-button
                v-tooltip="t('CATEGORIES.ADD_CHILD')"
                variant="clear"
                color-scheme="secondary"
                size="small"
                icon="add"
                @click="startAdd('categories', category.id)"
              />
              <woot-button
                v-tooltip="t('EDIT')"
                variant="clear"
                color-scheme="secondary"
                size="small"
                icon="edit"
                @click="startEdit('categories', category)"
              />
              <span class="param-slot">
                <woot-button
                  v-if="removable(category)"
                  v-tooltip="t('DELETE')"
                  variant="clear"
                  color-scheme="alert"
                  size="small"
                  icon="delete"
                  @click="remove('categories', category)"
                />
                <button
                  v-else
                  type="button"
                  class="param-link"
                  @click="toggle('categories', category)"
                >
                  {{ category.active ? t('DEACTIVATE') : t('ACTIVATE') }}
                </button>
              </span>
            </div>
          </template>
        </div>
        <div
          v-for="child in category.children"
          :key="`s${child.id}`"
          class="param-row param-child"
          :class="{ 'opacity-60': !child.active }"
        >
          <form
            v-if="isEditing('categories', child.id)"
            class="flex items-center flex-1 gap-2"
            @submit.prevent="saveEdit"
          >
            <input
              v-model="editing.form.name"
              type="text"
              maxlength="80"
              class="param-input flex-1"
            />
            <woot-button size="small" :is-loading="saving">
              {{ t('SAVE') }}
            </woot-button>
            <woot-button
              size="small"
              variant="clear"
              type="button"
              @click="cancel"
            >
              {{ t('CANCEL') }}
            </woot-button>
          </form>
          <template v-else>
            <span class="flex-1 min-w-0 truncate">
              {{ child.name }}
              <span v-if="!child.active" class="param-tag">
                {{ t('INACTIVE') }}
              </span>
            </span>
            <span class="param-count">
              {{ count(child.items) }}
            </span>
            <div v-if="canEdit" class="param-actions">
              <woot-button
                v-tooltip="t('EDIT')"
                variant="clear"
                color-scheme="secondary"
                size="small"
                icon="edit"
                @click="startEdit('categories', child)"
              />
              <span class="param-slot">
                <woot-button
                  v-if="removable(child)"
                  v-tooltip="t('DELETE')"
                  variant="clear"
                  color-scheme="alert"
                  size="small"
                  icon="delete"
                  @click="remove('categories', child)"
                />
                <button
                  v-else
                  type="button"
                  class="param-link"
                  @click="toggle('categories', child)"
                >
                  {{ child.active ? t('DEACTIVATE') : t('ACTIVATE') }}
                </button>
              </span>
            </div>
          </template>
        </div>
        <form
          v-if="isAdding('categories', category.id)"
          :key="`n${category.id}`"
          class="param-row param-child"
          @submit.prevent="saveAdd"
        >
          <input
            v-model="adding.form.name"
            type="text"
            maxlength="80"
            class="param-input flex-1"
            :placeholder="t('CATEGORIES.CHILD_NAME')"
          />
          <woot-button size="small" :is-loading="saving">
            {{ t('SAVE') }}
          </woot-button>
          <woot-button
            size="small"
            variant="clear"
            type="button"
            @click="cancel"
          >
            {{ t('CANCEL') }}
          </woot-button>
        </form>
      </template>
    </section>

    <!-- Impuestos trasladados y retenciones (misma lista, por tipo) -->
    <section v-for="group in taxGroups" :key="group.kind" class="param-box">
      <header class="flex items-start justify-between gap-2">
        <div>
          <h2 class="param-title">{{ t(`${group.key}.TITLE`) }}</h2>
          <p class="param-hint">{{ t(`${group.key}.HINT`) }}</p>
        </div>
        <woot-button
          v-if="canEdit"
          size="small"
          variant="smooth"
          icon="add"
          @click="startAdd('taxes', null, { kind: group.kind })"
        >
          {{ t('ADD') }}
        </woot-button>
      </header>
      <form
        v-if="isAdding('taxes') && adding.form.kind === group.kind"
        class="param-row"
        @submit.prevent="saveAdd"
      >
        <input
          v-model="adding.form.name"
          type="text"
          maxlength="60"
          class="param-input flex-1"
          :placeholder="t('TAXES.NAME')"
        />
        <input
          v-model="adding.form.percent"
          type="number"
          min="0"
          max="100"
          step="0.0001"
          class="param-input !w-24"
          :disabled="adding.form.exempt"
        />
        <label
          v-if="group.kind === 'transfer'"
          class="flex items-center gap-1 mb-0 text-sm"
        >
          <input v-model="adding.form.exempt" type="checkbox" class="m-0" />
          {{ t('TAXES.EXEMPT') }}
        </label>
        <woot-button size="small" :is-loading="saving">
          {{ t('SAVE') }}
        </woot-button>
        <woot-button size="small" variant="clear" type="button" @click="cancel">
          {{ t('CANCEL') }}
        </woot-button>
      </form>
      <div
        v-for="tax in group.rows"
        :key="tax.id"
        class="param-row"
        :class="{ 'opacity-60': !tax.active }"
      >
        <form
          v-if="isEditing('taxes', tax.id)"
          class="flex flex-wrap items-center flex-1 gap-2"
          @submit.prevent="saveEdit"
        >
          <input
            v-model="editing.form.name"
            type="text"
            maxlength="60"
            class="param-input flex-1"
          />
          <input
            v-model="editing.form.percent"
            type="number"
            min="0"
            max="100"
            step="0.0001"
            class="param-input !w-24"
            :disabled="editing.form.exempt"
          />
          <label
            v-if="group.kind === 'transfer'"
            class="flex items-center gap-1 mb-0 text-sm"
          >
            <input v-model="editing.form.exempt" type="checkbox" class="m-0" />
            {{ t('TAXES.EXEMPT') }}
          </label>
          <woot-button size="small" :is-loading="saving">
            {{ t('SAVE') }}
          </woot-button>
          <woot-button
            size="small"
            variant="clear"
            type="button"
            @click="cancel"
          >
            {{ t('CANCEL') }}
          </woot-button>
        </form>
        <template v-else>
          <input
            v-if="group.kind === 'transfer'"
            v-tooltip="
              tax.is_default ? t('TAXES.DEFAULT') : t('TAXES.MAKE_DEFAULT')
            "
            type="radio"
            name="default-tax"
            class="m-0"
            :checked="tax.is_default"
            :disabled="!canEdit || !tax.active || saving"
            @change="makeDefault(tax)"
          />
          <span class="flex-1 min-w-0 truncate font-medium">
            {{ tax.name }}
            <span v-if="tax.is_default" class="param-tag !text-woot-600">
              {{ t('TAXES.DEFAULT') }}
            </span>
            <span v-if="!tax.active" class="param-tag">
              {{ t('INACTIVE') }}
            </span>
          </span>
          <span class="w-20 shrink-0 text-right tabular-nums">{{
            percent(tax)
          }}</span>
          <span class="param-count">
            {{ count(tax.items) }}
          </span>
          <div v-if="canEdit" class="param-actions">
            <woot-button
              v-tooltip="t('EDIT')"
              variant="clear"
              color-scheme="secondary"
              size="small"
              icon="edit"
              @click="startEdit('taxes', tax)"
            />
            <span class="param-slot">
              <woot-button
                v-if="removable(tax)"
                v-tooltip="t('DELETE')"
                variant="clear"
                color-scheme="alert"
                size="small"
                icon="delete"
                @click="remove('taxes', tax)"
              />
              <button
                v-else-if="!tax.is_default"
                type="button"
                class="param-link"
                @click="toggle('taxes', tax)"
              >
                {{ tax.active ? t('DEACTIVATE') : t('ACTIVATE') }}
              </button>
            </span>
          </div>
        </template>
      </div>
    </section>

    <!-- Unidades de medida -->
    <section class="param-box">
      <header class="flex items-start justify-between gap-2">
        <div>
          <h2 class="param-title">{{ t('UNITS.TITLE') }}</h2>
          <p class="param-hint">{{ t('UNITS.HINT') }}</p>
        </div>
        <woot-button
          v-if="canEdit"
          size="small"
          variant="smooth"
          icon="add"
          @click="startAdd('units')"
        >
          {{ t('ADD') }}
        </woot-button>
      </header>
      <form
        v-if="isAdding('units')"
        class="param-row"
        @submit.prevent="saveAdd"
      >
        <input
          v-model="adding.form.name"
          type="text"
          maxlength="60"
          class="param-input flex-1"
          :placeholder="t('UNITS.NAME')"
        />
        <input
          v-model="adding.form.abbreviation"
          type="text"
          maxlength="20"
          class="param-input !w-28"
          :placeholder="t('UNITS.ABBREVIATION')"
        />
        <input
          v-model="adding.form.sat_code"
          type="text"
          maxlength="10"
          class="param-input !w-24 uppercase"
          :placeholder="t('UNITS.SAT_CODE')"
        />
        <woot-button size="small" :is-loading="saving">
          {{ t('SAVE') }}
        </woot-button>
        <woot-button size="small" variant="clear" type="button" @click="cancel">
          {{ t('CANCEL') }}
        </woot-button>
      </form>
      <div
        v-for="unit in units"
        :key="unit.id"
        class="param-row"
        :class="{ 'opacity-60': !unit.active }"
      >
        <form
          v-if="isEditing('units', unit.id)"
          class="flex flex-wrap items-center flex-1 gap-2"
          @submit.prevent="saveEdit"
        >
          <input
            v-model="editing.form.name"
            type="text"
            maxlength="60"
            class="param-input flex-1"
          />
          <input
            v-model="editing.form.abbreviation"
            type="text"
            maxlength="20"
            class="param-input !w-28"
          />
          <input
            v-model="editing.form.sat_code"
            type="text"
            maxlength="10"
            class="param-input !w-24 uppercase"
            :placeholder="t('UNITS.SAT_CODE')"
          />
          <woot-button size="small" :is-loading="saving">
            {{ t('SAVE') }}
          </woot-button>
          <woot-button
            size="small"
            variant="clear"
            type="button"
            @click="cancel"
          >
            {{ t('CANCEL') }}
          </woot-button>
        </form>
        <template v-else>
          <span class="flex-1 min-w-0 truncate font-medium">
            {{ unit.name }}
            <span v-if="!unit.active" class="param-tag">
              {{ t('INACTIVE') }}
            </span>
          </span>
          <span class="w-16 shrink-0 font-mono text-xs">{{
            unit.abbreviation
          }}</span>
          <span class="w-20 shrink-0 text-xs text-slate-500">
            {{ unit.sat_code ? `SAT ${unit.sat_code}` : '' }}
          </span>
          <span class="param-count">
            {{ count(unit.items) }}
          </span>
          <div v-if="canEdit" class="param-actions">
            <woot-button
              v-tooltip="t('EDIT')"
              variant="clear"
              color-scheme="secondary"
              size="small"
              icon="edit"
              @click="startEdit('units', unit)"
            />
            <span class="param-slot">
              <woot-button
                v-if="removable(unit)"
                v-tooltip="t('DELETE')"
                variant="clear"
                color-scheme="alert"
                size="small"
                icon="delete"
                @click="remove('units', unit)"
              />
              <button
                v-else
                type="button"
                class="param-link"
                @click="toggle('units', unit)"
              >
                {{ unit.active ? t('DEACTIVATE') : t('ACTIVATE') }}
              </button>
            </span>
          </div>
        </template>
      </div>
    </section>
  </div>
</template>

<style scoped>
.param-box {
  @apply flex flex-col gap-1 p-4 border rounded-lg border-slate-75 dark:border-slate-700;
}
.param-title {
  @apply m-0 text-base font-semibold text-slate-800 dark:text-slate-100;
}
.param-hint {
  @apply m-0 text-xs text-slate-500 dark:text-slate-400;
}
.param-row {
  @apply flex items-center gap-3 min-h-[2.5rem] py-1 text-sm border-b border-slate-50 dark:border-slate-800 last:border-b-0;
}
.param-child {
  @apply ml-4 pl-3 border-l-2 border-l-slate-100 dark:border-l-slate-700;
}
.param-input {
  @apply !mb-0 !h-8 !py-0 text-sm;
}
.param-count {
  @apply w-28 shrink-0 text-xs text-right whitespace-nowrap text-slate-500;
}
.param-actions {
  @apply flex items-center justify-end gap-1 w-40 shrink-0 whitespace-nowrap;
}
.param-slot {
  @apply flex justify-end w-20;
}
.param-link {
  @apply px-1 text-xs text-woot-600 hover:underline;
}
.param-tag {
  @apply ml-1 text-[11px] font-normal text-slate-500;
}
</style>
