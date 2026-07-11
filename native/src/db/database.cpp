#include "database.h"
#include <filesystem>
#include <fstream>
#include <chrono>
#include <random>
#include <sstream>
#include <algorithm>
#include <set>
#include <cstring>

namespace fs = std::filesystem;
using namespace amkb::db;

namespace {
std::string generate_uuid() {
    static std::random_device rd;
    static std::mt19937 gen(rd());
    static std::uniform_int_distribution<uint32_t> dist(0, 0xFFFFFFFF);
    uint32_t d[4];
    for (int i = 0; i < 4; i++) d[i] = dist(gen);
    char buf[37];
    snprintf(buf, sizeof(buf), "%08x-%04x-%04x-%04x-%04x%08x",
        d[0], (d[1]>>16)&0xFFFF, (d[1]&0xFFFF)|0x4000,
        (d[2]>>16)|0x8000, d[2]&0xFFFF, d[3]);
    return std::string(buf);
}
int64_t current_timestamp_ms() {
    return std::chrono::duration_cast<std::chrono::milliseconds>(
        std::chrono::system_clock::now().time_since_epoch()).count();
}
std::string to_lower(const std::string& s) {
    std::string r = s; std::transform(r.begin(),r.end(),r.begin(),::tolower); return r;
}
std::string get_extension(const std::string& p) {
    auto pos = p.rfind('.'); return pos==std::string::npos?"":to_lower(p.substr(pos+1));
}
std::string detect_media_type(const std::string& ext) {
    if(ext=="jpg"||ext=="jpeg"||ext=="png"||ext=="gif"||ext=="bmp"||ext=="webp"||ext=="svg") return "image";
    if(ext=="mp4"||ext=="avi"||ext=="mkv"||ext=="mov"||ext=="webm") return "video";
    if(ext=="mp3"||ext=="wav"||ext=="flac"||ext=="aac"||ext=="ogg") return "audio";
    if(ext=="pdf"||ext=="doc"||ext=="docx"||ext=="txt"||ext=="md") return "document";
    return "other";
}
std::string detect_mime_type(const std::string& ext) {
    if(ext=="jpg"||ext=="jpeg") return "image/jpeg";
    if(ext=="png") return "image/png";
    if(ext=="gif") return "image/gif";
    if(ext=="mp4") return "video/mp4";
    if(ext=="mp3") return "audio/mpeg";
    if(ext=="pdf") return "application/pdf";
    if(ext=="txt") return "text/plain";
    return "application/octet-stream";
}
void bind_text(sqlite3_stmt* s, int i, const std::string& v) { sqlite3_bind_text(s,i,v.c_str(),-1,SQLITE_TRANSIENT); }
void bind_opt_text(sqlite3_stmt* s, int i, const std::optional<std::string>& v) {
    if(v.has_value()) bind_text(s,i,v.value()); else sqlite3_bind_null(s,i);
}
} // anon

Database& Database::instance() { static Database db; return db; }
Database::~Database() { if(db_){sqlite3_close(db_);db_=nullptr;} }
bool Database::is_initialized() const { return db_!=nullptr; }

int Database::init(const std::string& app_dir) {
    std::lock_guard<std::mutex> lock(mutex_);
    app_dir_ = app_dir;
    fs::create_directories(app_dir);
    fs::create_directories(app_dir + "/media");
    fs::create_directories(app_dir + "/media/thumbnails");
    std::string db_path = app_dir + "/advance_media_kb.db";
    int rc = sqlite3_open(db_path.c_str(), &db_);
    if (rc != SQLITE_OK) return rc;
    sqlite3_exec(db_, "PRAGMA foreign_keys = ON", nullptr, nullptr, nullptr);
    return create_tables();
}

int Database::create_tables() {
    const char* sql = R"SQL(
        CREATE TABLE IF NOT EXISTS albums (id TEXT PRIMARY KEY, name TEXT NOT NULL, parent_id TEXT, cover_media_id TEXT, sort_order INTEGER NOT NULL DEFAULT 0, created_at INTEGER NOT NULL, FOREIGN KEY (parent_id) REFERENCES albums(id) ON DELETE CASCADE, FOREIGN KEY (cover_media_id) REFERENCES media_items(id) ON DELETE SET NULL);
        CREATE TABLE IF NOT EXISTS media_items (id TEXT PRIMARY KEY, original_name TEXT NOT NULL, storage_name TEXT NOT NULL, file_path TEXT NOT NULL, thumbnail_path TEXT NOT NULL, type TEXT NOT NULL, mime_type TEXT NOT NULL, size INTEGER NOT NULL, width INTEGER, height INTEGER, duration INTEGER, sha256_hash TEXT NOT NULL, created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL);
        CREATE TABLE IF NOT EXISTS notes (id TEXT PRIMARY KEY, media_id TEXT NOT NULL, content TEXT NOT NULL DEFAULT '', created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL, FOREIGN KEY (media_id) REFERENCES media_items(id) ON DELETE CASCADE);
        CREATE UNIQUE INDEX IF NOT EXISTS idx_notes_media_id_unique ON notes(media_id);
        CREATE TABLE IF NOT EXISTS tags (id TEXT PRIMARY KEY, name TEXT NOT NULL, color TEXT, parent_id TEXT, created_at INTEGER NOT NULL, FOREIGN KEY (parent_id) REFERENCES tags(id) ON DELETE CASCADE);
        CREATE TABLE IF NOT EXISTS album_media (album_id TEXT NOT NULL, media_id TEXT NOT NULL, added_at INTEGER NOT NULL, PRIMARY KEY (album_id, media_id), FOREIGN KEY (album_id) REFERENCES albums(id) ON DELETE CASCADE, FOREIGN KEY (media_id) REFERENCES media_items(id) ON DELETE CASCADE);
        CREATE TABLE IF NOT EXISTS media_tags (media_id TEXT NOT NULL, tag_id TEXT NOT NULL, created_at INTEGER NOT NULL, PRIMARY KEY (media_id, tag_id), FOREIGN KEY (media_id) REFERENCES media_items(id) ON DELETE CASCADE, FOREIGN KEY (tag_id) REFERENCES tags(id) ON DELETE CASCADE);
        CREATE TABLE IF NOT EXISTS app_settings (id INTEGER PRIMARY KEY CHECK (id = 1), theme_mode INTEGER NOT NULL DEFAULT 0, grid_columns INTEGER NOT NULL DEFAULT 3, album_grid_columns INTEGER NOT NULL DEFAULT 2, thumbnail_quality INTEGER NOT NULL DEFAULT 85, language TEXT NOT NULL DEFAULT 'system', dynamic_color INTEGER NOT NULL DEFAULT 1, last_scan_path TEXT NOT NULL DEFAULT '');
        CREATE INDEX IF NOT EXISTS idx_media_created_at ON media_items(created_at);
        CREATE INDEX IF NOT EXISTS idx_media_type ON media_items(type);
        CREATE UNIQUE INDEX IF NOT EXISTS idx_media_sha256 ON media_items(sha256_hash);
        CREATE INDEX IF NOT EXISTS idx_albums_parent_id ON albums(parent_id);
        CREATE INDEX IF NOT EXISTS idx_tags_parent_id ON tags(parent_id);
        CREATE INDEX IF NOT EXISTS idx_notes_media_id ON notes(media_id);
        INSERT OR IGNORE INTO app_settings (id, theme_mode, grid_columns, album_grid_columns, thumbnail_quality, language, dynamic_color) VALUES (1, 0, 3, 2, 85, 'zh', 1);
    )SQL";
    char* err = nullptr;
    int rc = sqlite3_exec(db_, sql, nullptr, nullptr, &err);
    if (rc != SQLITE_OK) { if(err) sqlite3_free(err); return rc; }
    sqlite3_exec(db_, "ALTER TABLE app_settings ADD COLUMN dynamic_color INTEGER NOT NULL DEFAULT 1", nullptr, nullptr, nullptr);
    sqlite3_exec(db_, "ALTER TABLE app_settings ADD COLUMN last_scan_path TEXT NOT NULL DEFAULT ''", nullptr, nullptr, nullptr);
    return SQLITE_OK;
}

MediaItem Database::row_to_media_item(sqlite3_stmt* s) {
    MediaItem m;
    m.id=reinterpret_cast<const char*>(sqlite3_column_text(s,0));
    m.original_name=reinterpret_cast<const char*>(sqlite3_column_text(s,1));
    m.storage_name=reinterpret_cast<const char*>(sqlite3_column_text(s,2));
    m.file_path=reinterpret_cast<const char*>(sqlite3_column_text(s,3));
    m.thumbnail_path=reinterpret_cast<const char*>(sqlite3_column_text(s,4));
    m.media_type=reinterpret_cast<const char*>(sqlite3_column_text(s,5));
    m.mime_type=reinterpret_cast<const char*>(sqlite3_column_text(s,6));
    m.size=sqlite3_column_int64(s,7);
    if(sqlite3_column_type(s,8)!=SQLITE_NULL) m.width=sqlite3_column_int(s,8);
    if(sqlite3_column_type(s,9)!=SQLITE_NULL) m.height=sqlite3_column_int(s,9);
    if(sqlite3_column_type(s,10)!=SQLITE_NULL) m.duration=sqlite3_column_int64(s,10);
    m.sha256_hash=reinterpret_cast<const char*>(sqlite3_column_text(s,11));
    m.created_at=sqlite3_column_int64(s,12);
    m.updated_at=sqlite3_column_int64(s,13);
    return m;
}
Album Database::row_to_album(sqlite3_stmt* s) {
    Album a;
    a.id=reinterpret_cast<const char*>(sqlite3_column_text(s,0));
    a.name=reinterpret_cast<const char*>(sqlite3_column_text(s,1));
    if(sqlite3_column_type(s,2)!=SQLITE_NULL) a.parent_id=reinterpret_cast<const char*>(sqlite3_column_text(s,2));
    if(sqlite3_column_type(s,3)!=SQLITE_NULL) a.cover_media_id=reinterpret_cast<const char*>(sqlite3_column_text(s,3));
    a.sort_order=sqlite3_column_int(s,4);
    a.created_at=sqlite3_column_int64(s,5);
    return a;
}
Tag Database::row_to_tag(sqlite3_stmt* s) {
    Tag t;
    t.id=reinterpret_cast<const char*>(sqlite3_column_text(s,0));
    t.name=reinterpret_cast<const char*>(sqlite3_column_text(s,1));
    if(sqlite3_column_type(s,2)!=SQLITE_NULL) t.color=reinterpret_cast<const char*>(sqlite3_column_text(s,2));
    if(sqlite3_column_type(s,3)!=SQLITE_NULL) t.parent_id=reinterpret_cast<const char*>(sqlite3_column_text(s,3));
    t.created_at=sqlite3_column_int64(s,4);
    return t;
}
Note Database::row_to_note(sqlite3_stmt* s) {
    Note n;
    n.id=reinterpret_cast<const char*>(sqlite3_column_text(s,0));
    n.media_id=reinterpret_cast<const char*>(sqlite3_column_text(s,1));
    n.content=reinterpret_cast<const char*>(sqlite3_column_text(s,2));
    n.created_at=sqlite3_column_int64(s,3);
    n.updated_at=sqlite3_column_int64(s,4);
    return n;
}

// ===== Settings =====
AppSettings Database::get_settings() {
    std::lock_guard<std::mutex> lock(mutex_);
    AppSettings s;
    sqlite3_stmt* stmt;
    sqlite3_prepare_v2(db_, "SELECT * FROM app_settings WHERE id = 1", -1, &stmt, nullptr);
    if (sqlite3_step(stmt) == SQLITE_ROW) {
        s.theme_mode=sqlite3_column_int(stmt,1); s.grid_columns=sqlite3_column_int(stmt,2);
        s.album_grid_columns=sqlite3_column_int(stmt,3); s.thumbnail_quality=sqlite3_column_int(stmt,4);
        s.language=reinterpret_cast<const char*>(sqlite3_column_text(stmt,5));
        s.dynamic_color=sqlite3_column_int(stmt,6);
        s.last_scan_path=reinterpret_cast<const char*>(sqlite3_column_text(stmt,7));
    }
    sqlite3_finalize(stmt);
    return s;
}
int Database::save_settings(const AppSettings& s) {
    std::lock_guard<std::mutex> lock(mutex_);
    sqlite3_stmt* stmt;
    sqlite3_prepare_v2(db_,"INSERT INTO app_settings(id,theme_mode,grid_columns,album_grid_columns,thumbnail_quality,language,dynamic_color,last_scan_path) VALUES(1?,?,?,?,?,?,?,?) ON CONFLICT(id) DO UPDATE SET theme_mode=excluded.theme_mode,grid_columns=excluded.grid_columns,album_grid_columns=excluded.album_grid_columns,thumbnail_quality=excluded.thumbnail_quality,language=excluded.language,dynamic_color=excluded.dynamic_color,last_scan_path=excluded.last_scan_path",-1,&stmt,nullptr);
    sqlite3_bind_int(stmt,1,s.theme_mode); sqlite3_bind_int(stmt,2,s.grid_columns);
    sqlite3_bind_int(stmt,3,s.album_grid_columns); sqlite3_bind_int(stmt,4,s.thumbnail_quality);
    bind_text(stmt,5,s.language); sqlite3_bind_int(stmt,6,s.dynamic_color); bind_text(stmt,7,s.last_scan_path);
    int rc=sqlite3_step(stmt); sqlite3_finalize(stmt); return rc;
}
StorageStats Database::get_storage_stats() {
    std::lock_guard<std::mutex> lock(mutex_);
    StorageStats st;
    sqlite3_stmt* stmt;
    sqlite3_prepare_v2(db_,"SELECT COUNT(*),COALESCE(SUM(size),0) FROM media_items",-1,&stmt,nullptr);
    if(sqlite3_step(stmt)==SQLITE_ROW){st.total_media_count=sqlite3_column_int(stmt,0);st.total_size=sqlite3_column_int64(stmt,1);}
    sqlite3_finalize(stmt);
    std::string dbp=app_dir_+"/advance_media_kb.db";
    if(fs::exists(dbp)) st.database_size=fs::file_size(dbp);
    std::string td=app_dir_+"/media/thumbnails";
    if(fs::exists(td)) for(auto& e:fs::directory_iterator(td)) if(e.is_regular_file()) st.thumbnail_cache_size+=e.file_size();
    return st;
}
int Database::clear_thumbnail_cache() {
    std::lock_guard<std::mutex> lock(mutex_);
    std::set<std::string> vp;
    sqlite3_stmt* stmt;
    sqlite3_prepare_v2(db_,"SELECT thumbnail_path FROM media_items WHERE thumbnail_path!=''",-1,&stmt,nullptr);
    while(sqlite3_step(stmt)==SQLITE_ROW) vp.insert(reinterpret_cast<const char*>(sqlite3_column_text(stmt,0)));
    sqlite3_finalize(stmt);
    int d=0; std::string td=app_dir_+"/media/thumbnails";
    if(fs::exists(td)) for(auto& e:fs::directory_iterator(td)) if(e.is_regular_file()&&vp.find(e.path().string())==vp.end()){fs::remove(e.path());d++;}
    return d;
}
int Database::export_data(const std::string& p) {
    std::lock_guard<std::mutex> lock(mutex_);
    char* err=nullptr; int rc=sqlite3_exec(db_,("VACUUM INTO '"+p+"'").c_str(),nullptr,nullptr,&err);
    if(err) sqlite3_free(err); return rc;
}
int Database::import_data(const std::string& p) {
    std::lock_guard<std::mutex> lock(mutex_);
    if(!fs::exists(p)) return -1;
    std::string dp=app_dir_+"/advance_media_kb.db", bp=dp+".backup";
    fs::copy_file(dp,bp,fs::copy_options::overwrite_existing);
    sqlite3_close(db_); db_=nullptr;
    try{fs::copy_file(p,dp,fs::copy_options::overwrite_existing);}catch(...){fs::copy_file(bp,dp,fs::copy_options::overwrite_existing);fs::remove(bp);sqlite3_open(dp.c_str(),&db_);return -1;}
    fs::remove(bp); sqlite3_open(dp.c_str(),&db_); sqlite3_exec(db_,"PRAGMA foreign_keys=ON",nullptr,nullptr,nullptr);
    return SQLITE_OK;
}
int Database::delete_all_data() {
    std::lock_guard<std::mutex> lock(mutex_);
    char* err=nullptr;
    int rc=sqlite3_exec(db_,"DELETE FROM media_tags;DELETE FROM album_media;DELETE FROM notes;DELETE FROM media_items;DELETE FROM albums;DELETE FROM tags;UPDATE app_settings SET theme_mode=0,grid_columns=3,album_grid_columns=2,thumbnail_quality=85,language='system',last_scan_path='' WHERE id=1;",nullptr,nullptr,&err);
    if(err) sqlite3_free(err); return rc;
}
std::vector<std::string> Database::find_unreferenced_files() {
    std::lock_guard<std::mutex> lock(mutex_);
    std::vector<std::string> r; std::set<std::string> vp;
    sqlite3_stmt* stmt;
    sqlite3_prepare_v2(db_,"SELECT file_path FROM media_items",-1,&stmt,nullptr);
    while(sqlite3_step(stmt)==SQLITE_ROW) vp.insert(reinterpret_cast<const char*>(sqlite3_column_text(stmt,0)));
    sqlite3_finalize(stmt);
    std::string md=app_dir_+"/media"; if(!fs::exists(md)) return r;
    for(auto& e:fs::directory_iterator(md)) if(e.is_regular_file()){auto s=e.path().string(); if(s.find("thumbnails")!=std::string::npos) continue; if(vp.find(s)==vp.end()) r.push_back(s);}
    return r;
}
int Database::delete_unreferenced_files() { auto f=find_unreferenced_files(); int c=0; for(auto& x:f) if(fs::remove(x)) c++; return c; }

// ===== Media =====
std::vector<MediaItem> Database::get_all_media() {
    std::lock_guard<std::mutex> lock(mutex_); std::vector<MediaItem> r;
    sqlite3_stmt* s; sqlite3_prepare_v2(db_,"SELECT * FROM media_items ORDER BY created_at DESC",-1,&s,nullptr);
    while(sqlite3_step(s)==SQLITE_ROW) r.push_back(row_to_media_item(s));
    sqlite3_finalize(s); return r;
}
std::vector<MediaItem> Database::search_media(const std::string& q) {
    std::lock_guard<std::mutex> lock(mutex_); std::vector<MediaItem> r;
    sqlite3_stmt* s; sqlite3_prepare_v2(db_,"SELECT * FROM media_items WHERE original_name LIKE ? ORDER BY created_at DESC",-1,&s,nullptr);
    bind_text(s,1,"%"+q+"%");
    while(sqlite3_step(s)==SQLITE_ROW) r.push_back(row_to_media_item(s));
    sqlite3_finalize(s); return r;
}
std::vector<MediaItem> Database::filter_media_by_type(const std::string& t) {
    std::lock_guard<std::mutex> lock(mutex_); std::vector<MediaItem> r;
    sqlite3_stmt* s; sqlite3_prepare_v2(db_,"SELECT * FROM media_items WHERE type=? ORDER BY created_at DESC",-1,&s,nullptr);
    bind_text(s,1,t);
    while(sqlite3_step(s)==SQLITE_ROW) r.push_back(row_to_media_item(s));
    sqlite3_finalize(s); return r;
}
std::optional<MediaItem> Database::get_media_by_id(const std::string& id) {
    std::lock_guard<std::mutex> lock(mutex_);
    sqlite3_stmt* s; sqlite3_prepare_v2(db_,"SELECT * FROM media_items WHERE id=?",-1,&s,nullptr); bind_text(s,1,id);
    std::optional<MediaItem> r; if(sqlite3_step(s)==SQLITE_ROW) r=row_to_media_item(s);
    sqlite3_finalize(s); return r;
}
int Database::delete_media(const std::string& id) {
    std::lock_guard<std::mutex> lock(mutex_);
    sqlite3_stmt* s; sqlite3_prepare_v2(db_,"DELETE FROM media_items WHERE id=?",-1,&s,nullptr); bind_text(s,1,id);
    int rc=sqlite3_step(s); sqlite3_finalize(s); return rc;
}
int Database::update_media(const MediaItem& m) {
    std::lock_guard<std::mutex> lock(mutex_);
    sqlite3_stmt* s; sqlite3_prepare_v2(db_,"UPDATE media_items SET original_name=?,thumbnail_path=?,size=?,width=?,height=?,updated_at=? WHERE id=?",-1,&s,nullptr);
    bind_text(s,1,m.original_name); bind_text(s,2,m.thumbnail_path); sqlite3_bind_int64(s,3,m.size);
    if(m.width) sqlite3_bind_int(s,4,*m.width); else sqlite3_bind_null(s,4);
    if(m.height) sqlite3_bind_int(s,5,*m.height); else sqlite3_bind_null(s,5);
    sqlite3_bind_int64(s,6,current_timestamp_ms()); bind_text(s,7,m.id);
    int rc=sqlite3_step(s); sqlite3_finalize(s); return rc;
}
int Database::import_media(const std::string& fp, const std::string& ad) {
    if(!fs::exists(fp)) return -1;
    std::string ext=get_extension(fp), mt=detect_media_type(ext), mime=detect_mime_type(ext);
    auto now=current_timestamp_ms();
    std::string id=generate_uuid(), on=fs::path(fp).filename().string(), sn=generate_uuid()+"."+ext;
    std::string dp=ad+"/media/"+sn, tp=ad+"/media/thumbnails/"+generate_uuid()+".jpg";
    fs::copy_file(fp,dp);
    {std::ofstream th(tp); th<<"";}
    std::lock_guard<std::mutex> lock(mutex_);
    sqlite3_stmt* s; sqlite3_prepare_v2(db_,"INSERT INTO media_items(id,original_name,storage_name,file_path,thumbnail_path,type,mime_type,size,sha256_hash,created_at,updated_at) VALUES(?,?,?,?,?,?,?,?,?,?,?)",-1,&s,nullptr);
    bind_text(s,1,id); bind_text(s,2,on); bind_text(s,3,sn); bind_text(s,4,dp); bind_text(s,5,tp);
    bind_text(s,6,mt); bind_text(s,7,mime); sqlite3_bind_int64(s,8,(int64_t)fs::file_size(fp));
    bind_text(s,9,"hash_"+id); sqlite3_bind_int64(s,10,now); sqlite3_bind_int64(s,11,now);
    int rc=sqlite3_step(s); sqlite3_finalize(s); return rc;
}
std::vector<MediaItem> Database::get_adjacent_media(const std::string& id) {
    std::lock_guard<std::mutex> lock(mutex_); std::vector<MediaItem> r;
    sqlite3_stmt* s;
    sqlite3_prepare_v2(db_,"SELECT * FROM media_items WHERE created_at<(SELECT created_at FROM media_items WHERE id=?) ORDER BY created_at DESC LIMIT 1",-1,&s,nullptr);
    bind_text(s,1,id); if(sqlite3_step(s)==SQLITE_ROW) r.push_back(row_to_media_item(s)); sqlite3_finalize(s);
    sqlite3_prepare_v2(db_,"SELECT * FROM media_items WHERE created_at>(SELECT created_at FROM media_items WHERE id=?) ORDER BY created_at ASC LIMIT 1",-1,&s,nullptr);
    bind_text(s,1,id); if(sqlite3_step(s)==SQLITE_ROW) r.push_back(row_to_media_item(s)); sqlite3_finalize(s);
    return r;
}
std::vector<MediaItem> Database::get_media_by_filter(const std::string& f) {
    if(f=="image") return filter_media_by_type("image"); if(f=="video") return filter_media_by_type("video");
    if(f=="audio") return filter_media_by_type("audio"); if(f=="document") return filter_media_by_type("document");
    if(f=="other") return filter_media_by_type("other"); return get_all_media();
}

// ===== Albums =====
std::vector<AlbumWithInfo> Database::get_root_albums() {
    std::lock_guard<std::mutex> lock(mutex_); std::vector<AlbumWithInfo> r;
    sqlite3_stmt* s;
    sqlite3_prepare_v2(db_,"SELECT a.*,(SELECT COUNT(*) FROM album_media WHERE album_id=a.id),(SELECT thumbnail_path FROM media_items WHERE id=a.cover_media_id) FROM albums a WHERE a.parent_id IS NULL ORDER BY a.sort_order,a.created_at DESC",-1,&s,nullptr);
    while(sqlite3_step(s)==SQLITE_ROW){AlbumWithInfo i;i.album=row_to_album(s);i.media_count=sqlite3_column_int(s,6);if(sqlite3_column_type(s,7)!=SQLITE_NULL)i.cover_path=reinterpret_cast<const char*>(sqlite3_column_text(s,7));r.push_back(i);}
    sqlite3_finalize(s); return r;
}
std::vector<AlbumWithInfo> Database::get_child_albums(const std::string& pid) {
    std::lock_guard<std::mutex> lock(mutex_); std::vector<AlbumWithInfo> r;
    sqlite3_stmt* s;
    sqlite3_prepare_v2(db_,"SELECT a.*,(SELECT COUNT(*) FROM album_media WHERE album_id=a.id),(SELECT thumbnail_path FROM media_items WHERE id=a.cover_media_id) FROM albums a WHERE a.parent_id=? ORDER BY a.sort_order,a.created_at DESC",-1,&s,nullptr);
    bind_text(s,1,pid);
    while(sqlite3_step(s)==SQLITE_ROW){AlbumWithInfo i;i.album=row_to_album(s);i.media_count=sqlite3_column_int(s,6);if(sqlite3_column_type(s,7)!=SQLITE_NULL)i.cover_path=reinterpret_cast<const char*>(sqlite3_column_text(s,7));r.push_back(i);}
    sqlite3_finalize(s); return r;
}
std::string Database::create_album(const std::string& n, const std::optional<std::string>& pid) {
    std::lock_guard<std::mutex> lock(mutex_); std::string id=generate_uuid();
    sqlite3_stmt* s; sqlite3_prepare_v2(db_,"INSERT INTO albums(id,name,parent_id,created_at) VALUES(?,?,?,?)",-1,&s,nullptr);
    bind_text(s,1,id); bind_text(s,2,n); bind_opt_text(s,3,pid); sqlite3_bind_int64(s,4,current_timestamp_ms());
    sqlite3_step(s); sqlite3_finalize(s); return id;
}
int Database::delete_album(const std::string& id) {
    std::lock_guard<std::mutex> lock(mutex_);
    sqlite3_stmt* s; sqlite3_prepare_v2(db_,"DELETE FROM albums WHERE id=?",-1,&s,nullptr); bind_text(s,1,id);
    int rc=sqlite3_step(s); sqlite3_finalize(s); return rc;
}
int Database::rename_album(const std::string& id, const std::string& n) {
    std::lock_guard<std::mutex> lock(mutex_);
    sqlite3_stmt* s; sqlite3_prepare_v2(db_,"UPDATE albums SET name=? WHERE id=?",-1,&s,nullptr); bind_text(s,1,n); bind_text(s,2,id);
    int rc=sqlite3_step(s); sqlite3_finalize(s); return rc;
}
int Database::add_media_to_album(const std::vector<std::string>& mids, const std::string& aid) {
    std::lock_guard<std::mutex> lock(mutex_);
    sqlite3_stmt* s; sqlite3_prepare_v2(db_,"INSERT OR IGNORE INTO album_media(album_id,media_id,added_at) VALUES(?,?,?)",-1,&s,nullptr);
    for(auto& m:mids){sqlite3_reset(s);bind_text(s,1,aid);bind_text(s,2,m);sqlite3_bind_int64(s,3,current_timestamp_ms());sqlite3_step(s);}
    sqlite3_finalize(s); return 0;
}
int Database::remove_media_from_album(const std::vector<std::string>& mids, const std::string& aid) {
    std::lock_guard<std::mutex> lock(mutex_);
    sqlite3_stmt* s; sqlite3_prepare_v2(db_,"DELETE FROM album_media WHERE album_id=? AND media_id=?",-1,&s,nullptr);
    for(auto& m:mids){sqlite3_reset(s);bind_text(s,1,aid);bind_text(s,2,m);sqlite3_step(s);}
    sqlite3_finalize(s); return 0;
}
int Database::set_album_cover(const std::string& aid, const std::string& mid) {
    std::lock_guard<std::mutex> lock(mutex_);
    sqlite3_stmt* s; sqlite3_prepare_v2(db_,"UPDATE albums SET cover_media_id=? WHERE id=?",-1,&s,nullptr); bind_text(s,1,mid); bind_text(s,2,aid);
    int rc=sqlite3_step(s); sqlite3_finalize(s); return rc;
}
std::vector<BreadcrumbItem> Database::get_album_breadcrumb(const std::string& aid) {
    std::lock_guard<std::mutex> lock(mutex_); std::vector<BreadcrumbItem> r; std::string cur=aid;
    while(!cur.empty()){sqlite3_stmt* s;sqlite3_prepare_v2(db_,"SELECT id,name,parent_id FROM albums WHERE id=?",-1,&s,nullptr);bind_text(s,1,cur);
    if(sqlite3_step(s)==SQLITE_ROW){BreadcrumbItem i;i.id=reinterpret_cast<const char*>(sqlite3_column_text(s,0));i.name=reinterpret_cast<const char*>(sqlite3_column_text(s,1));r.insert(r.begin(),i);cur=sqlite3_column_type(s,2)!=SQLITE_NULL?reinterpret_cast<const char*>(sqlite3_column_text(s,2)):std::string();}else cur.clear();sqlite3_finalize(s);}
    return r;
}
std::vector<MediaItem> Database::get_media_by_album(const std::string& aid) {
    std::lock_guard<std::mutex> lock(mutex_); std::vector<MediaItem> r;
    sqlite3_stmt* s; sqlite3_prepare_v2(db_,"SELECT m.* FROM media_items m JOIN album_media am ON m.id=am.media_id WHERE am.album_id=? ORDER BY am.added_at DESC",-1,&s,nullptr);
    bind_text(s,1,aid); while(sqlite3_step(s)==SQLITE_ROW) r.push_back(row_to_media_item(s)); sqlite3_finalize(s); return r;
}

// ===== Tags =====
std::vector<Tag> Database::get_all_tags() {
    std::lock_guard<std::mutex> lock(mutex_); std::vector<Tag> r;
    sqlite3_stmt* s; sqlite3_prepare_v2(db_,"SELECT * FROM tags ORDER BY name",-1,&s,nullptr);
    while(sqlite3_step(s)==SQLITE_ROW) r.push_back(row_to_tag(s)); sqlite3_finalize(s); return r;
}
std::vector<TagWithInfo> Database::get_root_tags() {
    std::lock_guard<std::mutex> lock(mutex_); std::vector<TagWithInfo> r;
    sqlite3_stmt* s; sqlite3_prepare_v2(db_,"SELECT t.*,(SELECT COUNT(*) FROM media_tags WHERE tag_id=t.id) FROM tags t WHERE t.parent_id IS NULL ORDER BY t.name",-1,&s,nullptr);
    while(sqlite3_step(s)==SQLITE_ROW){TagWithInfo i;i.tag=row_to_tag(s);i.media_count=sqlite3_column_int(s,5);r.push_back(i);}
    sqlite3_finalize(s); return r;
}
std::vector<TagWithInfo> Database::get_child_tags(const std::string& pid) {
    std::lock_guard<std::mutex> lock(mutex_); std::vector<TagWithInfo> r;
    sqlite3_stmt* s; sqlite3_prepare_v2(db_,"SELECT t.*,(SELECT COUNT(*) FROM media_tags WHERE tag_id=t.id) FROM tags t WHERE t.parent_id=? ORDER BY t.name",-1,&s,nullptr);
    bind_text(s,1,pid); while(sqlite3_step(s)==SQLITE_ROW){TagWithInfo i;i.tag=row_to_tag(s);i.media_count=sqlite3_column_int(s,5);r.push_back(i);}
    sqlite3_finalize(s); return r;
}
std::string Database::create_tag(const std::string& n, const std::optional<std::string>& c, const std::optional<std::string>& pid) {
    std::lock_guard<std::mutex> lock(mutex_); std::string id=generate_uuid();
    sqlite3_stmt* s; sqlite3_prepare_v2(db_,"INSERT INTO tags(id,name,color,parent_id,created_at) VALUES(?,?,?,?,?)",-1,&s,nullptr);
    bind_text(s,1,id); bind_text(s,2,n); bind_opt_text(s,3,c); bind_opt_text(s,4,pid); sqlite3_bind_int64(s,5,current_timestamp_ms());
    sqlite3_step(s); sqlite3_finalize(s); return id;
}
int Database::delete_tag(const std::string& id) {
    std::lock_guard<std::mutex> lock(mutex_);
    sqlite3_stmt* s; sqlite3_prepare_v2(db_,"DELETE FROM tags WHERE id=?",-1,&s,nullptr); bind_text(s,1,id);
    int rc=sqlite3_step(s); sqlite3_finalize(s); return rc;
}
int Database::rename_tag(const std::string& id, const std::string& n) {
    std::lock_guard<std::mutex> lock(mutex_);
    sqlite3_stmt* s; sqlite3_prepare_v2(db_,"UPDATE tags SET name=? WHERE id=?",-1,&s,nullptr); bind_text(s,1,n); bind_text(s,2,id);
    int rc=sqlite3_step(s); sqlite3_finalize(s); return rc;
}
int Database::update_tag_color(const std::string& id, const std::string& c) {
    std::lock_guard<std::mutex> lock(mutex_);
    sqlite3_stmt* s; sqlite3_prepare_v2(db_,"UPDATE tags SET color=? WHERE id=?",-1,&s,nullptr); bind_text(s,1,c); bind_text(s,2,id);
    int rc=sqlite3_step(s); sqlite3_finalize(s); return rc;
}
int Database::update_tag_parent(const std::string& id, const std::optional<std::string>& pid) {
    std::lock_guard<std::mutex> lock(mutex_);
    sqlite3_stmt* s; sqlite3_prepare_v2(db_,"UPDATE tags SET parent_id=? WHERE id=?",-1,&s,nullptr); bind_opt_text(s,1,pid); bind_text(s,2,id);
    int rc=sqlite3_step(s); sqlite3_finalize(s); return rc;
}
int Database::add_tag_to_media(const std::string& mid, const std::string& tid) {
    std::lock_guard<std::mutex> lock(mutex_);
    sqlite3_stmt* s; sqlite3_prepare_v2(db_,"INSERT OR IGNORE INTO media_tags(media_id,tag_id,created_at) VALUES(?,?,?)",-1,&s,nullptr);
    bind_text(s,1,mid); bind_text(s,2,tid); sqlite3_bind_int64(s,3,current_timestamp_ms());
    int rc=sqlite3_step(s); sqlite3_finalize(s); return rc;
}
int Database::remove_tag_from_media(const std::string& mid, const std::string& tid) {
    std::lock_guard<std::mutex> lock(mutex_);
    sqlite3_stmt* s; sqlite3_prepare_v2(db_,"DELETE FROM media_tags WHERE media_id=? AND tag_id=?",-1,&s,nullptr);
    bind_text(s,1,mid); bind_text(s,2,tid);
    int rc=sqlite3_step(s); sqlite3_finalize(s); return rc;
}
std::vector<Tag> Database::get_media_tags(const std::string& mid) {
    std::lock_guard<std::mutex> lock(mutex_); std::vector<Tag> r;
    sqlite3_stmt* s; sqlite3_prepare_v2(db_,"SELECT t.* FROM tags t JOIN media_tags mt ON t.id=mt.tag_id WHERE mt.media_id=? ORDER BY t.name",-1,&s,nullptr);
    bind_text(s,1,mid); while(sqlite3_step(s)==SQLITE_ROW) r.push_back(row_to_tag(s)); sqlite3_finalize(s); return r;
}
std::vector<MediaItem> Database::get_media_by_tags_and(const std::vector<std::string>& tids) {
    std::lock_guard<std::mutex> lock(mutex_); std::vector<MediaItem> r; if(tids.empty()) return r;
    std::string sql="SELECT m.* FROM media_items m WHERE "; for(size_t i=0;i<tids.size();i++){if(i)sql+=" AND ";sql+="EXISTS(SELECT 1 FROM media_tags WHERE media_id=m.id AND tag_id=?)";}
    sql+=" ORDER BY m.created_at DESC";
    sqlite3_stmt* s; sqlite3_prepare_v2(db_,sql.c_str(),-1,&s,nullptr);
    for(size_t i=0;i<tids.size();i++) bind_text(s,i+1,tids[i]);
    while(sqlite3_step(s)==SQLITE_ROW) r.push_back(row_to_media_item(s)); sqlite3_finalize(s); return r;
}
std::vector<MediaItem> Database::get_media_by_tags_or(const std::vector<std::string>& tids) {
    std::lock_guard<std::mutex> lock(mutex_); std::vector<MediaItem> r; if(tids.empty()) return r;
    std::string sql="SELECT DISTINCT m.* FROM media_items m JOIN media_tags mt ON m.id=mt.media_id WHERE mt.tag_id IN ("; for(size_t i=0;i<tids.size();i++){if(i)sql+=",";sql+="?";}sql+=") ORDER BY m.created_at DESC";
    sqlite3_stmt* s; sqlite3_prepare_v2(db_,sql.c_str(),-1,&s,nullptr);
    for(size_t i=0;i<tids.size();i++) bind_text(s,i+1,tids[i]);
    while(sqlite3_step(s)==SQLITE_ROW) r.push_back(row_to_media_item(s)); sqlite3_finalize(s); return r;
}

// ===== Notes =====
std::vector<Note> Database::get_all_notes() {
    std::lock_guard<std::mutex> lock(mutex_); std::vector<Note> r;
    sqlite3_stmt* s; sqlite3_prepare_v2(db_,"SELECT * FROM notes ORDER BY updated_at DESC",-1,&s,nullptr);
    while(sqlite3_step(s)==SQLITE_ROW) r.push_back(row_to_note(s)); sqlite3_finalize(s); return r;
}
std::optional<Note> Database::get_note_by_media_id(const std::string& mid) {
    std::lock_guard<std::mutex> lock(mutex_);
    sqlite3_stmt* s; sqlite3_prepare_v2(db_,"SELECT * FROM notes WHERE media_id=?",-1,&s,nullptr); bind_text(s,1,mid);
    std::optional<Note> r; if(sqlite3_step(s)==SQLITE_ROW) r=row_to_note(s); sqlite3_finalize(s); return r;
}
int Database::save_note(const std::string& mid, const std::string& content) {
    std::lock_guard<std::mutex> lock(mutex_); auto now=current_timestamp_ms();
    sqlite3_stmt* s; sqlite3_prepare_v2(db_,"INSERT INTO notes(id,media_id,content,created_at,updated_at) VALUES(?,?,?,?,?) ON CONFLICT(media_id) DO UPDATE SET content=excluded.content,updated_at=excluded.updated_at",-1,&s,nullptr);
    bind_text(s,1,generate_uuid()); bind_text(s,2,mid); bind_text(s,3,content); sqlite3_bind_int64(s,4,now); sqlite3_bind_int64(s,5,now);
    int rc=sqlite3_step(s); sqlite3_finalize(s); return rc;
}
int Database::delete_note(const std::string& id) {
    std::lock_guard<std::mutex> lock(mutex_);
    sqlite3_stmt* s; sqlite3_prepare_v2(db_,"DELETE FROM notes WHERE id=?",-1,&s,nullptr); bind_text(s,1,id);
    int rc=sqlite3_step(s); sqlite3_finalize(s); return rc;
}

// ===== Scanner =====
int Database::scan_directory(const std::string& dir, const std::string& ad) {
    if(!fs::exists(dir)||!fs::is_directory(dir)) return -1;
    int c=0; for(auto& e:fs::recursive_directory_iterator(dir)){if(e.is_regular_file()){auto ext=get_extension(e.path().string());if(detect_media_type(ext)!="other"){import_media(e.path().string(),ad);c++;}}} return c;
}
int Database::import_single_file(const std::string& fp) { return import_media(fp,app_dir_); }

// ===== Advanced Search =====
std::vector<MediaItem> Database::search_media_advanced(const SearchFilter& f) {
    std::lock_guard<std::mutex> lock(mutex_); std::vector<MediaItem> r;
    std::string sql="SELECT DISTINCT m.* FROM media_items m"; std::vector<std::string> cond;
    bool jt=f.tags.has_value()&&!f.tags->empty(); if(jt) sql+=" JOIN media_tags mt ON m.id=mt.media_id";
    if(!f.query.empty()) cond.push_back("m.original_name LIKE ?");
    if(f.media_type.has_value()) cond.push_back("m.type=?");
    if(f.start_date.has_value()) cond.push_back("m.created_at>=?");
    if(f.end_date.has_value()) cond.push_back("m.created_at<=?");
    if(f.min_size.has_value()) cond.push_back("m.size>=?");
    if(f.max_size.has_value()) cond.push_back("m.size<=?");
    if(jt){std::string ic="mt.tag_id IN (";for(size_t i=0;i<f.tags->size();i++){if(i)ic+=",";ic+="?";}ic+=")";cond.push_back(ic);}
    if(f.has_notes) cond.push_back("EXISTS(SELECT 1 FROM notes WHERE media_id=m.id)");
    if(!cond.empty()){sql+=" WHERE ";for(size_t i=0;i<cond.size();i++){if(i)sql+=" AND ";sql+=cond[i];}}
    sql+=" ORDER BY m.created_at DESC";
    sqlite3_stmt* s; sqlite3_prepare_v2(db_,sql.c_str(),-1,&s,nullptr);
    int p=1;
    if(!f.query.empty()){bind_text(s,p++,"%"+f.query+"%");}
    if(f.media_type.has_value()) bind_text(s,p++,*f.media_type);
    if(f.start_date.has_value()) sqlite3_bind_int64(s,p++,*f.start_date);
    if(f.end_date.has_value()) sqlite3_bind_int64(s,p++,*f.end_date);
    if(f.min_size.has_value()) sqlite3_bind_int64(s,p++,*f.min_size);
    if(f.max_size.has_value()) sqlite3_bind_int64(s,p++,*f.max_size);
    if(jt) for(auto& t:*f.tags) bind_text(s,p++,t);
    while(sqlite3_step(s)==SQLITE_ROW) r.push_back(row_to_media_item(s));
    sqlite3_finalize(s); return r;
}
