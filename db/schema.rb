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

ActiveRecord::Schema[8.0].define(version: 2025_11_26_025336) do
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

  create_table "activities", force: :cascade do |t|
    t.integer "performance_id", null: false
    t.float "value"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "start_frame"
    t.integer "end_frame"
    t.index ["performance_id"], name: "index_activities_on_performance_id"
  end

  create_table "detections", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "frame_number"
    t.float "x1"
    t.float "y1"
    t.float "x2"
    t.float "y2"
    t.integer "video_id", null: false
    t.float "activity"
    t.integer "person_id"
    t.index ["person_id"], name: "index_detections_on_person_id"
    t.index ["video_id", "person_id"], name: "index_detections_on_video_id_and_person_id"
    t.index ["video_id"], name: "index_detections_on_video_id"
  end

  create_table "performances", force: :cascade do |t|
    t.string "date"
    t.integer "performer_id", null: false
    t.integer "video_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "person_id"
    t.float "reference_bbox_height"
    t.datetime "reference_bbox_updated_at"
    t.index ["performer_id"], name: "index_performances_on_performer_id"
    t.index ["video_id", "person_id"], name: "index_performances_on_video_id_and_person_id", unique: true
    t.index ["video_id"], name: "index_performances_on_video_id"
  end

  create_table "performers", force: :cascade do |t|
    t.integer "num"
    t.string "name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.float "reference_bbox_height"
    t.float "height"
  end

  create_table "videos", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "title"
    t.string "analysis_status", default: "pending"
    t.date "date"
    t.index ["analysis_status"], name: "index_videos_on_analysis_status"
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "activities", "performances"
  add_foreign_key "detections", "videos"
  add_foreign_key "performances", "performers"
  add_foreign_key "performances", "videos"
end
