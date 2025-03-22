<template>
    <div class="mt-6 flex-1">
        <ve-table
          :fixed-header="true"
          max-height="calc(100vh - 34.2rem)"
          :columns="columns"
          :table-data="dataSinonimosRaiz"
          :border-around="false"
        />
    </div>
</template>

<script>
    import { VeTable } from 'vue-easytable';

    import Spinner from 'shared/components/Spinner.vue';
    import EmptyState from 'dashboard/components/widgets/EmptyState.vue';

    export default {
        components: {
            EmptyState,
            Spinner,
            VeTable,
        },
        props: {
            dataSinonimosRaiz: {
                type: Array,
                default: () => [],
            },
            onToggleEdit: {
              type: Function,
              default: (data) => {},
            },
            onToggleDelete: {
              type: Function,
              default: (data) => {},
            },
            onToggleFilterClick: {
              type: Function,
              default: (data) => {},
            },
        },
        data() {
            return {
                sortConfig: {},
            };
        },
        computed: {
            columns() {
                return [{
                        field: 'palabra',
                        key: 'palabra',
                        title: 'Sinónimo Raíz',
                        fixed: 'left',
                        align: 'left',
                        width: 70,
                        sortBy: this.sortConfig.palabra_clave || '',
                        renderBodyCell: ({ row }) => (
                          <div class="button-wrapper">
                            <woot-button variant="link" color-scheme="secondary" 
                              onClick={() => this.onToggleFilterClick(row)}>
                                {`${row.palabra}`}
                            </woot-button>
                          </div>
                        )
                    },{
                        field: 'palabra_id',
                        key: 'palabra_id',
                        title: '',
                        width: 70,
                        align: 'left',
                        renderBodyCell: ({ row }) => (
                          <div class="button-wrapper">
                            <woot-button variant="link" color-scheme="secondary" 
                              class-names="grey-btn" icon="edit"
                              onClick={() => this.onToggleEdit(row)}>
                            </woot-button>
                            <woot-button variant="link" color-scheme="secondary" 
                              class-names="grey-btn" icon="dismiss-circle"
                              onClick={() => this.onToggleDelete(row)}>
                            </woot-button>
                          </div>
                        )
                    },
                ];
            },
        }
    }
</script>


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