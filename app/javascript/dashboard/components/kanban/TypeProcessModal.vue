<script>
export default {
  name: 'TypeProcessModal',
  props: {
    show: {
      type: Boolean,
      default: false,
    },
    typeProcess: {
      type: Object,
      default: null,
    },
  },
  data() {
    return {
      form: {
        type_process_name: '',
        default: false,
        position: 1,
      },
      errors: {},
    };
  },
  computed: {
    isEditing() {
      return !!(this.typeProcess && this.typeProcess.id);
    },
    modalTitle() {
      return this.isEditing
        ? this.$t('KANBAN.TYPE_PROCESSES.EDIT_MODAL_TITLE')
        : this.$t('KANBAN.TYPE_PROCESSES.CREATE_MODAL_TITLE');
    },
  },
  watch: {
    typeProcess: {
      immediate: true,
      handler(newVal) {
        if (newVal && newVal.id) {
          this.form = {
            type_process_name: newVal.type_process_name || '',
            default: newVal.default || false,
            position: newVal.position || 1,
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
        type_process_name: '',
        default: false,
        position: 1,
      };
      this.errors = {};
    },
    validateForm() {
      this.errors = {};
      
      if (!this.form.type_process_name.trim()) {
        this.errors.type_process_name = this.$t('KANBAN.TYPE_PROCESSES.VALIDATIONS.TYPE_PROCESS_NAME_REQUIRED');
      }
      
      if (!this.form.position || this.form.position < 1) {
        this.errors.position = this.$t('KANBAN.TYPE_PROCESSES.VALIDATIONS.POSITION_REQUIRED');
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
          <!-- Type Process Name -->
          <div>
            <label class="block text-sm font-medium text-slate-700 dark:text-slate-300">
              {{ $t('KANBAN.TYPE_PROCESSES.FORM.TYPE_PROCESS_NAME') }}
              <span class="text-red-500">*</span>
            </label>
            <input
              v-model="form.type_process_name"
              type="text"
              class="w-full px-3 py-2 mt-1 border rounded-md border-slate-300 dark:border-slate-600 bg-white dark:bg-slate-800"
              :class="{ 'border-red-500': errors.type_process_name }"
              :placeholder="$t('KANBAN.TYPE_PROCESSES.FORM.TYPE_PROCESS_NAME_PLACEHOLDER')"
            />
            <p v-if="errors.type_process_name" class="mt-1 text-sm text-red-500">
              {{ errors.type_process_name }}
            </p>
          </div>
          
          <!-- Position -->
          <div>
            <label class="block text-sm font-medium text-slate-700 dark:text-slate-300">
              {{ $t('KANBAN.TYPE_PROCESSES.FORM.POSITION') }}
              <span class="text-red-500">*</span>
            </label>
            <input
              v-model.number="form.position"
              type="number"
              min="1"
              class="w-full px-3 py-2 mt-1 border rounded-md border-slate-300 dark:border-slate-600 bg-white dark:bg-slate-800"
              :class="{ 'border-red-500': errors.position }"
            />
            <p v-if="errors.position" class="mt-1 text-sm text-red-500">
              {{ errors.position }}
            </p>
          </div>
          
          <!-- Default -->
          <div class="flex items-center">
            <input
              id="type-process-default"
              v-model="form.default"
              type="checkbox"
              class="w-4 h-4 text-woot-600 border-slate-300 rounded focus:ring-woot-500"
            />
            <label for="type-process-default" class="ml-2 text-sm text-slate-700 dark:text-slate-300">
              {{ $t('KANBAN.TYPE_PROCESSES.FORM.DEFAULT') }}
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
          {{ $t('KANBAN.TYPE_PROCESSES.FORM.CANCEL') }}
        </woot-button>
        <woot-button
          color-scheme="primary"
          @click="handleSave"
        >
          {{ isEditing ? $t('KANBAN.TYPE_PROCESSES.FORM.UPDATE') : $t('KANBAN.TYPE_PROCESSES.FORM.CREATE') }}
        </woot-button>
      </div>
    </template>
  </woot-modal>
</template>