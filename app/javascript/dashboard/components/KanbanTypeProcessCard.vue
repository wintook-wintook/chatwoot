<!-- 
  app/javascript/dashboard/components/KanbanTypeProcessCard.vue 
  KANBAN0725
-->

<template>
    <div class="kanban-type-process-card">
      <div class="card-header">
        <div class="process-info">
          <h4 class="process-name">{{ process.name }}</h4>
          <div class="process-badges">
            <span v-if="process.default" class="badge badge-primary">
              Default
            </span>
            <span v-if="isSystem" class="badge badge-info">
              System
            </span>
          </div>
        </div>
        <div class="card-actions">
          <woot-button
            variant="hollow"
            color-scheme="secondary"
            size="tiny"
            icon="edit"
            @click="$emit('edit', process)"
          />
          <woot-button
            v-if="!isSystem"
            variant="hollow"
            color-scheme="alert"
            size="tiny"
            icon="delete"
            @click="$emit('delete', process)"
          />
        </div>
      </div>
  
      <div class="card-body">
        <p v-if="process.description" class="process-description">
          {{ process.description }}
        </p>
        
        <div class="process-stats">
          <div class="stat-item">
            <fluent-icon icon="flow" size="16" />
            <span>{{ processCount }} processes</span>
          </div>
          <div class="stat-item">
            <fluent-icon icon="calendar" size="16" />
            <span>{{ formatDate(process.created_at) }}</span>
          </div>
        </div>
      </div>
  
      <div v-if="showProcesses" class="card-footer">
        <div class="process-list">
          <div
            v-for="kanbanProcess in kanbanProcesses"
            :key="kanbanProcess.id"
            class="process-item"
          >
            <div class="process-dot" :style="{ backgroundColor: kanbanProcess.color }"></div>
            <span class="process-title">{{ kanbanProcess.name }}</span>
            <span class="process-count">{{ getKanbanProcessCount(kanbanProcess.id) }}</span>
          </div>
        </div>
      </div>
    </div>
  </template>
  
  <script>
  import kanbanMixin from '../mixins/kanbanMixin';
  import { format } from 'date-fns';
  
  export default {
    name: 'KanbanTypeProcessCard',
    mixins: [kanbanMixin],
    props: {
      process: {
        type: Object,
        required: true,
      },
      isSystem: {
        type: Boolean,
        default: false,
      },
      showProcesses: {
        type: Boolean,
        default: true,
      },
    },
    computed: {
      kanbanProcesses() {
        return this.getKanbanProcessesByType(this.process.id);
      },
      processCount() {
        return this.kanbanProcesses.length;
      },
    },
    methods: {
      formatDate(date) {
        return format(new Date(date), 'MMM dd, yyyy');
      },
    },
  };
  </script>
  
  <style lang="scss" scoped>
  .kanban-type-process-card {
    background: var(--white);
    border: 1px solid var(--color-border);
    border-radius: var(--border-radius-normal);
    overflow: hidden;
    transition: all 0.2s ease;
  
    &:hover {
      box-shadow: var(--shadow-medium);
    }
  }
  
  .card-header {
    display: flex;
    justify-content: space-between;
    align-items: flex-start;
    padding: var(--space-normal);
    border-bottom: 1px solid var(--color-border-light);
  }
  
  .process-info {
    flex: 1;
  }
  
  .process-name {
    margin: 0 0 var(--space-small) 0;
    font-size: var(--font-size-medium);
    font-weight: var(--font-weight-medium);
    color: var(--s-900);
  }
  
  .process-badges {
    display: flex;
    gap: var(--space-small);
  }
  
  .badge {
    display: inline-block;
    padding: 2px 8px;
    font-size: var(--font-size-mini);
    font-weight: var(--font-weight-medium);
    border-radius: var(--border-radius-small);
    text-transform: uppercase;
    letter-spacing: 0.5px;
  
    &.badge-primary {
      background: var(--w-500);
      color: var(--white);
    }
  
    &.badge-info {
      background: var(--b-500);
      color: var(--white);
    }
  }
  
  .card-actions {
    display: flex;
    gap: var(--space-small);
  }
  
  .card-body {
    padding: var(--space-normal);
  }
  
  .process-description {
    margin: 0 0 var(--space-normal) 0;
    color: var(--s-600);
    font-size: var(--font-size-small);
    line-height: 1.4;
  }
  
  .process-stats {
    display: flex;
    gap: var(--space-normal);
  }
  
  .stat-item {
    display: flex;
    align-items: center;
    gap: var(--space-small);
    color: var(--s-500);
    font-size: var(--font-size-small);
  }
  
  .card-footer {
    border-top: 1px solid var(--color-border-light);
    padding: var(--space-normal);
    background: var(--color-background);
  }
  
  .process-list {
    display: flex;
    flex-direction: column;
    gap: var(--space-small);
  }
  
  .process-item {
    display: flex;
    align-items: center;
    gap: var(--space-small);
    padding: var(--space-small);
    background: var(--white);
    border-radius: var(--border-radius-small);
    font-size: var(--font-size-small);
  }
  
  .process-dot {
    width: 8px;
    height: 8px;
    border-radius: 50%;
    flex-shrink: 0;
  }
  
  .process-title {
    flex: 1;
    color: var(--s-800);
  }
  
  .process-count {
    color: var(--s-500);
    font-weight: var(--font-weight-medium);
  }
  </style>