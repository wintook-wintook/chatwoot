<!-- 
  ================================================================================
  proyecto@contact_tracking
  ================================================================================
  Componente: TrackingList.vue
  Descripción: Lista de seguimientos con filtros y acciones
  Líneas: ~250
  ================================================================================
-->

<template>
    <div class="space-y-3 flex-1 flex flex-col min-h-[480px]">

        <!-- Filtros y Botón de Nuevo -->
        <div class="flex flex-col sm:flex-row justify-between items-stretch sm:items-center gap-3 flex-shrink-0">
            <div class="w-full sm:w-1/4 flex items-center">
                <select v-model="filters.status"
                    class="w-full h-[38px] bg-white dark:bg-slate-900 text-slate-900 dark:text-slate-100 border border-slate-200 dark:border-slate-600 rounded-md px-3 py-2 text-sm focus:outline-none focus:ring-1 focus:ring-woot-200 focus:border-woot-200"
                    style="margin-bottom: 0px;">
                    <option value="">Todos los estados</option>
                    <!-- <option value="pending">Pendiente</option> -->
                    <option value="scheduled">Programado</option>
                    <option value="active">Activo</option>
                    <option value="paused">Pausado</option>
                    <option value="completed">Completado</option>
                    <option value="cancelled">Cancelado</option>
                    <option value="failed">Fallido</option>
                </select>
            </div>

            <div class="w-full sm:flex-1 flex items-center">
                <input v-model="filters.searchText" type="text" placeholder="Buscar por objetivo..."
                    class="w-full h-[38px] bg-white dark:bg-slate-900 text-slate-900 dark:text-slate-100 border border-slate-200 dark:border-slate-600 rounded-md px-3 py-2 text-sm focus:outline-none focus:ring-1 focus:ring-woot-200 focus:border-woot-200" 
                    style="margin-bottom: 0px;"/>
            </div>

            <div class="w-full sm:w-auto flex-shrink-0 flex items-center gap-2">
                <woot-button color-scheme="secondary" variant="smooth" icon="arrow-clockwise" size="medium"
                    @click="$emit('refresh')">
                    Actualizar
                </woot-button>
                <woot-button
                    color-scheme="primary"
                    icon="add"
                    size="medium"
                    :is-disabled="hasActiveTracking"
                    v-tooltip="hasActiveTracking ? 'Ya existe un seguimiento activo para este contacto' : ''"
                    @click="$emit('add-new')">
                    Nuevo Seguimiento
                </woot-button>
            </div>
        </div>

        <!-- Contenedor VeTable -->
        <div class="flex-1 min-h-[380px] tracking-table-wrap">

            <!-- Loading -->
            <div v-if="isLoading" class="flex items-center justify-center h-64">
                <spinner size="small" />
            </div>

            <!-- Empty state -->
            <div v-else-if="filteredTrackings.length === 0" class="flex items-center justify-center h-64">
                <div class="flex flex-col items-center text-slate-600 dark:text-slate-400">
                    <fluent-icon icon="calendar-empty" size="48" class="mb-4" />
                    <p>No hay seguimientos creados</p>
                </div>
            </div>

            <!-- Tabla -->
            <VeTable v-else fixed-header max-height="380px" :columns="tableColumns" :table-data="filteredTrackings" />
        </div>
    </div>
</template>

<script>
import { VeTable } from 'vue-easytable';
import Spinner from 'shared/components/Spinner.vue';
import {
    formatDateTime,
    getStatusClass,
    getStatusLabel,
    canCancel,
    canEdit
} from '../../../helper/trackingHelpers';

export default {
    name: 'TrackingList',

    components: {
        VeTable,
        Spinner,
    },

    props: {
        contactId: {
            type: Number,
            required: true,
        },
        conversationId: {
            type: Number,
            default: null,
        },
        trackings: {
            type: Array,
            default: () => [],
        },
        isLoading: {
            type: Boolean,
            default: false,
        },
    },

    emits: ['edit', 'pause', 'resume', 'cancel', 'refresh', 'add-new'],

    data() {
        return {
            filters: {
                status: '',
                searchText: '',
            },
        };
    },

    computed: {
        // Verifica si existe un seguimiento activo/programado/pendiente
        hasActiveTracking() {
            return this.trackings.some(t =>
                t.status === 'pending' ||
                t.status === 'scheduled' ||
                t.status === 'active' ||
                t.status === 'paused'
            );
        },

        filteredTrackings() {
            let filtered = [...this.trackings];

            if (this.filters.status) {
                filtered = filtered.filter(t => t.status === this.filters.status);
            }

            if (this.filters.searchText) {
                const search = this.filters.searchText.toLowerCase();
                filtered = filtered.filter(
                    t =>
                        (t.objective && t.objective.toLowerCase().includes(search)) ||
                        (t.last_message_sent && t.last_message_sent.toLowerCase().includes(search))
                );
            }

            return filtered;
        },

        tableColumns() {
            return [
                {
                    field: 'objective',
                    key: 'objective',
                    title: 'Objetivo',
                    align: 'left',
                    width: '30%',
                    renderBodyCell: ({ row }) => {
                        return (
                            <div class="flex items-center gap-2">
                                <span class="text-sm">{row.objective}</span>
                                {row.ai_context && (
                                    <fluent-icon
                                        icon="bot"
                                        size="14"
                                        class="text-woot-500"
                                        v-tooltip="Con IA habilitada"
                                    />
                                )}
                                {row.whatsapp_templates && row.whatsapp_templates.filter(t => t).length > 0 && (
                                    <fluent-icon
                                        icon="chat-multiple"
                                        size="14"
                                        class="text-green-600"
                                        v-tooltip={`${row.whatsapp_templates.filter(t => t).length} plantillas WhatsApp`}
                                    />
                                )}
                            </div>
                        );
                    },
                },
                {
                    field: 'scheduled_for',
                    key: 'scheduled_for',
                    title: 'Programado',
                    align: 'left',
                    width: '15%',
                    renderBodyCell: ({ row }) => {
                        return (
                            <span class="text-sm text-slate-600 dark:text-slate-400">
                                {this.formatDateTime(row.scheduled_for)}
                            </span>
                        );
                    },
                },
                {
                    field: 'attempts',
                    key: 'attempts',
                    title: 'Recordatorios',
                    align: 'center',
                    width: '10%',
                    renderBodyCell: ({ row }) => {
                        // Si está completado, mostrar solo (attempt_count)
                        if (row.status === 'completed') {
                            return (
                                <span class="text-sm text-slate-600 dark:text-slate-400">
                                    ({row.attempt_count})
                                </span>
                            );
                        }

                        // En proceso: mostrar attempt_count + 1 / max_attempts
                        const displayCount = row.attempt_count + 1;
                        return (
                            <span class="text-sm text-slate-600 dark:text-slate-400">
                                {displayCount} / {row.max_attempts}
                            </span>
                        );
                    },
                },
                {
                    field: 'status',
                    key: 'status',
                    title: 'Estado',
                    align: 'left',
                    width: '12%',
                    renderBodyCell: ({ row }) => {
                        // Mostrar "Programado" para pending, scheduled, active
                        // Mostrar el estado real para completed, cancelled, failed, paused
                        let displayStatus = row.status;

                        if (['pending', 'scheduled', 'active'].includes(row.status)) {
                            displayStatus = 'scheduled';
                        }

                        const statusClass = this.getStatusClass(displayStatus);
                        return (
                            <span class={['status-badge', statusClass]}>
                                {this.getStatusLabel(displayStatus)}
                            </span>
                        );
                    },
                },
                {
                    field: 'actions',
                    key: 'actions',
                    title: 'Acciones',
                    align: 'center',
                    width: '18%',
                    renderBodyCell: ({ row }) => {
                        return (
                            <div class="button-wrapper">
                                {(row.status === 'active' || row.status === 'scheduled') && (
                                    <woot-button
                                        color-scheme="secondary"
                                        variant="smooth"
                                        size="small"
                                        icon="snooze"
                                        v-tooltip="Pausar"
                                        onClick={() => this.$emit('pause', row.id)}
                                    />
                                )}
                                {row.status === 'paused' && (
                                    <woot-button
                                        color-scheme="success"
                                        variant="smooth"
                                        size="small"
                                        icon="calendar-clock"
                                        v-tooltip="Reanudar"
                                        onClick={() => this.$emit('resume', row.id)}
                                    />
                                )}
                                {this.canCancel(row.status) && (
                                    <woot-button
                                        color-scheme="alert"
                                        variant="smooth"
                                        size="small"
                                        icon="dismiss"
                                        v-tooltip="Cancelar"
                                        onClick={() => this.$emit('cancel', row.id)}
                                    />
                                )}
                                {this.canEdit(row.status) && (
                                    <woot-button
                                        color-scheme="primary"
                                        variant="smooth"
                                        size="small"
                                        icon="edit"
                                        v-tooltip="Editar"
                                        onClick={() => this.$emit('edit', row)}
                                    />
                                )}
                            </div>
                        );
                    },
                },
            ];
        },
    },

    methods: {
        formatDateTime,
        getStatusClass,
        getStatusLabel,
        canCancel,
        canEdit,
    },
};
</script>

<style lang="scss" scoped>
.min-h-\[380px\] {
    min-height: 380px;
}

.tracking-table-wrap {
    flex: 1 1;
    height: 100%;
    overflow: hidden;
}

.tracking-table-wrap::v-deep {
    .ve-table {
        padding-bottom: var(--space-large);
    }

    .ve-table-header-th {
        padding: var(--space-small) var(--space-two) !important;
        font-size: var(--font-size-mini) !important;
        font-weight: var(--font-weight-medium) !important;
    }

    .ve-table-body-td {
        padding: var(--space-small) var(--space-two) !important;
    }

    .button-wrapper {
        display: flex;
        align-items: center;
        justify-content: center;
        gap: var(--space-micro);
    }

    .status-badge {
        display: inline-flex;
        padding: var(--space-micro) var(--space-smaller);
        font-size: var(--font-size-mini);
        font-weight: var(--font-weight-medium);
        border-radius: var(--border-radius-small);

        &.status-pending {
            background-color: var(--y-100);
            color: var(--y-800);
        }

        &.status-scheduled {
            background-color: var(--b-100);
            color: var(--b-800);
        }

        &.status-active {
            background-color: var(--g-100);
            color: var(--g-800);
        }

        &.status-paused {
            background-color: var(--s-100);
            color: var(--s-800);
        }

        &.status-completed {
            background-color: var(--g-200);
            color: var(--g-900);
        }

        &.status-cancelled {
            background-color: var(--s-200);
            color: var(--s-900);
        }

        &.status-failed {
            background-color: var(--r-100);
            color: var(--r-800);
        }
    }
}

input,
select {
    height: 38px !important;
    font-size: 14px !important;
}
</style>