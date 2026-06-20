-- ============================================================
-- SeanS™ — Supabase Setup Script
-- Paste this ENTIRE file into Supabase → SQL Editor → New Query
-- Click "Run" once. That's the only manual step needed.
-- ============================================================

-- 1. PROFILES (extends Supabase auth.users with app-specific data)
create table if not exists profiles (
  id uuid references auth.users(id) on delete cascade primary key,
  username text unique not null,
  created_at timestamp with time zone default now(),
  favorite_genres text[] default '{}'
);

alter table profiles enable row level security;

create policy "Profiles are viewable by everyone"
  on profiles for select using (true);

create policy "Users can insert their own profile"
  on profiles for insert with check (auth.uid() = id);

create policy "Users can update their own profile"
  on profiles for update using (auth.uid() = id);


-- 2. SONGS (metadata for every uploaded track)
create table if not exists songs (
  id uuid default gen_random_uuid() primary key,
  uploader_id uuid references profiles(id) on delete cascade not null,
  title text not null,
  artist text not null,
  genre text default 'Other',
  is_public boolean default false,        -- false = copyrighted/private, true = shared in Songs tab
  storage_path text not null,              -- path inside the 'songs' storage bucket
  created_at timestamp with time zone default now()
);

alter table songs enable row level security;

-- Anyone can see public songs; uploaders can always see their own (public or private)
create policy "Public songs are viewable by everyone, private songs only by uploader"
  on songs for select
  using (is_public = true or auth.uid() = uploader_id);

create policy "Users can insert their own songs"
  on songs for insert with check (auth.uid() = uploader_id);

create policy "Users can update their own songs"
  on songs for update using (auth.uid() = uploader_id);

create policy "Users can delete their own songs"
  on songs for delete using (auth.uid() = uploader_id);


-- 3. PLAYLISTS
create table if not exists playlists (
  id uuid default gen_random_uuid() primary key,
  owner_id uuid references profiles(id) on delete cascade not null,
  name text not null,
  created_at timestamp with time zone default now()
);

alter table playlists enable row level security;

create policy "Users can view their own playlists"
  on playlists for select using (auth.uid() = owner_id);

create policy "Users can insert their own playlists"
  on playlists for insert with check (auth.uid() = owner_id);

create policy "Users can update their own playlists"
  on playlists for update using (auth.uid() = owner_id);

create policy "Users can delete their own playlists"
  on playlists for delete using (auth.uid() = owner_id);


-- 4. PLAYLIST_SONGS (join table: which songs are in which playlist)
create table if not exists playlist_songs (
  id uuid default gen_random_uuid() primary key,
  playlist_id uuid references playlists(id) on delete cascade not null,
  song_id uuid references songs(id) on delete cascade not null,
  added_at timestamp with time zone default now()
);

alter table playlist_songs enable row level security;

create policy "Users can view songs in their own playlists"
  on playlist_songs for select
  using (
    exists (
      select 1 from playlists
      where playlists.id = playlist_songs.playlist_id
      and playlists.owner_id = auth.uid()
    )
  );

create policy "Users can add songs to their own playlists"
  on playlist_songs for insert
  with check (
    exists (
      select 1 from playlists
      where playlists.id = playlist_songs.playlist_id
      and playlists.owner_id = auth.uid()
    )
  );

create policy "Users can remove songs from their own playlists"
  on playlist_songs for delete
  using (
    exists (
      select 1 from playlists
      where playlists.id = playlist_songs.playlist_id
      and playlists.owner_id = auth.uid()
    )
  );


-- 5. STORAGE BUCKET for MP3 files
insert into storage.buckets (id, name, public)
values ('songs', 'songs', true)
on conflict (id) do nothing;

create policy "Song files are publicly readable"
  on storage.objects for select
  using (bucket_id = 'songs');

create policy "Authenticated users can upload songs"
  on storage.objects for insert
  with check (bucket_id = 'songs' and auth.role() = 'authenticated');

create policy "Users can delete their own uploaded files"
  on storage.objects for delete
  using (bucket_id = 'songs' and auth.uid()::text = (storage.foldername(name))[1]);

-- ============================================================
-- Done! Your database is ready. Go build something great.
-- ============================================================
