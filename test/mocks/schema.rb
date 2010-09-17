ActiveRecord::Schema.define do

  create_table "bills", :force => true do |t|
    t.string   "state"
    t.text     "contents"
    t.integer  "locked_by_user_id"
  end

  create_table "users", :force => true do |t|
    t.string   "username"
    t.string   "user_type"
  end

end