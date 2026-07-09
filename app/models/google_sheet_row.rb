# == Schema Information
#
# Table name: google_sheet_rows
#
#  id                  :bigint           not null, primary key
#  data                :jsonb            not null
#  row_index           :integer          not null
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  account_id          :bigint           not null
#  knowledge_source_id :bigint           not null
#
# Indexes
#
#  idx_google_sheet_rows_unique           (knowledge_source_id,row_index) UNIQUE
#  index_google_sheet_rows_on_account_id  (account_id)
#
class GoogleSheetRow < ApplicationRecord
  belongs_to :account
  belongs_to :knowledge_source

  validates :row_index, presence: true
end
