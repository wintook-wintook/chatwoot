<template>
  <header class="header">
    <div class="table-actions-wrap">
      <div class="left-aligned-wrap">
        <div class="search-wrap">
          <fluent-icon icon="search" class="search-icon" />
          <input
            type="text"
            :placeholder="'Buscar'"
            class="contact-search"
            :value="searchQuery"
            @keyup.enter="onSearchSubmit"
            @input="onInputSearch"
          />
          <woot-button
            :is-loading="false"
            class="clear"
            :class-names="searchButtonClass"
            @click="onSearchSubmit"
          >
            {{ 'Buscar' }}
          </woot-button>
        </div>
      </div>
      <div class="right-aligned-wrap">
        <woot-button
          class="margin-right-small clear"
          color-scheme="success"
          icon="add-circle"
          data-testid="create-new-contact"
          @click="onToggleCreate"
        >
          {{ 'Agregar' }}
        </woot-button>
      </div>
    </div>
  </header>
</template>

<script>
import { mapGetters } from 'vuex';

export default {
  props: {
    searchQuery: {
      type: String,
      default: '',
    },
    onInputSearch: {
      type: Function,
      default: () => {},
    },
    onSearchSubmit: {
      type: Function,
      default: () => {},
    },
    onToggleCreate: {
      type: Function,
      default: () => {},
    },
    onToggleImport: {
      type: Function,
      default: () => {},
    },
    onToggleFilter: {
      type: Function,
      default: () => {},
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
