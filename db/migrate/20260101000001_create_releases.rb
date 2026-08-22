class CreateReleases < ActiveRecord::Migration[8.1]
  def change
    create_table :releases do |t|
      t.integer :discogs_id, null: false
      t.string  :title, null: false
      t.string  :artist, null: false
      t.integer :year
      t.string  :thumb_url
      t.string  :cover_url
      t.string  :country
      t.string  :catno
      t.string  :label
      t.string  :resource_url
      t.json    :formats,     default: []
      t.json    :genres,      default: []
      t.json    :styles,      default: []
      t.json    :labels,      default: []
      t.json    :artists,     default: []
      t.json    :details              # lazily fetched full release (tracklist, videos, notes)
      t.datetime :details_fetched_at

      t.timestamps
    end

    add_index :releases, :discogs_id, unique: true
    add_index :releases, :artist
    add_index :releases, :year
  end
end
