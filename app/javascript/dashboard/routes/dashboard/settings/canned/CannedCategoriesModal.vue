<script>
// proyecto@respuestas_predefinidas R3 — LAS CATEGORÍAS
// ============================================================================
// Plan: docs/respuestas_predefinidas_plan.md §2. Crear, renombrar y borrar categorías
// (borrar deja sus respuestas sin categoría), y las SUGERIDAS por el principio de los
// nombres (D3): «PATITAS (14 respuestas · la usa 1 agente) [Crear y asignar]». Nada se
// mueve solo: la persona acepta cada una.
//
// El nombre es el que se escribe en @buscar_predefinidas(NOMBRE): sin paréntesis y sin
// «!» al principio (lo valida también el servidor).
// ============================================================================
import CategoryAPI from 'dashboard/api/cannedResponseCategory';
import { useAlert } from 'dashboard/composables';

const INVALID_NAME = /[()]|^!/;

export default {
  props: {
    show: { type: Boolean, default: false },
  },
  emits: ['close', 'changed'],
  data() {
    return {
      categories: [],
      suggestions: [],
      newName: '',
      editingId: null,
      editingName: '',
      confirmingId: null,
      busy: false,
    };
  },
  computed: {
    newNameInvalid() {
      return INVALID_NAME.test(this.newName.trim());
    },
  },
  watch: {
    show(abierto) {
      if (abierto) this.load();
    },
  },
  methods: {
    async load() {
      try {
        const [lista, sugeridas] = await Promise.all([
          CategoryAPI.get(),
          CategoryAPI.suggestions(),
        ]);
        this.categories = lista.data || [];
        this.suggestions = sugeridas.data || [];
      } catch (error) {
        useAlert(this.$t('CANNED_MGMT.CATEGORIES.LOAD_ERROR'));
      }
    },
    async run(accion) {
      this.busy = true;
      try {
        await accion();
        await this.load();
        this.$emit('changed');
      } catch (error) {
        useAlert(this.$t('CANNED_MGMT.CATEGORIES.SAVE_ERROR'));
      } finally {
        this.busy = false;
      }
    },
    create() {
      const nombre = this.newName.trim();
      if (!nombre || this.newNameInvalid) return;
      this.run(async () => {
        await CategoryAPI.create({
          canned_response_category: { name: nombre },
        });
        this.newName = '';
      });
    },
    startEdit(categoria) {
      this.editingId = categoria.id;
      this.editingName = categoria.name;
    },
    saveEdit() {
      const nombre = this.editingName.trim();
      if (!nombre || INVALID_NAME.test(nombre)) return;
      const id = this.editingId;
      this.run(async () => {
        await CategoryAPI.update(id, {
          canned_response_category: { name: nombre },
        });
        this.editingId = null;
      });
    },
    remove(categoria) {
      this.confirmingId = null;
      this.run(() => CategoryAPI.delete(categoria.id));
    },
    accept(sugerida) {
      this.run(() =>
        CategoryAPI.createWith(sugerida.name, sugerida.canned_ids)
      );
    },
  },
};
</script>

<template>
  <woot-modal :show="show" size="medium" :on-close="() => $emit('close')">
    <div class="flex flex-col gap-5 p-8 text-sm">
      <div>
        <h2
          class="!m-0 text-base font-semibold text-slate-800 dark:text-slate-50"
        >
          {{ $t('CANNED_MGMT.CATEGORIES.TITLE') }}
        </h2>
        <p class="!mt-1 !mb-0 text-slate-600 dark:text-slate-300">
          {{ $t('CANNED_MGMT.CATEGORIES.HINT') }}
        </p>
      </div>

      <form class="flex items-start gap-2" @submit.prevent="create">
        <div class="flex-1">
          <input
            v-model="newName"
            type="text"
            class="w-full !mb-0"
            :placeholder="$t('CANNED_MGMT.CATEGORIES.NEW_PLACEHOLDER')"
          />
          <p
            v-if="newNameInvalid"
            class="!m-0 mt-1 text-xs text-red-600 dark:text-red-400"
          >
            {{ $t('CANNED_MGMT.CATEGORIES.INVALID_NAME') }}
          </p>
        </div>
        <woot-button
          icon="add"
          size="small"
          :is-disabled="!newName.trim() || newNameInvalid || busy"
        >
          {{ $t('CANNED_MGMT.CATEGORIES.ADD') }}
        </woot-button>
      </form>

      <div class="flex flex-col">
        <p
          v-if="!categories.length"
          class="!m-0 text-slate-500 dark:text-slate-400"
        >
          {{ $t('CANNED_MGMT.CATEGORIES.EMPTY') }}
        </p>
        <div
          v-for="categoria in categories"
          :key="categoria.id"
          class="flex items-center gap-2 py-2 border-b border-slate-50 dark:border-slate-800"
          @mouseleave="confirmingId = null"
        >
          <template v-if="editingId === categoria.id">
            <input
              v-model="editingName"
              type="text"
              class="flex-1 !mb-0"
              @keydown.enter.prevent="saveEdit"
            />
            <woot-button size="tiny" :is-disabled="busy" @click="saveEdit">
              {{ $t('CANNED_MGMT.CATEGORIES.SAVE') }}
            </woot-button>
            <woot-button
              size="tiny"
              variant="clear"
              color-scheme="secondary"
              @click="editingId = null"
            >
              {{ $t('CANNED_MGMT.CATEGORIES.CANCEL') }}
            </woot-button>
          </template>
          <template v-else>
            <span
              class="flex-1 font-medium font-mono text-slate-800 dark:text-slate-100"
            >
              {{ categoria.name }}
            </span>
            <span class="text-xs text-slate-500 dark:text-slate-400">
              {{
                $t('CANNED_MGMT.CATEGORIES.COUNT', {
                  count: categoria.canned_count,
                })
              }}
            </span>
            <woot-button
              v-tooltip="$t('CANNED_MGMT.CATEGORIES.RENAME')"
              size="tiny"
              variant="clear"
              color-scheme="secondary"
              icon="edit"
              @click="startEdit(categoria)"
            />
            <woot-button
              v-if="confirmingId !== categoria.id"
              v-tooltip="$t('CANNED_MGMT.CATEGORIES.DELETE')"
              size="tiny"
              variant="clear"
              color-scheme="secondary"
              icon="delete"
              @click="confirmingId = categoria.id"
            />
            <woot-button
              v-else
              size="tiny"
              variant="smooth"
              color-scheme="alert"
              :is-disabled="busy"
              @click="remove(categoria)"
            >
              {{ $t('CANNED_MGMT.CATEGORIES.DELETE_CONFIRM') }}
            </woot-button>
          </template>
        </div>
        <p
          v-if="confirmingId"
          class="!m-0 mt-1 text-xs text-slate-500 dark:text-slate-400"
        >
          {{ $t('CANNED_MGMT.CATEGORIES.DELETE_HINT') }}
        </p>
      </div>

      <div v-if="suggestions.length" class="flex flex-col gap-2">
        <h3
          class="!m-0 text-sm font-semibold text-slate-800 dark:text-slate-100"
        >
          {{ $t('CANNED_MGMT.CATEGORIES.SUGGESTED') }}
        </h3>
        <p class="!m-0 text-xs text-slate-500 dark:text-slate-400">
          {{ $t('CANNED_MGMT.CATEGORIES.SUGGESTED_HINT') }}
        </p>
        <div
          v-for="sugerida in suggestions"
          :key="sugerida.name"
          class="flex items-center gap-2 py-1"
        >
          <span
            class="font-mono font-medium text-slate-800 dark:text-slate-100"
          >
            {{ sugerida.name }}
          </span>
          <span class="flex-1 text-xs text-slate-500 dark:text-slate-400">
            {{
              $t('CANNED_MGMT.CATEGORIES.SUGGESTED_COUNT', {
                count: sugerida.count,
              })
            }}
            <template v-if="sugerida.agents">
              ·
              {{
                $t('CANNED_MGMT.CATEGORIES.SUGGESTED_AGENTS', {
                  count: sugerida.agents,
                })
              }}
            </template>
          </span>
          <woot-button
            size="tiny"
            variant="smooth"
            icon="add"
            :is-disabled="busy"
            @click="accept(sugerida)"
          >
            {{ $t('CANNED_MGMT.CATEGORIES.ACCEPT') }}
          </woot-button>
        </div>
      </div>

      <div class="flex justify-end">
        <woot-button
          variant="clear"
          color-scheme="secondary"
          @click="$emit('close')"
        >
          {{ $t('CANNED_MGMT.CATEGORIES.CLOSE') }}
        </woot-button>
      </div>
    </div>
  </woot-modal>
</template>
