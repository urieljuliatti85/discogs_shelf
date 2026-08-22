class WantlistItem < ApplicationRecord
  belongs_to :release

  validates :release_id, uniqueness: true

  scope :recent_first, -> { order(date_added: :desc, id: :desc) }
end
