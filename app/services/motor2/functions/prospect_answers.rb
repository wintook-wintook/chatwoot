# frozen_string_literal: true

# «Atención a prospectos» — lo que manda su asistente, limpio: solo las llaves que conoce la función
# (Motor2::Functions::Prospects), con tope. Es lo que se guarda en motor2['answers'].
module Motor2::Functions::ProspectAnswers
  P = Motor2::Functions::Prospects

  module_function

  def call(raw)
    raw = Motor2::Sanitizer.plain(raw)
    out = P::TEXTS.index_with { |k| raw[k].to_s.strip.first(1000) }
    P::IDS.each { |k| out[k] = raw[k].to_s.strip.presence&.to_i }
    P::BOOLEANS.each { |k| out[k] = raw.key?(k) ? ActiveModel::Type::Boolean.new.cast(raw[k]) || false : k == 'only_prospects' }
    out.merge(lists(raw), rows(raw)).compact
  end

  def lists(raw)
    { 'question_list' => Array(raw['question_list']).map { |q| q.to_s.squish.first(300) }.compact_blank.first(P::MAX_QUESTIONS),
      'appointment_user_ids' => Array(raw['appointment_user_ids']).map(&:to_i).select(&:positive?).uniq,
      'required_contact' => Array(raw['required_contact']).map(&:to_s) & P::CONTACT_FIELDS.keys }
  end

  def rows(raw)
    { 'qualify' => Array(raw['qualify']).filter_map { |q| qualify_row(Motor2::Sanitizer.plain(q)) },
      'objections' => Array(raw['objections']).filter_map { |o| objection_row(Motor2::Sanitizer.plain(o)) }.first(P::MAX_OBJECTIONS) }
  end

  def qualify_row(row)
    return unless P::QUESTIONS.key?(row['key'])

    { 'key' => row['key'], 'on' => ActiveModel::Type::Boolean.new.cast(row['on']) || false, 'text' => row['text'].to_s.strip.first(300) }
  end

  def objection_row(row)
    objection = row['objection'].to_s.strip.first(300)
    answer = row['answer'].to_s.strip.first(800)
    { 'objection' => objection, 'answer' => answer } if objection.present? && answer.present?
  end
end
