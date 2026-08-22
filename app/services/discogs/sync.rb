module Discogs
  # Pulls the collection and the wantlist from Discogs into SQLite.
  # Progress is written to a SyncRun so the UI can poll it.
  class Sync
    attr_reader :client, :sync_run

    def initialize(client: Client.new, sync_run: nil)
      @client = client
      @sync_run = sync_run || SyncRun.create!(status: "pending")
    end

    def call
      sync_run.start!(stage: "collection")
      @seen_instance_ids = Set.new
      @seen_want_release_ids = Set.new

      collection_total = 0
      wantlist_total = 0

      client.each_page(:collection, on_pagination: ->(p) {
        collection_total = p["items"].to_i
        sync_run.update!(total_count: collection_total)
      }) do |items, _pagination|
        import_collection(items)
      end

      seen_ids = @seen_instance_ids.to_a
      CollectionItem.where.not(instance_id: seen_ids).delete_all if seen_ids.any?

      sync_run.update!(stage: "wantlist")

      client.each_page(:wantlist, on_pagination: ->(p) {
        wantlist_total = p["items"].to_i
        sync_run.update!(total_count: collection_total + wantlist_total)
      }) do |items, _pagination|
        import_wantlist(items)
      end

      seen_wants = @seen_want_release_ids.to_a
      WantlistItem.where.not(release_id: seen_wants).delete_all if seen_wants.any?

      Release.where.missing(:collection_item).where.missing(:wantlist_item).delete_all

      sync_run.finish!
      sync_run
    rescue StandardError => e
      Rails.logger.error("[Discogs::Sync] #{e.class}: #{e.message}")
      sync_run.fail!("#{e.class}: #{e.message}")
      raise
    end

    private

    def import_collection(items)
      items.each do |item|
        release = upsert_release(item["basic_information"])
        next unless release

        record = CollectionItem.find_or_initialize_by(instance_id: item["instance_id"])
        record.assign_attributes(
          release: release,
          folder_id: item["folder_id"],
          rating: item["rating"].to_i,
          date_added: parse_time(item["date_added"]),
          notes: Array(item["notes"])
        )
        record.save!
        @seen_instance_ids << record.instance_id
      end

      bump_progress(items.size)
    end

    def import_wantlist(items)
      items.each do |item|
        release = upsert_release(item["basic_information"])
        next unless release

        record = WantlistItem.find_or_initialize_by(release_id: release.id)
        record.assign_attributes(
          rating: item["rating"].to_i,
          notes: item["notes"].presence,
          date_added: parse_time(item["date_added"])
        )
        record.save!
        @seen_want_release_ids << release.id
      end

      bump_progress(items.size)
    end

    def upsert_release(info)
      return nil if info.blank?

      attributes = ReleaseMapper.attributes_from(info)
      return nil if attributes[:discogs_id].blank?

      release = Release.find_or_initialize_by(discogs_id: attributes[:discogs_id])
      release.assign_attributes(attributes.except(:discogs_id))
      release.save!
      release
    end

    def bump_progress(count)
      sync_run.increment!(:synced_count, count)
    end

    def parse_time(value)
      Time.zone.parse(value.to_s)
    rescue ArgumentError
      nil
    end
  end
end
