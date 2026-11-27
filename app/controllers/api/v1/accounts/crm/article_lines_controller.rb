# CrmZeus A1 — líneas de artículos (con su grupo de líneas).
#
#   GET /crm/article_lines · POST /crm/article_lines · PATCH/DELETE /crm/article_lines/:id
class Api::V1::Accounts::Crm::ArticleLinesController < Api::V1::Accounts::Crm::CatalogBaseController
  private

  def relation
    Current.account.crm_article_lines.includes(:group)
  end

  def record_params
    params.require(:article_line).permit(:name, :key, :group_id, :is_default, :active)
  end

  def record_json(record)
    Crm::CatalogJson.article_line(record)
  end

  def usage_count(record)
    Current.account.crm_articles.where(line_id: record.id).count
  end

  def in_use_message(count)
    "#{used_by(count, 'artículo', 'artículos')}; desactívala en lugar de borrarla"
  end
end
