class CollectionItem < ApplicationRecord
  belongs_to :release

  validates :instance_id, presence: true, uniqueness: true

  scope :recent_first, -> { order(date_added: :desc, id: :desc) }
end
