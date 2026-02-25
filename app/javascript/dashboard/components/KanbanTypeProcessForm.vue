<!-- 
  app/javascript/dashboard/components/KanbanTypeProcessForm.vue 
  KANBAN0725
-->
<template>
    <div class="kanban-type-process-form">
      <div class="modal-header">
        <h3 class="modal-title">
          {{ isEditing ? 'Edit kanban type process' : 'Add new kanban type process' }}
        </h3>
      </div>
  
      <form @submit.prevent="handleSubmit">
        <div class="modal-body">
          <div class="form-group">
            <label class="form-label" for="process-name">
              Name
              <span class="required-indicator">*</span>
            </label>
            <woot-input
              id="process-name"
              v-model="formData.name"
              placeholder="Enter process type name"
              :error="errors.name"
              required
            />
            <span v-if="errors.name" class="error-message">
              {{ errors.name }}
            </span>
          </div>
  
          <div class="form-group">
            <label class="form-label" for="process-description">
              Description
            </label>
            <woot-input
              id="process-description"
              v-model="formData.description"
              type="textarea"
              placeholder="Enter a description for this process type"
              :error="errors.description"
              rows="3"
            />
            <span v-if="errors.description" class="error-message">
              {{ errors.description }}
            </span>
          </div>
  
          <div class="form-group">
            <label class="form-label">
              Options
            </label>
            <div class="checkbox-group">
              <woot-checkbox
                v-model="formData.default"
                label="Set as default process"
              />
              <woot-checkbox
                v-model="formData.is_system"
                label="System process (managed by Chatwoot)"
                :disabled="!canSetSystemFlag"
              />
            </div>
          </div>
  
          <div v-if="isEditing && process" class="form-group">
            <label class="form-label">
              Metadata
            </label>
            <div class="metadata-info">
              <div class="metadata-item">
                <span class="metadata-label">Created at:</span>
                <span class="metadata-value">{{ formatDate(process.created_at) }}</span>
              </div>
              <div class="metadata-item">
                <span class="metadata-label">Updated at:</span>
                <span class="metadata-value">{{ formatDate(process.updated_at) }}</span>
              </div>
            </div>
          </div>
        </div>
  
        <div class="modal-footer">
          <woot-button
            variant="clear"
            @click="$emit('cancel')"
          >
            Cancel
          </woot-button>
          <woot-button
            type="submit"
            color-scheme="primary"
            :loading="isSubmitting"
          >
            {{ isEditing ? 'Update type process' : 'Create type process' }}
          </woot-button>
        </div>
      </form>
    </div>
  </template>
  
  <script>
  import { format } from 'date-fns';
  
  export default {
    name: 'KanbanTypeProcessForm',
    props: {
      process: {
        type: Object,
        default: null,
      },
      isEditing: {
        type: Boolean,
        default: false,
      },
    },
    data() {
      return {
        formData: {
          name: '',
          description: '',
          default: false,
          is_system: false,
        },
        errors: {},
        isSubmitting: false,
      };
    },
    computed: {
      canSetSystemFlag() {
        // Only allow setting system flag for admins or if already a system process
        return this.$store.getters.getCurrentUserRole === 'administrator' || 
               (this.process && this.process.is_system);
      },
    },
    watch: {
      process: {
        immediate: true,
        handler(newProcess) {
          if (newProcess) {
            this.formData = {
              name: newProcess.name || '',
              description: newProcess.description || '',
              default: newProcess.default || false,
              is_system: newProcess.is_system || false,
            };
          } else {
            this.resetForm();
          }
        },
      },
    },
    methods: {
      resetForm() {
        this.formData = {
          name: '',
          description: '',
          default: false,
          is_system: false,
        };
        this.errors = {};
      },
  
      validateForm() {
        this.errors = {};
        
        if (!this.formData.name.trim()) {
          this.errors.name = 'Name is required';
        } else if (this.formData.name.length < 2) {
          this.errors.name = 'Name must be at least 2 characters';
        } else if (this.formData.name.length > 50) {
          this.errors.name = 'Name must be 50 characters or less';
        }
  
        if (this.formData.description && this.formData.description.length > 255) {
          this.errors.description = 'Description must be 255 characters or less';
        }
  
        return Object.keys(this.errors).length === 0;
      },
  
      async handleSubmit() {
        if (!this.validateForm()) {
          return;
        }
  
        this.isSubmitting = true;
        
        try {
          const processData = {
            ...this.formData,
            name: this.formData.name.trim(),
            description: this.formData.description.trim(),
          };
  
          this.$emit('save', processData);
        } catch (error) {
          console.error('Error in form submission:', error);
        } finally {
          this.isSubmitting = false;
        }
      },
  
      formatDate(date) {
        return format(new Date(date), 'PPp');
      },
    },
  };
  </script>
  
  <style lang="scss" scoped>
  .kanban-type-process-form {
    width: 100%;
    max-width: 500px;
  }
  
  .modal-header {
    padding: var(--space-normal) var(--space-large);
    border-bottom: 1px solid var(--color-border);
  }
  
  .modal-title {
    margin: 0;
    font-size: var(--font-size-large);
    font-weight: var(--font-weight-medium);
  }
  
  .modal-body {
    padding: var(--space-large);
  }
  
  .form-group {
    margin-bottom: var(--space-large);
  
    &:last-child {
      margin-bottom: 0;
    }
  }
  
  .form-label {
    display: block;
    margin-bottom: var(--space-small);
    font-weight: var(--font-weight-medium);
    color: var(--s-800);
  }
  
  .required-indicator {
    color: var(--r-500);
    margin-left: 2px;
  }
  
  .error-message {
    display: block;
    margin-top: var(--space-small);
    color: var(--r-500);
    font-size: var(--font-size-small);
  }
  
  .checkbox-group {
    display: flex;
    flex-direction: column;
    gap: var(--space-small);
  }
  
  .metadata-info {
    background: var(--color-background);
    border-radius: var(--border-radius-small);
    padding: var(--space-normal);
  }
  
  .metadata-item {
    display: flex;
    justify-content: space-between;
    margin-bottom: var(--space-small);
  
    &:last-child {
      margin-bottom: 0;
    }
  }
  
  .metadata-label {
    font-weight: var(--font-weight-medium);
    color: var(--s-600);
  }
  
  .metadata-value {
    color: var(--s-800);
  }
  
  .modal-footer {
    display: flex;
    justify-content: flex-end;
    gap: var(--space-normal);
    padding: var(--space-normal) var(--space-large);
    border-top: 1px solid var(--color-border);
  }
  </style>