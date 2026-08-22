class ItemSerializer
  def self.call(item, list:)
    ReleaseSerializer.summary(item.release).merge(
      list: list,
      item_id: item.id,
      rating: item.rating,
      date_added: item.date_added,
      notes: item.notes.presence
    )
  end
end
