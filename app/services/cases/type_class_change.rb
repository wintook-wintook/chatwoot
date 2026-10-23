# frozen_string_literal: true

# ================================================================================
# @tickets_cases — «Cambiar de clase» un tipo de caso
# ================================================================================
# La clase vive en el tipo y sus casos la heredan, así que un tipo con casos no
# cambia de clase en su lugar. En su lugar:
#   1. se crea un tipo NUEVO en la otra clase con el mismo nombre, color, prefijo,
#      campos personalizados y clasificación (servicios y categorías); sus etapas
#      son las de la clase nueva;
#   2. el consecutivo del folio sigue donde iba (mismo prefijo, sin repetir folios);
#   3. el tipo de antes se RETIRA con sus casos tal cual (clase, etapas, datos,
#      historia, métricas) y su nombre lleva «(anterior)», para que @crear_ticket
#      (que busca el tipo por nombre) encuentre el nuevo;
#   4. las automatizaciones «Asignar Caso» que usaban el tipo viejo pasan al nuevo,
#      y las reglas de casos que lo nombran lo siguen nombrando y suman el nuevo.
# Sin casos, el tipo cambia de clase directo (sus etapas pasan a las de la nueva).
# ================================================================================

class Cases::TypeClassChange
  Result = Struct.new(:type, :retired, :kept_cases, :automations, :rules, keyword_init: true)
  RETIRED_SUFFIX = ' (anterior)'
  NAME_MAX = 100 # CaseType valida el nombre hasta 100
  TYPE_ATTRS = %w[color position prefix public itil_enabled].freeze

  def initialize(type, new_class)
    @type = type
    @account = type.account
    @new_class = new_class.to_s
  end

  def call
    raise ArgumentError, 'El tipo ya es de esa clase' if @type.case_class == @new_class
    raise ArgumentError, 'Un tipo retirado no cambia de clase' if @type.retired?
    return change_in_place unless @type.case_tickets.exists?

    CaseType.transaction { replace_type }
  end

  private

  def change_in_place
    @type.update!(case_class: @new_class)
    Result.new(type: @type, retired: nil, kept_cases: 0, automations: [], rules: [])
  end

  def replace_type
    kept = @type.case_tickets.count
    name = @type.name
    @type.update!(name: retired_name(name), retired_at: Time.current)
    new_type = @account.case_types.create!(@type.attributes.slice(*TYPE_ATTRS).merge(name: name, case_class: @new_class))
    copy_fields(new_type)
    copy_classification(new_type)
    continue_folio_series(new_type)
    Result.new(type: new_type, retired: @type, kept_cases: kept,
               automations: repoint_automations(new_type), rules: extend_rules(new_type))
  end

  def retired_name(name)
    "#{name.to_s.first(NAME_MAX - RETIRED_SUFFIX.size)}#{RETIRED_SUFFIX}"
  end

  def copy_fields(new_type)
    @type.case_type_fields.each do |field|
      new_type.case_type_fields.create!(field.attributes.except('id', 'case_type_id', 'created_at', 'updated_at'))
    end
  end

  def copy_classification(new_type)
    @type.case_services.each do |service|
      new_type.case_services.create!(service.attributes.except('id', 'case_type_id', 'created_at', 'updated_at'))
    end
    CaseCategory.where(case_type_id: @type.id, parent_id: nil).find_each { |root| copy_category(root, new_type, nil) }
  end

  def copy_category(category, new_type, parent_id)
    copy = CaseCategory.create!(category.attributes.except('id', 'case_type_id', 'parent_id', 'created_at', 'updated_at')
                                        .merge(case_type_id: new_type.id, parent_id: parent_id))
    CaseCategory.where(parent_id: category.id).find_each { |child| copy_category(child, new_type, copy.id) }
  end

  # Contadores «type:<viejo>[:periodo]» → «type:<nuevo>[:periodo]» con el mismo valor.
  def continue_folio_series(new_type)
    CaseFolioCounter.where(account_id: @account.id).where('counter_key LIKE ?', "type:#{@type.id}%").find_each do |counter|
      suffix = counter.counter_key.delete_prefix("type:#{@type.id}")
      next unless suffix.empty? || suffix.start_with?(':')

      CaseFolioCounter.create!(account_id: @account.id, counter_key: "type:#{new_type.id}#{suffix}", value: counter.value)
    end
  end

  def repoint_automations(new_type)
    AutomationRule.where(account_id: @account.id).filter_map do |rule|
      changed = false
      actions = Array(rule.actions).map do |action|
        next action unless action['action_name'] == 'assign_case_type' && Array(action['action_params']).first.to_s == @type.id.to_s

        changed = true
        action.merge('action_params' => [new_type.id])
      end
      next unless changed

      rule.update!(actions: actions)
      { id: rule.id, name: rule.name }
    end
  end

  # La regla que nombra el tipo viejo nombra también el nuevo (eq → in, neq → not_in).
  def extend_rules(new_type)
    CaseRule.where(account_id: @account.id).filter_map do |rule|
      changed = false
      conditions = Array(rule.conditions).map do |c|
        next c unless c['field'] == 'case_type' && Array(c['value']).map(&:to_s).include?(@type.id.to_s)

        changed = true
        extended_condition(c, new_type)
      end
      next unless changed

      rule.update!(conditions: conditions)
      { id: rule.id, name: rule.name }
    end
  end

  def extended_condition(condition, new_type)
    operator = { 'eq' => 'in', 'neq' => 'not_in' }.fetch(condition['operator'], condition['operator'])
    condition.merge('operator' => operator, 'value' => (Array(condition['value']) + [new_type.id]).map(&:to_s).uniq)
  end
end
