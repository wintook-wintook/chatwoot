<script>
import axios from 'axios';
import { mapGetters } from 'vuex';

export default {
  props: {
    searchQuery: {
      type: String,
      default: '',
    },
    searchTrained: {
      type: Number,
      default: 2,
    },
    similarity: {
      type: Number,
      default: 0.85,
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
    onToggleUpdate: {
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
    onTogglePages: {
      type: Function,
      default: () => {},
    },
    onToggleTrainedFilter: {
      type: Function,
      default: () => {},
    },
    onToggleOrigenFilter: {
      type: Function,
      default: () => {},
    },
    onToggleUpdateForo: {
      type: Function,
      default: () => {},
    },
    onToggleOptions: {
      type: Function,
      default: () => {},
    },
  },
  data() {
    return {
      showCreateModal: false,
      showImportModal: false,
      disableSimilarity: true,
      auxSimilarity: 0,
    };
  },
  computed: {
    searchButtonClass() {
      return this.searchQuery !== '' ? 'show' : '';
    },
    ...mapGetters({
      getAppliedContactFilters: 'contacts/getAppliedContactFilters',
      currentUser: 'getCurrentUser',
      getAccount: 'accounts/getAccount',
    }),
    hasAppliedFilters() {
      return this.getAppliedContactFilters.length;
    },
  },
  methods: {
    onChange(e) {
      const valor = e.target.value;
      this.auxSimilarity = valor;
      this.disableSimilarity = valor >= 0 && valor <= 1 ? false : true;
    },

    async onToggleSimilarity() {
      const { access_token, account_id } = this.currentUser;
      const valueSimilarity = this.auxSimilarity;
      const result = await axios
        .post(process.env.URL_WEBHOOK + '/api/setSimilarity', {
          params: { access_token, account_id, similarity: valueSimilarity },
        })
        .then(function (resp) {
          return resp;
        })
        .catch(function (error) {
          return error;
        });
      this.similarity = this.auxSimilarity;
      this.disableSimilarity = true;
    },
  },
};
</script>

<template>
  <div class="mt-6 flex-1">
    <div class="table-actions-wrap">
      <div class="left-aligned-wrap">
        <div class="search-wrap">
          <fluent-icon icon="search" class="search-icon" />
          <input
            type="text"
            :placeholder="Buscar"
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
        <div class="search-wrap" style="width: 120px">
          <select
            style="margin-bottom: 0px"
            @change="onToggleTrainedFilter($event)"
          >
            <option value="2">{{ 'Todos' }}</option>
            <option value="1">{{ 'Entrenados' }}</option>
            <option value="0">{{ 'No Entrenados' }}</option>
          </select>
        </div>
        <div class="search-wrap" style="width: 120px">
          <select
            style="margin-bottom: 0px"
            @change="onToggleOrigenFilter($event)"
          >
            <option value="0">{{ 'Todos' }}</option>
            <option value="3">{{ 'Foro' }}</option>
            <option value="1">{{ 'Resp. Predefinidas' }}</option>
          </select>
        </div>
        <!-- <div class="search-wrap" style="width: 80px">
          <input
            type="number"
            step="0.01"
            :value="similarity"
            placeholder="0.00"
            min="0.00"
            max="1.00"
            style="margin-bottom: 0px; width: 100px"
            @input="onChange"
          />
        </div>
        <div class="left-aligned-wrap">
          <woot-button
            class="margin-right-small"
            color-scheme="success"
            icon="checkmark"
            :is-disabled="disableSimilarity"
            @click="onToggleSimilarity"
          >
            {{ 'Similitud' }}
          </woot-button>
        </div> -->
      </div>

      <!-- <div class="left-aligned-wrap">
          <select>
            <option :value="0">{{ "Origen de Datos" }}</option>
          </select>
        </div> -->

      <div class="right-aligned-wrap">
        <woot-button
          class="margin-right-small clear"
          color-scheme="primary"
          icon="arrow-download"
          @click="onToggleUpdate"
        >
          {{ 'Refrescar' }}
        </woot-button>
        <div class="search-wrap" style="width: 80px">
          <select style="margin-bottom: 0px" @change="onTogglePages($event)">
            <option value="10">10</option>
            <option value="25">25</option>
            <option value="50">50</option>
          </select>
        </div>

        <!-- <woot-button
          class="margin-right-small"
          color-scheme="success"
          icon="arrow-download"
          @click="onToggleUpdateForo"
        >
          {{ 'Actualizar' }}
        </woot-button>-->

        <woot-button
          class="margin-right-small"
          color-scheme="success"
          icon="arrow-download"
          @click="onToggleOptions"
        >
          {{ 'Opciones' }}
        </woot-button>
      </div>
    </div>


  </div>
</template>

<style lang="scss" scoped>
.page-title {
  margin: 0;
}
.table-actions-wrap {
  display: flex;
  justify-content: space-between;
  width: 100%;
  // padding: var(--space-small) var(--space-normal) var(--space-small) var(--space-normal);
  padding: var(--space-small) var(--space-zero) var(--space-small)
    var(--space-zero);
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
    top: 1px;
    left: var(--space-one);
    height: 2.5rem;
    line-height: 3.6rem;
    font-size: var(--font-size-medium);
    color: var(--b-700);
  }
  .contact-search {
    margin: 0;
    height: 2.5rem;
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
