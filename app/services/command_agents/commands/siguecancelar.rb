# frozen_string_literal: true
# proyecto@bot_comando

# ================================================================================
# proyecto@commands_agents [ARCHIVO NUEVO]
# ================================================================================
# Service: CommandAgents::Commands::Siguecancelar
# Descripcion: Comando /siguecancelar — cancela un seguimiento activo de un contacto.
#
# Flujo:
#   1. start             → pide teléfono o nombre del contacto
#   2. ask_contact       → busca el contacto y muestra su seguimiento activo → pide confirmación
#   3. confirm_cancel    → cancela el seguimiento si el agente confirma
#
# Fecha: 2026-03-17
# ================================================================================

module CommandAgents
  module Commands
    class Siguecancelar < Base
      COMMAND_NAME = 'siguecancelar'
      STEPS = %w[ask_contact confirm_cancel].freeze

      # ============================================================
      # Inicio del comando
      # ============================================================
      def start
        create_session(STEPS.first)
        reply("🔍 ¿A qué contacto deseas cancelarle el seguimiento?\nEscribe el *nombre* o *teléfono*:")
      end

      # ============================================================
      # Procesamiento de respuestas según el paso actual
      # ============================================================
      def continue
        return cancel_session if cancel_requested?(input)

        case @session.current_step
        when 'ask_contact'    then handle_ask_contact
        when 'confirm_cancel' then handle_confirm_cancel
        else
          Rails.logger.error "[Commands::Siguecancelar] Paso desconocido: #{@session.current_step}"
          cancel_session('Ocurrió un error interno. Intenta de nuevo con /siguecancelar.')
        end
      end

      private

      # ============================================================
      # Paso 1: Buscar contacto y mostrar su seguimiento activo
      # ============================================================
      def handle_ask_contact
        query    = input.strip
        contacts = search_contacts(query)

        if contacts.empty?
          reply("⚠️ No encontré ningún contacto con *\"#{query}\"*.\nIntenta con otro nombre o teléfono:")
          return
        end

        if contacts.size > 1
          lista = contacts.each_with_index.map { |c, i| "#{i + 1}. #{c.name} #{c.phone_number}" }.join("\n")
          reply("⚠️ Encontré varios contactos. Sé más específico:\n#{lista}")
          return
        end

        contact  = contacts.first
        tracking = active_tracking_for_contact(contact.id)

        unless tracking
          @session&.cancel!
          reply("ℹ️ El contacto *#{contact.name}* no tiene ningún seguimiento activo.\n\nPara crear uno nuevo escribe */sigue*")
          return
        end

        save_data('contact_id',   contact.id)
        save_data('contact_name', contact.name)
        save_data('tracking_id',  tracking.id)

        advance_to('confirm_cancel')
        reply(<<~MSG)
          📋 Seguimiento encontrado:

          👤 Contacto: *#{contact.name}* #{contact.phone_number}
          📌 Plantilla: *#{tracking.tracking_template&.name || '—'}*
          📅 Programado: #{tracking.scheduled_for&.strftime('%d/%m/%Y a las %H:%M') || '—'}
          🔁 Estado: #{tracking.status}

          ¿Confirmas cancelar este seguimiento? (*si* / *no*)
        MSG
      end

      # ============================================================
      # Paso 2: Confirmar y cancelar el seguimiento
      # ============================================================
      def handle_confirm_cancel
        answer = input.downcase.strip

        if %w[si sí yes s].include?(answer)
          tracking = ContactTracking.find_by(id: get_data('tracking_id'))

          unless tracking
            cancel_session('No se encontró el seguimiento. Puede que ya haya sido cancelado.')
            return
          end

          if tracking.cancel!
            @session.complete!
            reply("✅ Seguimiento de *#{get_data('contact_name')}* cancelado correctamente.\n\nPara crear uno nuevo escribe */sigue*")
          else
            cancel_session("No se pudo cancelar el seguimiento (estado actual: #{tracking.status}).")
          end

        elsif %w[no n cancelar].include?(answer)
          cancel_session('Operación cancelada. El seguimiento sigue activo.')

        else
          reply("¿Confirmas cancelar el seguimiento? Responde *si* para cancelar o *no* para dejarlo activo.")
        end
      end

      # ============================================================
      # Helpers privados
      # ============================================================

      def search_contacts(query)
        @account.contacts
                .where('phone_number ILIKE :q OR name ILIKE :q', q: "%#{query}%")
                .limit(5)
      end

      def active_tracking_for_contact(contact_id)
        ContactTracking
          .where(contact_id: contact_id, status: %w[pending scheduled active paused])
          .order(created_at: :desc)
          .first
      end
    end
  end
end
