# frozen_string_literal: true

# ================================================================================
# proyecto@asistente_agentes_ia — GUARDAR EL ENTRENAMIENTO
# ================================================================================
# Lleva el borrador del asistente a un Agente IA: crea uno nuevo, o reemplaza el
# Entrenamiento de uno que ya existe.
#
# POR QUÉ NO GUARDA SI HAY BLOQUEANTES:
#   Todo el módulo existe porque hoy se puede guardar un agente que no ejecuta nada
#   y nadie se entera. Dejar que el guardado se saltee el comprobador sería
#   reintroducir el defecto por la puerta de atrás. Los hallazgos que DEGRADAN sí
#   dejan guardar: avisan de algo que funciona mal, no de algo que no existe.
#
# AL REEMPLAZAR SE GUARDA EL ANTERIOR:
#   En previous_complementary_prompt. Es una columna y no una tabla de versiones
#   porque lo que hace falta acá es poder volver atrás UNA vez, en el momento: si el
#   Entrenamiento nuevo sale peor, se revierte sin depender de que alguien haya
#   copiado el viejo a mano antes de guardar.
# ================================================================================

class ContactTrackings::Assistant::SaveService
  Result = Struct.new(:template, :error, :details, keyword_init: true) do
    def success? = error.blank?
  end

  def initialize(account, user:, draft:, mode:, params: {})
    @account = account
    @user = user
    @draft = draft.to_s
    @mode = mode.to_s
    @params = params
  end

  def call
    return Result.new(error: :empty_draft) if @draft.blank?

    validation = ContactTrackings::Assistant::ValidatorService.new(@draft, account: @account).call
    return Result.new(error: :blocking_findings, details: validation[:blocking]) if validation[:blocking].any?

    case @mode
    when 'create'  then create
    when 'replace' then replace
    else Result.new(error: :unknown_mode)
    end
  end

  private

  def create
    template = @account.tracking_templates.new(
      name: @params[:name],
      objective: @params[:objective],
      # Solo lo que la persona dijo en la conversación. Vacío es una respuesta
      # válida: rellenarlo de memoria le haría citar al agente cosas falsas.
      ai_context: @params[:ai_context].presence,
      inbox_id: resolved_inbox_id,
      complementary_prompt: @draft,
      user: @user
    )
    template.save ? Result.new(template: template) : Result.new(error: :invalid, details: template.errors.full_messages)
  end

  def replace
    template = @account.tracking_templates.find_by(id: @params[:template_id])
    return Result.new(error: :template_not_found) if template.nil?

    # El anterior se guarda ANTES de pisarlo; si el update falla, no se perdió nada.
    template.previous_complementary_prompt = template.complementary_prompt
    template.complementary_prompt = @draft
    template.save ? Result.new(template: template) : Result.new(error: :invalid, details: template.errors.full_messages)
  end

  # Un inbox de otra cuenta no se liga: se ignora, igual que hace el inventario.
  def resolved_inbox_id
    @account.inboxes.where(id: @params[:inbox_id]).pick(:id)
  end
end
