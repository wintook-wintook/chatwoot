<script>
export default {
  name: 'ProcessModal',
  props: {
    show: {
      type: Boolean,
      default: false,
    },
    process: {
      type: Object,
      default: null,
    },
  },
  data() {
    return {
      form: {
        kanban_process_id: '',
        default: false,
      },
      errors: {},
    };
  },
  computed: {
    isEditing() {
      return !!this.process;
    },
    modalTitle() {
      return this.isEditing
        ? this.$t('KANBAN.PROCESSES.EDIT_MODAL_TITLE')
        : this.$t('KANBAN.PROCESSES.CREATE_MODAL_TITLE');
    },
  },
  watch: {
    process: {
      immediate: true,
      handler(newVal) {
        if (newVal) {
          this.form = {
            kanban_process_id: newVal.kanban_process_id || '',
            default: newVal.default || false,
          };
        } else {
          this.resetForm();
        }
      },
    },
  },
  methods: {
    resetForm() {
      this.form = {
        kanban_process_id: '',
        default: false,
      };
      this.errors = {};
    },
    validateForm() {
      this.errors = {};
      
      if (!this.form.kanban_process_id.trim()) {
        this.errors.kanban_process_id = this.$t('KANBAN.PROCESSES.VALIDATIONS.KANBAN_PROCESS_ID_REQUIRED');
      }
      
      return Object.keys(this.errors).length === 0;
    },
    handleSave() {
      if (this.validateForm()) {
        this.$emit('save', { ...this.form });
      }
    },
    handleClose() {
      this.resetForm();
      this.$emit('close');
    },
  },
};
</script>

<template>
  <woot-modal
    :show="show"
    :on-close="handleClose"
    size="medium"
  >
    <template #header>
      <h2 class="text-xl font-semibold text-slate-900 dark:text-slate-100">
        {{ modalTitle }}
      </h2>
    </template>
    
    <template #body>
      <form @submit.prevent="handleSave">
        <div class="space-y-4">
          <!-- Kanban Process ID -->
          <div>
            <label class="block text-sm font-medium text-slate-700 dark:text-slate-300">
              {{ $t('KANBAN.PROCESSES.FORM.KANBAN_PROCESS_ID') }}
              <span class="text-red-500">*</span>
            </label>
            <input
              v-model="form.kanban_process_id"
              type="text"
              class="w-full px-3 py-2 mt-1 border rounded-md border-slate-300 dark:border-slate-600 bg-white dark:bg-slate-800"
              :class="{ 'border-red-500': errors.kanban_process_id }"
              :placeholder="$t('KANBAN.PROCESSES.FORM.KANBAN_PROCESS_ID_PLACEHOLDER')"
            />
            <p v-if="errors.kanban_process_id" class="mt-1 text-sm text-red-500">
              {{ errors.kanban_process_id }}
            </p>
          </div>
          
          <!-- Default -->
          <div class="flex items-center">
            <input
              id="process-default"
              v-model="form.default"
              type="checkbox"
              class="w-4 h-4 text-woot-600 border-slate-300 rounded focus:ring-woot-500"
            />
            <label for="process-default" class="ml-2 text-sm text-slate-700 dark:text-slate-300">
              {{ $t('KANBAN.PROCESSES.FORM.DEFAULT') }}
            </label>
          </div>
        </div>
      </form>
    </template>
    
    <template #footer>
      <div class="flex justify-end space-x-2">
        <woot-button
          variant="clear"
          @click="handleClose"
        >
          {{ $t('KANBAN.PROCESSES.FORM.CANCEL') }}
        </woot-button>
        <woot-button
          color-scheme="primary"
          @click="handleSave"
        >
          {{ isEditing ? $t('KANBAN.PROCESSES.FORM.UPDATE') : $t('KANBAN.PROCESSES.FORM.CREATE') }}
        </woot-button>
      </div>
    </template>
  </woot-modal>
</template>