require 'active_record'

class StopTime < ActiveRecord::Base
  
end

class Trip < ActiveRecord::Base

end

ActiveRecord::Base.establish_connection(
  :adapter => 'sqlite3',
  :database => 'data/processed.sqlite3'
)

unless StopTime.table_exists?
  ActiveRecord::Schema.define(:version => 201112200430) do
    create_table :stop_times do |t|
      t.column :trip_id, :string
      t.column :arrival_time, :string
      t.column :departure_time, :string
      t.column :stop_id, :string
      t.column :stop_sequence, :integer
      t.column :pickup_type, :integer
      t.column :drop_off_type, :integer
    end
  
    add_index :stop_times, :stop_id, :unique => false
  end
end

unless Trip.table_exists?
  ActiveRecord::Schema.define(:version => 201205011152) do
    create_table :trips do |t|
      t.column :route_id, :string
      t.column :service_id, :string
      t.column :trip_id, :string, :primary => true
      t.column :trip_headsign, :string
      t.column :block_id, :integer
    end
  end
end