<template>
  <div class="mt-6 flex-1">
    <div class="table-actions-wrap">
      <div class="left-aligned-wrap">
        <woot-button class="margin-right-small clear" color-scheme="success" icon="add-circle"
          data-testid="create-new-question" @click="onToggleCreateQuestion">
          {{ 'Agregar Pregunta' }}
        </woot-button>

        <woot-button class="margin-right-small clear" color-scheme="primary" icon="add-circle"
          data-testid="create-new-answer" @click="onToggleCreateAnswer">
          {{ 'Agregar Respuesta' }}
        </woot-button>
        <form class="mx-0 flex flex-wrap px-3">
          <div class="w-full flex items-center gap-2">
            <input v-model="dataActiveQuestions.set_questions" type="checkbox" :value="true"
              @change="toogleActiveQuestions" />
            <label for="conversation_creation">
              {{ 'Activar preguntas de calificación de prospecto...' }}
            </label>
          </div>
        </form>
      </div>
      <div class="right-aligned-wrap">

      </div>
    </div>
  </div>
</template>

<script>
import { mapGetters } from 'vuex';

export default {
  props: {
    onToggleCreateQuestion: {
      type: Function,
      default: () => { },
    },
    onToggleCreateAnswer: {
      type: Function,
      default: () => { },
    },
    dataActiveQuestions: {
      type: Array,
      default: () => { },
    },
  },
  data() {
    return {
      showCreateModal: false,
      showImportModal: false,
    };
  },
  computed: {
    searchButtonClass() {
      return this.searchQuery !== '' ? 'show' : '';
    },
    ...mapGetters({
      getAppliedContactFilters: 'contacts/getAppliedContactFilters',
    }),
    hasAppliedFilters() {
      return this.getAppliedContactFilters.length;
    },
  },
  methods: {
    toogleActiveQuestions() {
      // Emitir el valor actual de dataActiveQuestions.set_questions
      this.$emit('active-questions', { active: this.dataActiveQuestions.set_questions });
    },
  },
};
</script>

<style lang="scss" scoped>
.page-title {
  margin: 0;
}

.table-actions-wrap {
  display: flex;
  justify-content: space-between;
  width: 100%;
  // padding: var(--space-small) var(--space-normal) var(--space-small) var(--space-normal);
  padding: var(--space-small) var(--space-zero) var(--space-small) var(--space-zero);
}

.left-aligned-wrap {
  display: flex;
  align-items: center;
  justify-content: center;
}

.right-aligned-wrap {
  display: flex;
}

.search-wrap {
  width: 250px;
  display: flex;
  align-items: center;
  position: relative;
  margin-right: var(--space-small);

  .search-icon {
    position: absolute;
    top: 2px;
    left: var(--space-one);
    height: 1.8rem;
    line-height: 3.6rem;
    font-size: var(--font-size-medium);
    color: var(--b-700);
  }

  .contact-search {
    margin: 0;
    // height: 3.8rem;
    width: 100%;
    padding-left: var(--space-large);
    padding-right: 6rem;
    border-color: var(--s-100);
  }

  .button {
    margin-left: var(--space-small);
    height: 3.2rem;
    right: var(--space-smaller);
    position: absolute;
    padding: 0 var(--space-small);
    transition: transform 100ms linear;
    opacity: 0;
    transform: translateX(-1px);
    visibility: hidden;
  }

  .button.show {
    opacity: 1;
    transform: translateX(0);
    visibility: visible;
  }
}

.filters__button-wrap {
  position: relative;

  .filters__applied-indicator {
    position: absolute;
    height: var(--space-small);
    width: var(--space-small);
    top: var(--space-smaller);
    right: var(--space-slab);
    background-color: var(--s-500);
    border-radius: var(--border-radius-rounded);
  }
}
</style>
