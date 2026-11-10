# frozen_string_literal: true

# fix/mensajes_programados — ScheduledMessage usa estas columnas, pero nunca tuvieron migración:
# se agregaron a mano en alguna base y por eso entraban y salían de schema.rb. Donde faltaban,
# crear un mensaje programado tronaba con NoMethodError (is_template?). `if_not_exists`: en las
# bases que ya las tienen esta migración no cambia nada.
class AddTemplateFieldsToScheduledMessages < ActiveRecord::Migration[7.0]
  def change
    add_column :scheduled_messages, :template_name, :string, if_not_exists: true
    add_column :scheduled_messages, :template_language, :string, if_not_exists: true
    add_column :scheduled_messages, :template_category, :string, if_not_exists: true
    add_column :scheduled_messages, :template_namespace, :string, if_not_exists: true
    add_column :scheduled_messages, :template_params, :json, if_not_exists: true
    # Igual que en las bases que ya la tienen: con null: false quedarían distintas.
    add_column :scheduled_messages, :is_template, :boolean, default: false, if_not_exists: true # rubocop:disable Rails/ThreeStateBooleanColumn
  end
end
