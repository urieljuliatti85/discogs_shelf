class CreateWantlistItems < ActiveRecord::Migration[8.1]
  def change
    create_table :wantlist_items do |t|
      t.references :release, null: false, foreign_key: true, index: { unique: true }
      t.integer :rating, default: 0
      t.text :notes
      t.datetime :date_added

      t.timestamps
    end

    add_index :wantlist_items, :date_added
  end
end
