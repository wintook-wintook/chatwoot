# frozen_string_literal: true

# Asistente (Dali) — guarda la plantilla de seguimiento confirmada. Se incluye en Assistant::Executor.
module Assistant::FollowUpPresetRunner
  def run_save_follow_up_preset(payload)
    preset = @account.ai_follow_up_presets.create!(payload.slice('name', *AiFollowUpPreset::FIELDS).merge('created_by' => @user))
    done("Plantilla de seguimiento «#{preset.name}» guardada", "#{base}/tickets")
  rescue ActiveRecord::RecordInvalid => e
    raise Assistant::Executor::Refused, e.record.errors.full_messages.to_sentence
  end
end
