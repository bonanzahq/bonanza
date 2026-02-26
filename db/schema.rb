# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_02_25_090730) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "accessories", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "name"
    t.bigint "parent_item_id", null: false
    t.datetime "updated_at", null: false
    t.index ["parent_item_id"], name: "index_accessories_on_parent_item_id"
  end

  create_table "accessories_line_items", id: false, force: :cascade do |t|
    t.bigint "accessory_id", null: false
    t.bigint "line_item_id", null: false
    t.index ["accessory_id", "line_item_id"], name: "index_accessories_line_items_on_accessory_id_and_line_item_id"
  end

  create_table "active_storage_attachments", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.bigint "record_id", null: false
    t.string "record_type", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.string "content_type"
    t.datetime "created_at", null: false
    t.string "filename", null: false
    t.string "key", null: false
    t.text "metadata"
    t.string "service_name", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "borrowers", force: :cascade do |t|
    t.integer "borrower_type", default: 0, null: false
    t.datetime "created_at", null: false
    t.string "email", null: false
    t.string "email_token"
    t.string "firstname", null: false
    t.boolean "id_checked", default: false, null: false
    t.boolean "insurance_checked", default: false, null: false
    t.string "lastname", null: false
    t.string "phone", null: false
    t.string "student_id"
    t.boolean "tos_accepted", default: false, null: false
    t.datetime "tos_accepted_at"
    t.datetime "updated_at", null: false
    t.index ["student_id"], name: "index_borrowers_unique_student_id", unique: true, where: "(student_id IS NOT NULL)"
  end

  create_table "conducts", force: :cascade do |t|
    t.bigint "borrower_id", null: false
    t.datetime "created_at", null: false
    t.bigint "department_id", null: false
    t.integer "duration"
    t.integer "kind"
    t.bigint "lending_id"
    t.datetime "lifted_at"
    t.bigint "lifted_by_id"
    t.boolean "permanent", default: false, null: false
    t.text "reason"
    t.datetime "updated_at", null: false
    t.bigint "user_id"
    t.index ["borrower_id", "department_id"], name: "index_conducts_unique_active_ban_per_department", unique: true, where: "((kind = 1) AND (lifted_at IS NULL))"
    t.index ["borrower_id"], name: "index_conducts_on_borrower_id"
    t.index ["department_id"], name: "index_conducts_on_department_id"
    t.index ["lending_id"], name: "index_conducts_on_lending_id"
    t.index ["user_id"], name: "index_conducts_on_user_id"
  end

  create_table "department_memberships", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "department_id"
    t.integer "role", default: 0, null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id"
    t.index ["department_id"], name: "index_department_memberships_on_department_id"
    t.index ["user_id"], name: "index_department_memberships_on_user_id"
  end

  create_table "departments", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "default_lending_duration"
    t.integer "genus", default: 0, null: false
    t.boolean "hidden", default: false, null: false
    t.string "name"
    t.text "note"
    t.string "room"
    t.boolean "staffed"
    t.datetime "staffed_at"
    t.string "time"
    t.datetime "updated_at", null: false
  end

  create_table "gdpr_audit_logs", force: :cascade do |t|
    t.string "action", null: false
    t.datetime "created_at", null: false
    t.jsonb "metadata", default: {}, null: false
    t.bigint "performed_by_id"
    t.string "performed_by_type"
    t.bigint "target_id", null: false
    t.string "target_type", null: false
    t.index ["action"], name: "index_gdpr_audit_logs_on_action"
    t.index ["performed_by_type", "performed_by_id"], name: "index_gdpr_audit_logs_on_performed_by"
    t.index ["target_type", "target_id"], name: "index_gdpr_audit_logs_on_target"
  end

  create_table "item_histories", force: :cascade do |t|
    t.integer "condition"
    t.datetime "created_at", null: false
    t.bigint "item_id", null: false
    t.bigint "line_item_id"
    t.text "note"
    t.integer "quantity"
    t.integer "status"
    t.datetime "updated_at", null: false
    t.bigint "user_id"
    t.index ["item_id"], name: "index_item_histories_on_item_id"
    t.index ["line_item_id"], name: "index_item_histories_on_line_item_id"
    t.index ["user_id"], name: "index_item_histories_on_user_id"
  end

  create_table "items", force: :cascade do |t|
    t.integer "condition", default: 0, null: false
    t.datetime "created_at", null: false
    t.integer "lending_counter", default: 0, null: false
    t.text "note"
    t.bigint "parent_item_id", null: false
    t.integer "quantity", default: 1
    t.integer "status", default: 0, null: false
    t.string "storage_location"
    t.string "uid"
    t.datetime "updated_at", null: false
    t.index ["parent_item_id"], name: "index_items_on_parent_item_id"
  end

  create_table "legal_texts", force: :cascade do |t|
    t.text "content", null: false
    t.datetime "created_at", null: false
    t.integer "kind", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["user_id"], name: "index_legal_texts_on_user_id"
  end

  create_table "lendings", force: :cascade do |t|
    t.bigint "borrower_id"
    t.datetime "created_at", null: false
    t.bigint "department_id"
    t.integer "duration"
    t.datetime "lent_at"
    t.text "note"
    t.integer "notification_counter"
    t.datetime "returned_at"
    t.integer "state", default: 0, null: false
    t.text "token"
    t.datetime "updated_at", null: false
    t.bigint "user_id"
    t.index ["borrower_id"], name: "index_lendings_on_borrower_id"
    t.index ["department_id"], name: "index_lendings_on_department_id"
    t.index ["user_id"], name: "index_lendings_on_user_id"
  end

  create_table "line_items", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "item_id"
    t.integer "lending_id"
    t.integer "quantity"
    t.datetime "returned_at"
    t.datetime "updated_at", null: false
  end

  create_table "parent_items", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "department_id", null: false
    t.text "description"
    t.string "name"
    t.string "price"
    t.datetime "updated_at", null: false
    t.index ["department_id"], name: "index_parent_items_on_department_id"
  end

  create_table "solid_queue_blocked_executions", force: :cascade do |t|
    t.string "concurrency_key", null: false
    t.datetime "created_at", null: false
    t.datetime "expires_at", null: false
    t.bigint "job_id", null: false
    t.integer "priority", default: 0, null: false
    t.string "queue_name", null: false
    t.index ["concurrency_key", "priority", "job_id"], name: "index_solid_queue_blocked_executions_for_release"
    t.index ["expires_at", "concurrency_key"], name: "index_solid_queue_blocked_executions_for_maintenance"
    t.index ["job_id"], name: "index_solid_queue_blocked_executions_on_job_id", unique: true
  end

  create_table "solid_queue_claimed_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "job_id", null: false
    t.bigint "process_id"
    t.index ["job_id"], name: "index_solid_queue_claimed_executions_on_job_id", unique: true
    t.index ["process_id", "job_id"], name: "index_solid_queue_claimed_executions_on_process_id_and_job_id"
  end

  create_table "solid_queue_failed_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "error"
    t.bigint "job_id", null: false
    t.index ["job_id"], name: "index_solid_queue_failed_executions_on_job_id", unique: true
  end

  create_table "solid_queue_jobs", force: :cascade do |t|
    t.string "active_job_id"
    t.text "arguments"
    t.string "class_name", null: false
    t.string "concurrency_key"
    t.datetime "created_at", null: false
    t.datetime "finished_at"
    t.integer "priority", default: 0, null: false
    t.string "queue_name", null: false
    t.datetime "scheduled_at"
    t.datetime "updated_at", null: false
    t.index ["active_job_id"], name: "index_solid_queue_jobs_on_active_job_id"
    t.index ["class_name"], name: "index_solid_queue_jobs_on_class_name"
    t.index ["finished_at"], name: "index_solid_queue_jobs_on_finished_at"
    t.index ["queue_name", "finished_at"], name: "index_solid_queue_jobs_for_filtering"
    t.index ["scheduled_at", "finished_at"], name: "index_solid_queue_jobs_for_alerting"
  end

  create_table "solid_queue_pauses", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "queue_name", null: false
    t.index ["queue_name"], name: "index_solid_queue_pauses_on_queue_name", unique: true
  end

  create_table "solid_queue_processes", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "hostname"
    t.string "kind", null: false
    t.datetime "last_heartbeat_at", null: false
    t.text "metadata"
    t.string "name", null: false
    t.integer "pid", null: false
    t.bigint "supervisor_id"
    t.index ["last_heartbeat_at"], name: "index_solid_queue_processes_on_last_heartbeat_at"
    t.index ["name", "supervisor_id"], name: "index_solid_queue_processes_on_name_and_supervisor_id", unique: true
    t.index ["supervisor_id"], name: "index_solid_queue_processes_on_supervisor_id"
  end

  create_table "solid_queue_ready_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "job_id", null: false
    t.integer "priority", default: 0, null: false
    t.string "queue_name", null: false
    t.index ["job_id"], name: "index_solid_queue_ready_executions_on_job_id", unique: true
    t.index ["priority", "job_id"], name: "index_solid_queue_poll_all"
    t.index ["queue_name", "priority", "job_id"], name: "index_solid_queue_poll_by_queue"
  end

  create_table "solid_queue_recurring_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "job_id", null: false
    t.datetime "run_at", null: false
    t.string "task_key", null: false
    t.index ["job_id"], name: "index_solid_queue_recurring_executions_on_job_id", unique: true
    t.index ["task_key", "run_at"], name: "index_solid_queue_recurring_executions_on_task_key_and_run_at", unique: true
  end

  create_table "solid_queue_recurring_tasks", force: :cascade do |t|
    t.text "arguments"
    t.string "class_name"
    t.string "command", limit: 2048
    t.datetime "created_at", null: false
    t.text "description"
    t.string "key", null: false
    t.integer "priority", default: 0
    t.string "queue_name"
    t.string "schedule", null: false
    t.boolean "static", default: true, null: false
    t.datetime "updated_at", null: false
    t.index ["key"], name: "index_solid_queue_recurring_tasks_on_key", unique: true
    t.index ["static"], name: "index_solid_queue_recurring_tasks_on_static"
  end

  create_table "solid_queue_scheduled_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "job_id", null: false
    t.integer "priority", default: 0, null: false
    t.string "queue_name", null: false
    t.datetime "scheduled_at", null: false
    t.index ["job_id"], name: "index_solid_queue_scheduled_executions_on_job_id", unique: true
    t.index ["scheduled_at", "priority", "job_id"], name: "index_solid_queue_dispatch_all"
  end

  create_table "solid_queue_semaphores", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "expires_at", null: false
    t.string "key", null: false
    t.datetime "updated_at", null: false
    t.integer "value", default: 1, null: false
    t.index ["expires_at"], name: "index_solid_queue_semaphores_on_expires_at"
    t.index ["key", "value"], name: "index_solid_queue_semaphores_on_key_and_value"
    t.index ["key"], name: "index_solid_queue_semaphores_on_key", unique: true
  end

  create_table "taggings", id: :serial, force: :cascade do |t|
    t.string "context", limit: 128
    t.datetime "created_at", precision: nil
    t.integer "tag_id"
    t.integer "taggable_id"
    t.string "taggable_type"
    t.integer "tagger_id"
    t.string "tagger_type"
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
    t.boolean "admin", default: false, null: false
    t.datetime "confirmation_sent_at"
    t.string "confirmation_token"
    t.datetime "confirmed_at"
    t.datetime "created_at", null: false
    t.integer "current_department_id"
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "firstname"
    t.datetime "invitation_accepted_at"
    t.datetime "invitation_created_at"
    t.integer "invitation_limit"
    t.datetime "invitation_sent_at"
    t.string "invitation_token"
    t.integer "invitations_count", default: 0
    t.bigint "invited_by_id"
    t.string "invited_by_type"
    t.string "lastname"
    t.datetime "remember_created_at"
    t.datetime "reset_password_sent_at"
    t.string "reset_password_token"
    t.string "unconfirmed_email"
    t.datetime "updated_at", null: false
    t.index ["confirmation_token"], name: "index_users_on_confirmation_token", unique: true
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
  add_foreign_key "conducts", "users", column: "lifted_by_id"
  add_foreign_key "item_histories", "items"
  add_foreign_key "item_histories", "line_items"
  add_foreign_key "item_histories", "users"
  add_foreign_key "legal_texts", "users"
  add_foreign_key "parent_items", "departments"
  add_foreign_key "solid_queue_blocked_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_claimed_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_failed_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_ready_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_recurring_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_scheduled_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "users", "departments", column: "current_department_id"
end
