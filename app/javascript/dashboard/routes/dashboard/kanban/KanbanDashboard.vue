<template>
  <div class="flex flex-col h-full overflow-hidden">
    <div class="flex-1 p-4">
      <div class="flex items-center justify-between mb-6">
        <h1 class="text-2xl font-bold text-slate-800 dark:text-slate-100">
          {{ $t('KANBAN.TITLE') }}
        </h1>
        <woot-button color-scheme="primary" icon="add" @click="createNewBoard">
          {{ $t('KANBAN.NEW_BOARD') }}
        </woot-button>
      </div>

      <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
        <!-- Aquí irían las tarjetas de tableros kanban -->
        <div class="bg-white dark:bg-slate-800 rounded-lg p-6 shadow-sm border border-slate-200 dark:border-slate-700">
          <h3 class="text-lg font-semibold mb-2">Tablero de Ejemplo</h3>
          <p class="text-slate-600 dark:text-slate-400 mb-4">Descripción del tablero</p>
          <woot-button variant="clear" size="small" @click="openBoard">
            {{ $t('KANBAN.OPEN_BOARD') }}
          </woot-button>
        </div>
      </div>
    </div>
  </div>
</template>

<script>
export default {
  name: 'KanbanDashboard',
  data() {
    return {
      boards: [],
      loading: false,
    };
  },
  mounted() {
    this.loadBoards();
  },
  methods: {
    async loadBoards() {
      this.loading = true;
      try {
        // Aquí harías la llamada API para cargar los tableros
        // this.boards = await this.$store.dispatch('kanban/loadBoards');
      } catch (error) {
        console.error('Error loading boards:', error);
      } finally {
        this.loading = false;
      }
    },
    createNewBoard() {
      // Lógica para crear nuevo tablero
      this.$router.push({
        name: 'kanban_board',
        params: { boardId: 'new' }
      });
    },
    openBoard(boardId) {
      this.$router.push({
        name: 'kanban_board',
        params: { boardId }
      });
    },
  },
};
</script>