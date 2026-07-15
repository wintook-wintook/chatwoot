# frozen_string_literal: true

# @waba_templates
# Procesa los webhooks de CICLO DE VIDA de plantilla de Meta (field message_template_*):
#   - status_update     → actualiza status por meta_template_id (APPROVED sin sync manual);
#                         guarda rejection_reason SOLO en REJECTED, lo limpia en otros flips.
#   - quality_update    → quality_score GREEN/YELLOW/RED.
#   - components_update  → log + sugiere re-sync (no auto-aplica).
#
# ⚠️ Estos campos NO se suscriben por API: hay que activarlos a mano en
#    Meta App Dashboard → WhatsApp → Configuration → Webhooks. El botón Sync es el fallback.
class Whatsapp::TemplateWebhookService
  def initialize(channel, change)
    @channel = channel
    @change = change.with_indifferent_access
    @field = @change[:field].to_s
    @value = (@change[:value] || {}).with_indifferent_access
  end

  def perform
    meta_id = @value[:message_template_id].to_s
    return log('webhook de plantilla sin message_template_id') if meta_id.blank?

    templates = @channel.whatsapp_templates.by_meta_id(meta_id)
    return log("webhook sin fila local (meta_id=#{meta_id}) — ¿falta sync?") if templates.empty?

    log("colisión de meta_template_id=#{meta_id} (#{templates.size} filas)") if templates.size > 1
    templates.each { |template| apply(template) }
  end

  private

  def apply(template)
    case @field
    when 'message_template_status_update'     then update_status(template)
    when 'message_template_quality_update'    then update_quality(template)
    when 'message_template_components_update' then note_components(template)
    else log("field no manejado: #{@field}")
    end
  end

  def update_status(template)
    status = @value[:event].to_s.upcase
    return log("evento de status desconocido: #{status}") unless WhatsappTemplate::STATUSES.include?(status)

    template.status = status
    template.rejection_reason = status == 'REJECTED' ? rejection_reason : nil
    template.save!(validate: false)
  end

  def update_quality(template)
    score = @value[:new_quality_score].to_s.upcase
    normalized = WhatsappTemplate::QUALITY_SCORES.include?(score) ? score : nil
    # rubocop:disable Rails/SkipsModelValidations
    template.update_column(:quality_score, normalized)
    # rubocop:enable Rails/SkipsModelValidations
  end

  def note_components(template)
    Rails.logger.info "[waba_templates] components_update meta_id=#{template.meta_template_id} — se sugiere re-sync"
  end

  def rejection_reason
    reason = @value[:reason].to_s
    reason.blank? || reason.casecmp('NONE').zero? ? nil : reason
  end

  def log(message)
    Rails.logger.warn "[waba_templates] #{message}"
    nil
  end
end
