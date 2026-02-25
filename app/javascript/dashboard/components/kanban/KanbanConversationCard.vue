<template>
  <div
    class="kanban-conversation-card bg-white dark:bg-slate-800 rounded-lg shadow-sm p-3 mb-3 cursor-pointer border border-slate-200 dark:border-slate-700 hover:shadow-md transition-all duration-200"
    :class="[priorityClass, statusClass, { 'dragging': isDragging }]"
    draggable="true"
    @dragstart="onDragStart"
    @dragend="onDragEnd"
    @click="openConversation"
  >
    <!-- Header con ID y Status -->
    <div class="flex justify-between items-start mb-2">
      <div class="flex items-center space-x-2">
        <!-- <span class="text-xs font-medium bg-slate-100 dark:bg-slate-700 text-slate-600 dark:text-slate-300 rounded px-2 py-1">
          #{{ conversation.display_id || conversation.id }}
        </span> -->
        <span 
          class="text-xs px-2 py-1 rounded-full text-white font-medium"
          :style="{ backgroundColor: statusColor }"
        >
          {{ statusText }}
        </span>
      </div>
      
      <div class="flex items-center space-x-1">
        <!-- Badge de mensajes no leídos -->
        <span 
          v-if="unreadCount > 0" 
          class="text-xs font-medium bg-red-500 text-white rounded-full h-5 w-5 flex items-center justify-center animate-pulse"
        >
          {{ unreadCount > 99 ? '99+' : unreadCount }}
        </span>
        
        <!-- Indicador de prioridad -->
        <div 
          v-if="conversation.priority && conversation.priority !== 'none'"
          class="priority-indicator w-2 h-2 rounded-full"
          :class="priorityIndicatorClass"
          :title="`Prioridad: ${priorityText}`"
        ></div>
      </div>
    </div>

    <!-- Información del contacto -->
    <div class="mb-2">
      <div class="flex items-center space-x-2 mb-1">
        <!-- Avatar o inicial del contacto -->
        <div class="flex-shrink-0">
          <div 
            v-if="contactAvatar"
            class="w-8 h-8 rounded-full bg-cover bg-center"
            :style="{ backgroundImage: `url(${contactAvatar})` }"
          ></div>
          <div 
            v-else
            class="w-8 h-8 rounded-full bg-gradient-to-br from-blue-400 to-blue-600 flex items-center justify-center text-white text-xs font-bold"
          >
            {{ contactInitials }}
          </div>
        </div>
        
        <!-- Nombre del contacto -->
        <div class="flex-1 min-w-0">
          <div class="text-sm font-medium text-slate-800 dark:text-slate-200 truncate">
            {{ contactName }}
          </div>
          <div v-if="contactEmail" class="text-xs text-slate-500 dark:text-slate-400 truncate">
            {{ contactEmail }}
          </div>
        </div>
      </div>
    </div>

    <!-- Preview del último mensaje -->
    <div v-if="lastMessagePreview" class="mb-3">
      <p class="text-xs text-slate-600 dark:text-slate-400 line-clamp-2 leading-relaxed">
        {{ lastMessagePreview }}
      </p>
    </div>

    <!-- Etiquetas -->
    <div v-if="conversation.labels && conversation.labels.length" class="flex flex-wrap gap-1 mb-2">
      <span 
        v-for="label in visibleLabels" 
        :key="label.id"
        class="text-xs px-2 py-1 rounded-full text-white font-medium"
        :style="{ backgroundColor: label.color || '#6b7280' }"
      >
        {{ label.title }}
      </span>
      <span 
        v-if="hiddenLabelsCount > 0" 
        class="text-xs px-2 py-1 rounded-full bg-slate-200 dark:bg-slate-600 text-slate-600 dark:text-slate-300"
      >
        +{{ hiddenLabelsCount }}
      </span>
    </div>

    <!-- Footer con información adicional -->
    <div class="flex justify-between items-center text-xs">
      <!-- Información del inbox y asignado -->
      <div class="flex items-center space-x-2 flex-1 min-w-0">
        <!-- Inbox -->
        <div class="flex items-center space-x-1">
          <span 
            class="w-2 h-2 rounded-full flex-shrink-0"
            :style="{ backgroundColor: inboxColor }"
          ></span>
          <span class="text-slate-500 dark:text-slate-400 truncate">
            {{ inboxName }}
          </span>
        </div>
        
        <!-- Asignado -->
        <div v-if="assigneeName" class="flex items-center space-x-1 text-blue-600 dark:text-blue-400">
          <span>👨‍💻</span>
          <span class="truncate">{{ assigneeName }}</span>
        </div>
      </div>

      <!-- Tiempo y avatar del asignado -->
      <div class="flex items-center space-x-2 flex-shrink-0">
        <span v-if="lastActivityTime" class="text-slate-400">
          {{ lastActivityTime }}
        </span>
        
        <!-- Avatar del asignado -->
        <div 
          v-if="assigneeInitials" 
          class="h-6 w-6 rounded-full bg-blue-500 text-white flex items-center justify-center text-xs font-medium"
          :title="assigneeName"
        >
          {{ assigneeInitials }}
        </div>
        <div 
          v-else
          class="h-6 w-6 rounded-full bg-slate-300 dark:bg-slate-600 flex items-center justify-center"
          title="Sin asignar"
        >
          <span class="text-slate-500 dark:text-slate-400 text-xs">?</span>
        </div>
      </div>
    </div>
  </div>
</template>

<script>
import { frontendURL, conversationUrl } from 'dashboard/helper/URLHelper';

export default {
  name: 'KanbanConversationCard',
  props: {
    conversation: {
      type: Object,
      required: true,
    },
    columnId: {
      type: [String, Number],
      required: true,
    },
    activeLabel: {
      type: String,
      default: '',
    },
    teamId: {
      type: [String, Number],
      default: 0,
    },
    foldersId: {
      type: [String, Number],
      default: 0,
    },
    conversationType: {
      type: String,
      default: '',
    },
  },
  
  data() {
    return {
      isDragging: false,
    };
  },

  computed: {
    // === INFORMACIÓN DEL CONTACTO ===
    contactName() {
      if (this.conversation.meta && this.conversation.meta.sender) {
        return this.conversation.meta.sender.name || 
               this.conversation.meta.sender.email || 
               'Contacto sin nombre';
      }
      return 'Contacto desconocido';
    },

    contactEmail() {
      return this.conversation.meta?.sender?.email || null;
    },

    contactAvatar() {
      return this.conversation.meta?.sender?.thumbnail || 
             this.conversation.meta?.sender?.avatar_url || null;
    },

    contactInitials() {
      const name = this.contactName;
      if (name === 'Contacto sin nombre' || name === 'Contacto desconocido') {
        return '?';
      }
      return name
        .split(' ')
        .map(n => n[0])
        .join('')
        .toUpperCase()
        .substring(0, 2);
    },

    // === INFORMACIÓN DEL ASIGNADO ===
    assigneeName() {
      return this.conversation.meta?.assignee?.name || null;
    },

    assigneeInitials() {
      if (!this.assigneeName) return '';
      return this.assigneeName
        .split(' ')
        .map(n => n[0])
        .join('')
        .toUpperCase()
        .substring(0, 2);
    },

    // === ESTADO Y PRIORIDAD ===
    statusText() {
      const statusMap = {
        open: 'Abierto',
        pending: 'Pendiente',
        resolved: 'Resuelto',
        snoozed: 'Pospuesto'
      };
      return statusMap[this.conversation.status] || this.conversation.status;
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

    statusClass() {
      return `status-${this.conversation.status}`;
    },

    priorityText() {
      const priorityMap = {
        urgent: 'Urgente',
        high: 'Alta',
        medium: 'Media',
        low: 'Baja',
        none: 'Sin prioridad'
      };
      return priorityMap[this.conversation.priority] || 'Normal';
    },

    priorityClass() {
      if (!this.conversation.priority || this.conversation.priority === 'none') {
        return '';
      }
      return `priority-${this.conversation.priority}`;
    },

    priorityIndicatorClass() {
      const priorityClasses = {
        urgent: 'bg-red-500 animate-pulse',
        high: 'bg-orange-500',
        medium: 'bg-yellow-500',
        low: 'bg-green-500'
      };
      return priorityClasses[this.conversation.priority] || '';
    },

    // === MENSAJES ===
    unreadCount() {
      return this.conversation.unread_count || 0;
    },

    lastMessagePreview() {
      if (this.conversation.messages && this.conversation.messages.length > 0) {
        const lastMessage = this.conversation.messages[this.conversation.messages.length - 1];
        if (lastMessage.content) {
          return lastMessage.content.length > 80 
            ? lastMessage.content.substring(0, 80) + '...' 
            : lastMessage.content;
        }
      }
      return 'Sin mensajes';
    },

    // === INBOX ===
    inboxName() {
      return this.conversation.inbox?.name || 'Inbox';
    },

    inboxColor() {
      return this.conversation.inbox?.color || '#1f93ff';
    },

    // === ETIQUETAS ===
    visibleLabels() {
      if (!this.conversation.labels) return [];
      return this.conversation.labels.slice(0, 2);
    },

    hiddenLabelsCount() {
      if (!this.conversation.labels) return 0;
      return Math.max(0, this.conversation.labels.length - 2);
    },

    // === TIEMPO ===
    lastActivityTime() {
      if (!this.conversation.last_activity_at) return '';
      
      const now = new Date();
      const activityDate = new Date(this.conversation.last_activity_at * 1000);
      const diffMs = now - activityDate;
      const diffMins = Math.floor(diffMs / 60000);
      const diffHours = Math.floor(diffMs / 3600000);
      const diffDays = Math.floor(diffMs / 86400000);

      if (diffMins < 1) return 'Ahora';
      if (diffMins < 60) return `${diffMins}m`;
      if (diffHours < 24) return `${diffHours}h`;
      if (diffDays < 7) return `${diffDays}d`;
      
      return activityDate.toLocaleDateString();
    },

    // === GETTERS DEL STORE ===
    accountId() {
      return this.$store.getters.getCurrentAccountId;
    },

    activeInbox() {
      return this.$store.getters.getSelectedInbox;
    },
  },

  methods: {
    // === NAVEGACIÓN ===
    openConversation() {
      if (this.isDragging) return; // No navegar si se está arrastrando

      const path = frontendURL(
        conversationUrl({
          accountId: this.accountId,
          activeInbox: this.activeInbox,
          id: this.conversation.id,
          label: this.activeLabel,
          teamId: this.teamId,
          foldersId: this.foldersId,
          conversationType: this.conversationType,
        })
      );

      this.$router.push({ path });
    },

    // === DRAG & DROP ===
    onDragStart(event) {
      this.isDragging = true;
      
      const dragData = {
        conversationId: this.conversation.id,
        sourceColumnId: this.columnId,
        conversation: this.conversation
      };
      
      event.dataTransfer.setData('application/json', JSON.stringify(dragData));
      event.dataTransfer.effectAllowed = 'move';
      
      // Emitir evento al componente padre
      this.$emit('drag-start', this.conversation, this.columnId);
    },

    onDragEnd() {
      this.isDragging = false;
      this.$emit('drag-end');
    },

    // === UTILITIES ===
    formatDate(timestamp) {
      if (!timestamp) return 'Sin fecha';
      const date = new Date(timestamp * 1000);
      return date.toLocaleDateString() + ' ' + date.toLocaleTimeString();
    },
  },
};
</script>

<style scoped>
.kanban-conversation-card {
  transition: all 0.2s ease;
  cursor: pointer;
}

.kanban-conversation-card:hover {
  transform: translateY(-1px);
  box-shadow: 0 4px 6px -1px rgba(0, 0, 0, 0.1), 0 2px 4px -1px rgba(0, 0, 0, 0.06);
}

.kanban-conversation-card.dragging {
  opacity: 0.7;
  transform: rotate(2deg) scale(0.95);
  z-index: 1000;
  box-shadow: 0 10px 25px rgba(0, 0, 0, 0.2);
}

/* Bordes de prioridad */
.priority-urgent {
  border-left: 4px solid #ef4444;
}

.priority-high {
  border-left: 4px solid #f97316;
}

.priority-medium {
  border-left: 4px solid #eab308;
}

.priority-low {
  border-left: 4px solid #10b981;
}

/* Estados */
.status-open {
  border-top: 2px solid #3b82f6;
}

.status-pending {
  border-top: 2px solid #f97316;
}

.status-resolved {
  border-top: 2px solid #10b981;
}

.status-snoozed {
  border-top: 2px solid #8b5cf6;
}

/* Truncate para múltiples líneas */
.line-clamp-2 {
  display: -webkit-box;
  -webkit-line-clamp: 2;
  -webkit-box-orient: vertical;  
  overflow: hidden;
}

/* Animaciones */
@keyframes pulse {
  0%, 100% {
    opacity: 1;
  }
  50% {
    opacity: .5;
  }
}

.animate-pulse {
  animation: pulse 2s cubic-bezier(0.4, 0, 0.6, 1) infinite;
}

/* Indicador de prioridad */
.priority-indicator {
  box-shadow: 0 0 0 2px rgba(255, 255, 255, 0.5);
}
</style>