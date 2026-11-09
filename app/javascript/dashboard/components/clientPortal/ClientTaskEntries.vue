<!--
  Tareas con el cliente — lo que pasó en el portal sobre una tarea (empezó, comentó,
  subió archivo, la completó) y, desde aquí, responderle o regresarla a pendiente.
  Va dentro del modal de la tarea (TicketTasks) cuando la hace el cliente.
-->
<script>
import CaseTasksAPI from 'dashboard/api/caseTasks';

const T = 'CLIENT_TASKS';

export default {
  name: 'ClientTaskEntries',
  props: {
    ticketId: { type: [Number, String], required: true },
    taskId: { type: Number, required: true },
    status: { type: String, default: 'pending' },
    readonly: { type: Boolean, default: false },
  },
  emits: ['changed'],
  data() {
    return {
      entries: [],
      reply: '',
      reason: '',
      returning: false,
      busy: false,
      error: '',
    };
  },
  mounted() {
    this.load();
  },
  methods: {
    t(key, params) {
      return this.$t(`${T}.${key}`, params);
    },
    async load() {
      const { data } = await CaseTasksAPI.clientEntries(
        this.ticketId,
        this.taskId
      );
      this.entries = data.entries;
    },
    when(at) {
      return new Date(at).toLocaleString(undefined, {
        day: 'numeric',
        month: 'short',
        hour: '2-digit',
        minute: '2-digit',
      });
    },
    async send(action) {
      this.busy = true;
      this.error = '';
      try {
        if (action === 'reply') {
          await CaseTasksAPI.replyClient(
            this.ticketId,
            this.taskId,
            this.reply
          );
          this.reply = '';
        } else {
          await CaseTasksAPI.returnToClient(
            this.ticketId,
            this.taskId,
            this.reason
          );
          this.reason = '';
          this.returning = false;
          this.$emit('changed');
        }
        await this.load();
      } catch (e) {
        this.error = e.response?.data?.error || this.t('ERROR');
      } finally {
        this.busy = false;
      }
    },
  },
};
</script>

<template>
  <section
    class="p-3 mt-4 border rounded-lg border-violet-100 bg-violet-50/40 dark:border-violet-900 dark:bg-violet-900/10"
  >
    <h4 class="m-0 text-sm font-semibold text-slate-800 dark:text-slate-100">
      {{ t('PORTAL_TITLE') }}
    </h4>
    <p v-if="!entries.length" class="m-0 mt-1 text-xs text-slate-500">
      {{ t('EMPTY') }}
    </p>
    <ul class="flex flex-col gap-2 p-0 m-0 mt-2 list-none">
      <li
        v-for="entry in entries"
        :key="entry.id"
        class="px-3 py-2 text-sm bg-white rounded-md dark:bg-slate-800"
      >
        <p class="m-0 text-xs text-slate-500">
          {{ entry.author || '—' }} · {{ t(`KINDS.${entry.kind}`) }} ·
          {{ when(entry.created_at) }}
        </p>
        <p
          v-if="entry.content"
          class="m-0 mt-1 whitespace-pre-line text-slate-800 dark:text-slate-100"
        >
          {{ entry.content }}
        </p>
        <a
          v-if="entry.file"
          :href="entry.file.url"
          target="_blank"
          rel="noopener noreferrer"
          class="inline-block mt-1 text-xs text-woot-600 hover:underline"
        >
          {{ entry.file.name }}
        </a>
      </li>
    </ul>
    <div v-if="!readonly" class="flex flex-col gap-2 mt-3">
      <div class="flex items-end gap-2">
        <textarea
          v-model="reply"
          rows="2"
          class="flex-1 !mb-0 text-sm"
          :placeholder="t('REPLY_PLACEHOLDER')"
        />
        <woot-button
          size="small"
          :is-loading="busy && !returning"
          :is-disabled="!reply.trim()"
          @click="send('reply')"
        >
          {{ t('REPLY') }}
        </woot-button>
      </div>
      <template v-if="status === 'done'">
        <woot-button
          v-if="!returning"
          size="small"
          variant="smooth"
          color-scheme="warning"
          icon="arrow-reply"
          @click="returning = true"
        >
          {{ t('RETURN') }}
        </woot-button>
        <div v-else class="flex items-end gap-2">
          <textarea
            v-model="reason"
            rows="2"
            class="flex-1 !mb-0 text-sm"
            :placeholder="t('RETURN_PLACEHOLDER')"
          />
          <woot-button
            size="small"
            color-scheme="warning"
            :is-loading="busy && returning"
            :is-disabled="!reason.trim()"
            @click="send('return')"
          >
            {{ t('RETURN_CONFIRM') }}
          </woot-button>
        </div>
      </template>
      <p v-if="error" class="m-0 text-xs text-red-600">{{ error }}</p>
    </div>
  </section>
</template>
