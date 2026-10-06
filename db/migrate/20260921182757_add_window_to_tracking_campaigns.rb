# frozen_string_literal: true

# proyecto@automatizacion_campanas — la campaña con VENTANA (docs/automatizacion_campanas_plan.md §5.1).
#
# `scheduled_for` sigue siendo el INICIO de la ventana: no se renombra porque hay datos y
# código (bulk, dashboard) que ya lo leen. Lo nuevo es el fin, el tipo y cómo se agenda a
# cada inscrito. Las campañas que ya existen quedan "por lote" (batch), que es lo que son.
#
# Cada columna va escrita a mano, con su `unless column_exists?`: con un `**options`
# genérico el cop Rails/NotNullColumn de RuboCop falla por dentro y frena el commit.
class AddWindowToTrackingCampaigns < ActiveRecord::Migration[7.0]
  def up
    add_column :tracking_campaigns, :mode, :string, default: 'batch', null: false unless exists?(:mode)
    add_column :tracking_campaigns, :ends_at, :datetime unless exists?(:ends_at)
    add_column :tracking_campaigns, :entry_delay_minutes, :integer, default: 0, null: false unless exists?(:entry_delay_minutes)
    add_column :tracking_campaigns, :respect_working_hours, :boolean, default: true, null: false unless exists?(:respect_working_hours)
    add_column :tracking_campaigns, :daily_cap, :integer unless exists?(:daily_cap)
    add_column :tracking_campaigns, :audience, :jsonb, default: {}, null: false unless exists?(:audience)
  end

  def down
    %i[mode ends_at entry_delay_minutes respect_working_hours daily_cap audience].each do |name|
      remove_column :tracking_campaigns, name if exists?(name)
    end
  end

  private

  def exists?(name)
    column_exists?(:tracking_campaigns, name)
  end
end
