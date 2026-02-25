<script>
export default {
  name: 'KanbanCard',
  props: {
    card: {
      type: Object,
      required: true,
    },
  },
  methods: {
    onDragStart(event) {
      this.$emit('drag-start', event, this.card);
    },
  },
};
</script>

<template>
  <div
    draggable="true"
    class="p-3 bg-white border rounded-lg shadow-sm cursor-move dark:bg-slate-900 border-slate-200 dark:border-slate-700 hover:shadow-md transition-shadow"
    @dragstart="onDragStart"
  >
    <!-- Card Content -->
    <div class="space-y-2">
      <h4 class="font-medium text-slate-900 dark:text-slate-100">
        {{ card.title || 'Sample Card' }}
      </h4>
      <p class="text-sm text-slate-600 dark:text-slate-400">
        {{ card.description || 'Sample card description' }}
      </p>
      
      <!-- Card Metadata -->
      <div class="flex items-center justify-between text-xs text-slate-500 dark:text-slate-400">
        <span>{{ card.id || 'ID' }}</span>
        <span>{{ card.updated_at || 'Date' }}</span>
      </div>
    </div>
  </div>
</template>
<!-- <script>
export default {
  name: 'KanbanCard',
  props: {
    conversation: {
      type: Object,
      required: true,
    },
    columnId: {
      type: String,
      required: true,
    },
  },
  computed: {
    priorityClass() {
      const priority = this.conversation.priority || 'normal';
      return `priority-${priority}`;
    },
    lastMessagePreview() {
      if (this.conversation.messages && this.conversation.messages.length > 0) {
        const lastMessage = this.conversation.messages[this.conversation.messages.length - 1];
        return lastMessage.content ? lastMessage.content.substring(0, 60) + '...' : 'No message content';
      }
      return 'No messages';
    },
    assigneeInitials() {
      if (this.conversation.assignee && this.conversation.assignee.name) {
        return this.conversation.assignee.name
          .split(' ')
          .map(n => n[0])
          .join('')
          .toUpperCase();
      }
      return '';
    },
    contactName() {
      if (this.conversation.meta && this.conversation.meta.sender) {
        return this.conversation.meta.sender.name || 
               this.conversation.meta.sender.email || 
               'Unknown Contact';
      }
      return 'Unknown Contact';
    },
    unreadCount() {
      return this.conversation.unread_count || 0;
    },
    inboxInfo() {
      return this.conversation.inbox || {};
    },
    statusColor() {
      const statusColors = {
        open: '#3b82f6',      // blue
        pending: '#f97316',   // orange  
        resolved: '#10b981',  // green
        snoozed: '#8b5cf6'    // purple
      };
      return statusColors[this.conversation.status] || '#6b7280';
    },
  },
  methods: {
    onDragStart(event) {
      const dragData = {
        conversationId: this.conversation.id,
        sourceColumnId: this.columnId,
        conversation: this.conversation
      };
      
      event.dataTransfer.setData('text/plain', JSON.stringify(dragData));
      event.dataTransfer.effectAllowed = 'move';
      
      // Añadir clase visual durante el arrastre
      this.$el.classList.add('dragging');
    },
    onDragEnd(event) {
      this.$el.classList.remove('dragging');
    },
    openConversation() {
      // Navegar a la conversación específica
      this.$router.push({
        name: 'inbox_conversation',
        params: {
          accountId: this.$route.params.accountId,
          inboxId: this.conversation.inbox_id,
          conversationId: this.conversation.id,
        },
      });
    },
    formatTime(timestamp) {
      if (!timestamp) return '';
      const date = new Date(timestamp * 1000);
      return date.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
    },
  },
};
</script>

<template>
  <div 
    class="kanban-card bg-white dark:bg-slate-800 rounded-lg shadow-sm p-3 mb-3 cursor-move border border-slate-200 dark:border-slate-700 hover:shadow-md transition-all duration-200"
    :class="[priorityClass, { 'dragging': false }]"
    draggable="true"
    @dragstart="onDragStart"
    @dragend="onDragEnd"
    @click="openConversation"
  >
  
    <div class="flex justify-between items-start mb-2">
      <span class="text-xs font-medium bg-slate-100 dark:bg-slate-700 text-slate-600 dark:text-slate-300 rounded px-2 py-1">
        #{{ conversation.display_id || conversation.id }}
      </span>
      <div class="flex items-center space-x-1">
        <span 
          v-if="unreadCount > 0" 
          class="text-xs font-medium bg-red-500 text-white rounded-full h-5 w-5 flex items-center justify-center"
        >
          {{ unreadCount > 99 ? '99+' : unreadCount }}
        </span>
        <span 
          class="w-2 h-2 rounded-full"
          :style="{ backgroundColor: statusColor }"
          :title="conversation.status"
        ></span>
      </div>
    </div>
    
    <div class="text-sm font-medium mb-2 truncate text-slate-800 dark:text-slate-200">
      {{ contactName }}
    </div>
    
    <p class="text-xs text-slate-600 dark:text-slate-400 mb-3 line-clamp-2 leading-relaxed">
      {{ lastMessagePreview }}
    </p>
    
    <div v-if="conversation.labels && conversation.labels.length" class="flex flex-wrap gap-1 mb-2">
      <span 
        v-for="label in conversation.labels.slice(0, 2)" 
        :key="label.id"
        class="text-xs px-2 py-1 rounded-full text-white"
        :style="{ backgroundColor: label.color || '#6b7280' }"
      >
        {{ label.title }}
      </span>
      <span 
        v-if="conversation.labels.length > 2" 
        class="text-xs px-2 py-1 rounded-full bg-slate-200 dark:bg-slate-600 text-slate-600 dark:text-slate-300"
      >
        +{{ conversation.labels.length - 2 }}
      </span>
    </div>
    
    <div class="flex justify-between items-center">
      <div class="flex items-center space-x-2">
        <div class="flex items-center space-x-1">
          <span 
            class="w-2 h-2 rounded-full"
            :style="{ backgroundColor: inboxInfo.color || '#1f93ff' }"
          ></span>
          <span class="text-xs text-slate-500 dark:text-slate-400 truncate max-w-20">
            {{ inboxInfo.name || 'Inbox' }}
          </span>
        </div>
      </div>
      
      <div class="flex items-center space-x-2">
        <span v-if="conversation.last_activity_at" class="text-xs text-slate-400">
          {{ formatTime(conversation.last_activity_at) }}
        </span>
        <div 
          v-if="assigneeInitials" 
          class="h-6 w-6 rounded-full bg-woot-500 text-white flex items-center justify-center text-xs font-medium"
          :title="conversation.assignee ? conversation.assignee.name : ''"
        >
          {{ assigneeInitials }}
        </div>
        <div 
          v-else
          class="h-6 w-6 rounded-full bg-slate-300 dark:bg-slate-600 flex items-center justify-center"
          title="Unassigned"
        >
          <fluent-icon icon="person" size="12" class="text-slate-500 dark:text-slate-400" />
        </div>
      </div>
    </div>
  </div>
</template>

<style scoped>
.kanban-card {
  transition: all 0.2s ease;
  cursor: pointer;
}

.kanban-card:hover {
  transform: translateY(-1px);
  box-shadow: 0 4px 6px -1px rgba(0, 0, 0, 0.1), 0 2px 4px -1px rgba(0, 0, 0, 0.06);
}

.kanban-card.dragging {
  opacity: 0.7;
  transform: rotate(5deg);
  z-index: 1000;
}

.priority-urgent {
  border-left: 4px solid #ef4444;
}

.priority-high {
  border-left: 4px solid #f97316;
}

.priority-normal {
  border-left: 4px solid #3b82f6;
}

.priority-low {
  border-left: 4px solid #10b981;
}

.line-clamp-2 {
  display: -webkit-box;
  -webkit-line-clamp: 2;
  -webkit-box-orient: vertical;  
  overflow: hidden;
}
</style> -->