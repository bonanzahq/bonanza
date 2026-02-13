# ABOUTME: Initial database schema for Bonanza Redux.
# ABOUTME: Created from schema.rb to ensure db:migrate works on a fresh database.

class InitialSchema < ActiveRecord::Migration[7.0]
  def change
    enable_extension "plpgsql"

    create_table "accessories", force: :cascade do |t|
      t.text "name"
      t.bigint "parent_item_id", null: false
      t.datetime "created_at", null: false
      t.datetime "updated_at", null: false
      t.index ["parent_item_id"], name: "index_accessories_on_parent_item_id"
    end

    create_table "accessories_line_items", id: false, force: :cascade do |t|
      t.bigint "accessory_id", null: false
      t.bigint "line_item_id", null: false
      t.index ["accessory_id", "line_item_id"], name: "index_accessories_line_items_on_accessory_id_and_line_item_id"
    end

    create_table "active_storage_attachments", force: :cascade do |t|
      t.string "name", null: false
      t.string "record_type", null: false
      t.bigint "record_id", null: false
      t.bigint "blob_id", null: false
      t.datetime "created_at", null: false
      t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
      t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
    end

    create_table "active_storage_blobs", force: :cascade do |t|
      t.string "key", null: false
      t.string "filename", null: false
      t.string "content_type"
      t.text "metadata"
      t.string "service_name", null: false
      t.bigint "byte_size", null: false
      t.string "checksum"
      t.datetime "created_at", null: false
      t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
    end

    create_table "active_storage_variant_records", force: :cascade do |t|
      t.bigint "blob_id", null: false
      t.string "variation_digest", null: false
      t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
    end

    create_table "borrowers", force: :cascade do |t|
      t.string "firstname", null: false
      t.string "lastname", null: false
      t.string "email", null: false
      t.string "phone", null: false
      t.integer "borrower_type", default: 0, null: false
      t.boolean "id_checked", default: false, null: false
      t.boolean "insurance_checked", default: false, null: false
      t.string "student_id"
      t.string "email_token"
      t.boolean "tos_accepted", default: false, null: false
      t.datetime "tos_accepted_at"
      t.datetime "created_at", null: false
      t.datetime "updated_at", null: false
    end

    create_table "conducts", force: :cascade do |t|
      t.integer "kind"
      t.bigint "borrower_id", null: false
      t.bigint "department_id", null: false
      t.bigint "user_id"
      t.text "reason"
      t.bigint "lending_id", null: false
      t.integer "duration"
      t.boolean "permanent", default: false, null: false
      t.datetime "created_at", null: false
      t.datetime "updated_at", null: false
      t.index ["borrower_id"], name: "index_conducts_on_borrower_id"
      t.index ["department_id"], name: "index_conducts_on_department_id"
      t.index ["lending_id"], name: "index_conducts_on_lending_id"
      t.index ["user_id"], name: "index_conducts_on_user_id"
    end

    create_table "department_memberships", force: :cascade do |t|
      t.integer "role", default: 0, null: false
      t.bigint "user_id"
      t.bigint "department_id"
      t.datetime "created_at", null: false
      t.datetime "updated_at", null: false
      t.index ["department_id"], name: "index_department_memberships_on_department_id"
      t.index ["user_id"], name: "index_department_memberships_on_user_id"
    end

    create_table "departments", force: :cascade do |t|
      t.string "name"
      t.string "room"
      t.text "note"
      t.string "time"
      t.integer "default_lending_duration"
      t.boolean "staffed"
      t.datetime "staffed_at"
      t.datetime "created_at", null: false
      t.datetime "updated_at", null: false
      t.boolean "hidden", default: false, null: false
      t.integer "genus", default: 0, null: false
    end

    create_table "item_histories", force: :cascade do |t|
      t.integer "quantity"
      t.text "note"
      t.integer "condition"
      t.integer "status"
      t.bigint "item_id", null: false
      t.bigint "user_id"
      t.bigint "line_item_id"
      t.datetime "created_at", null: false
      t.datetime "updated_at", null: false
      t.index ["item_id"], name: "index_item_histories_on_item_id"
      t.index ["line_item_id"], name: "index_item_histories_on_line_item_id"
      t.index ["user_id"], name: "index_item_histories_on_user_id"
    end

    create_table "items", force: :cascade do |t|
      t.string "uid"
      t.integer "quantity", default: 1
      t.integer "status", default: 0, null: false
      t.text "note"
      t.string "storage_location"
      t.bigint "parent_item_id", null: false
      t.datetime "created_at", null: false
      t.datetime "updated_at", null: false
      t.integer "lending_counter", default: 0, null: false
      t.integer "condition", default: 0, null: false
      t.index ["parent_item_id"], name: "index_items_on_parent_item_id"
    end

    create_table "legal_texts", force: :cascade do |t|
      t.text "content", null: false
      t.integer "kind", null: false
      t.bigint "user_id", null: false
      t.datetime "created_at", null: false
      t.datetime "updated_at", null: false
      t.index ["user_id"], name: "index_legal_texts_on_user_id"
    end

    create_table "lendings", force: :cascade do |t|
      t.bigint "borrower_id"
      t.datetime "lent_at"
      t.datetime "returned_at"
      t.text "note"
      t.integer "state", default: 0, null: false
      t.text "token"
      t.bigint "user_id"
      t.bigint "department_id"
      t.integer "duration"
      t.integer "notification_counter"
      t.datetime "created_at", null: false
      t.datetime "updated_at", null: false
      t.index ["borrower_id"], name: "index_lendings_on_borrower_id"
      t.index ["department_id"], name: "index_lendings_on_department_id"
      t.index ["user_id"], name: "index_lendings_on_user_id"
    end

    create_table "line_items", force: :cascade do |t|
      t.integer "item_id"
      t.integer "lending_id"
      t.integer "quantity"
      t.datetime "returned_at"
      t.datetime "created_at", null: false
      t.datetime "updated_at", null: false
    end

    create_table "parent_items", force: :cascade do |t|
      t.string "name"
      t.text "description"
      t.datetime "created_at", null: false
      t.datetime "updated_at", null: false
      t.integer "department_id", null: false
      t.string "price"
      t.index ["department_id"], name: "index_parent_items_on_department_id"
    end

    create_table "taggings", id: :serial, force: :cascade do |t|
      t.integer "tag_id"
      t.string "taggable_type"
      t.integer "taggable_id"
      t.string "tagger_type"
      t.integer "tagger_id"
      t.string "context", limit: 128
      t.datetime "created_at", precision: nil
      t.string "tenant", limit: 128
      t.index ["context"], name: "index_taggings_on_context"
      t.index ["tag_id", "taggable_id", "taggable_type", "context", "tagger_id", "tagger_type"], name: "taggings_idx", unique: true
      t.index ["tag_id"], name: "index_taggings_on_tag_id"
      t.index ["taggable_id", "taggable_type", "context"], name: "index_taggings_on_taggable_id_and_taggable_type_and_context"
      t.index ["taggable_id", "taggable_type", "tagger_id", "context"], name: "taggings_idy"
      t.index ["taggable_id"], name: "index_taggings_on_taggable_id"
      t.index ["taggable_type"], name: "index_taggings_on_taggable_type"
      t.index ["tagger_id", "tagger_type"], name: "index_taggings_on_tagger_id_and_tagger_type"
      t.index ["tagger_id"], name: "index_taggings_on_tagger_id"
      t.index ["tenant"], name: "index_taggings_on_tenant"
    end

    create_table "tags", id: :serial, force: :cascade do |t|
      t.string "name"
      t.integer "taggings_count", default: 0
      t.index ["name"], name: "index_tags_on_name", unique: true
    end

    create_table "users", force: :cascade do |t|
      t.string "email", default: "", null: false
      t.string "encrypted_password", default: "", null: false
      t.string "reset_password_token"
      t.datetime "reset_password_sent_at"
      t.datetime "remember_created_at"
      t.datetime "created_at", null: false
      t.datetime "updated_at", null: false
      t.integer "current_department_id"
      t.string "firstname"
      t.string "lastname"
      t.boolean "admin", default: false, null: false
      t.string "invitation_token"
      t.datetime "invitation_created_at"
      t.datetime "invitation_sent_at"
      t.datetime "invitation_accepted_at"
      t.integer "invitation_limit"
      t.string "invited_by_type"
      t.bigint "invited_by_id"
      t.integer "invitations_count", default: 0
      t.index ["current_department_id"], name: "index_users_on_current_department_id"
      t.index ["email"], name: "index_users_on_email", unique: true
      t.index ["invitation_token"], name: "index_users_on_invitation_token", unique: true
      t.index ["invited_by_id"], name: "index_users_on_invited_by_id"
      t.index ["invited_by_type", "invited_by_id"], name: "index_users_on_invited_by"
      t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
    end

    add_foreign_key "accessories", "parent_items"
    add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
    add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
    add_foreign_key "conducts", "borrowers"
    add_foreign_key "conducts", "departments"
    add_foreign_key "conducts", "lendings"
    add_foreign_key "conducts", "users"
    add_foreign_key "item_histories", "items"
    add_foreign_key "item_histories", "line_items"
    add_foreign_key "item_histories", "users"
    add_foreign_key "legal_texts", "users"
    add_foreign_key "parent_items", "departments"
    add_foreign_key "users", "departments", column: "current_department_id"
  end
end
