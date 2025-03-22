<script>
import { VeTable } from 'vue-easytable';

// import Spinner from 'shared/components/Spinner.vue';
// import EmptyState from 'dashboard/components/widgets/EmptyState.vue';

export default {
  components: {
    // EmptyState,
    // Spinner,
    VeTable,
  },
  props: {
    dataTable: {
      type: Array,
      default: () => [],
    },
    onToggleEdit: {
      type: Function,
      default: () => {},
    },
    onTogglePrompt: {
      type: Function,
      default: () => {},
    },
    onToggleUpdate: {
      type: Function,
      default: () => {},
    },
    onToggleDelete: {
      type: Function,
      default: () => {},
    },
  },
  data() {
    return {
      sortConfig: {},
    };
  },
  computed: {
    columns() {
      return [
        {
          field: 'trained',
          key: 'trained',
          title: 'Opciones',
          align: 'center',
          width: '12%',
          fixed: 'left',
          renderBodyCell: ({ row, column }) => {
            const trained = row[column.field];
            const color = trained ? 'success' : 'alert';
            const tooltip = trained
              ? 'Eliminar Entrenamiento'
              : 'Generar Entrenamiento';
            return (
              <div>
                <div class="button-wrapper">
                  <woot-button
                    color-scheme={color}
                    variant="smooth"
                    size="20"
                    class-names="grey-btn"
                    icon="bot"
                    v-tooltip={tooltip}
                    onClick={() => this.onToggleEdit(row)}
                  ></woot-button>
                  <woot-button
                    color-scheme="primary"
                    variant="smooth"
                    size="20"
                    class-names="grey-btn"
                    icon="code"
                    v-tooltip="Actualización de prompt..."
                    onClick={() => this.onTogglePrompt(row)}
                  ></woot-button>
                  <woot-button
                    color-scheme="success"
                    variant="smooth"
                    size="20"
                    class-names="grey-btn"
                    icon="arrow-download"
                    v-tooltip="Actualización de artículo desde el foro..."
                    onClick={() => this.onToggleUpdate(row)}
                  ></woot-button>
                </div>
              </div>
            );
          },
        },
        {
          field: 'short_code',
          key: 'short_code',
          title: 'Titulo',
          align: 'left',
          width: '38%',
          fixed: 'left',
          sortBy: this.sortConfig.short_code || '',
          renderBodyCell: ({ row, column }) => {
            const title = row[column.field];
            return (
              <span>{row.short_code}</span>
            );
          },
        },
        {
          field: 'created_at',
          key: 'created_at',
          title: 'Creación Origen',
          align: 'right',
          sortBy: this.sortConfig.created_at || '',
        },
        {
          field: 'updated_at',
          key: 'updated_at',
          title: 'Actualización Origen',
          align: 'right',
          sortBy: this.sortConfig.updated_at || '',
        },
      ];
    },
  },
};
</script>

<template>
  <div>
    <VeTable
      fixed-header
      max-height="100vh - 34.2rem)"
      :columns="columns"
      :table-data="dataTable"
    />
  </div>
</template>

<style lang="scss" scoped>
@import '~dashboard/assets/scss/mixins';

.vocabulario-table-wrap {
  flex: 1 1;
  height: 100%;
  overflow: hidden;
}

.vocabulario-table-wrap::v-deep {
  .ve-table {
    padding-bottom: var(--space-large);
  }

  .row--user-block {
    align-items: center;
    display: flex;
    text-align: left;

    .user-block {
      min-width: 0;
    }

    .user-thumbnail-box {
      margin-right: var(--space-small);
    }

    .user-name {
      font-size: var(--font-size-small);
      font-weight: var(--font-weight-medium);
      margin: 0;
      text-transform: capitalize;
    }

    .view-details--button {
      color: var(--color-body);
    }

    .user-email {
      margin: 0;
    }
  }

  .ve-table-header-th {
    padding: var(--space-small) var(--space-two) !important;
  }

  .ve-table-body-td {
    padding: var(--space-small) var(--space-two) !important;
  }

  .ve-table-header-th {
    font-size: var(--font-size-mini) !important;
  }

  .ve-table-sort {
    top: -4px;
  }
}

.contacts--loader {
  align-items: center;
  display: flex;
  font-size: var(--font-size-default);
  justify-content: center;
  padding: var(--space-big);
}

.cell--social-profiles {
  a {
    color: var(--s-300);
    display: inline-block;
    font-size: var(--font-size-medium);
    min-width: var(--space-large);
    text-align: center;
  }
}
</style>
