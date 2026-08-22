class CreateSyncRuns < ActiveRecord::Migration[8.1]
  def change
    create_table :sync_runs do |t|
      t.string   :status, null: false, default: "pending"
      t.string   :stage
      t.integer  :synced_count, null: false, default: 0
      t.integer  :total_count
      t.datetime :started_at
      t.datetime :finished_at
      t.text     :error_message

      t.timestamps
    end

    add_index :sync_runs, :created_at
  end
end
