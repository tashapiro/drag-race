library(tidyverse)
library(spotifyr)
library(httr)
library(data.table)

df_ls <-read.csv("../data/lip_sync_contestant.csv")
songs<- df_ls|>distinct(song_id, song, artist)

#authenticate spotify - insert your own client id and client secret id (from Spotify Developer Account)
Sys.setenv(SPOTIFY_CLIENT_ID = client_id)
Sys.setenv(SPOTIFY_CLIENT_SECRET = client_secret_id)
access_token <- get_spotify_access_token()


#custom function using spotifyR to get track elements
get_track<-function(song, artist){
  query = paste(song, str_replace(artist, " ft.",""))
  results = search_spotify(query, type="track", limit=1)
  data=data.frame(track_id = results$id, 
                  track = results$name,
                  artist_id = rbindlist(results$artists, fill=TRUE)$id,
                  artist = rbindlist(results$artists, fill=TRUE)$name,
                  album = results$album.name,
                  track_url = results$external_urls.spotify)
  head(data,1)
}

replace <- data.frame(song_id = c("S106","S156","S437"), 
                      song = c("Cover Girl", "Two To Make It Right","Heartbreak Hotel (Hex Hector)"),
                      artist = c("RuPaul", "Seduction","Whitney Houston ft. Faith Evans, Kelly Price")
)

replace$song[replace$song_id=="S106"]

#loop to get spotify track data
spotify_data <- data.frame()
for(row in 1:nrow(songs)){
  song_id<-as.character(songs[row, "song_id"])
  if(!song_id %in% replace$song_id){lkp<-songs}else{lkp<-replace}
  song<-lkp$song[lkp$song_id==song_id]
  artist<-lkp$artist[lkp$song_id==song_id]
  q <- paste(song, artist)
  print(q)
  temp_data<-get_track(song, artist)
  if(nrow(temp_data)>0){
    temp_data$song_id<-song_id
    spotify_data<-rbind(spotify_data, temp_data)
  }
}

#clean up spotify song data
df_sp<-spotify_data|>
  select(song_id, track_id, artist_id, track, artist, album, track_url)|>
  rename(spotify_track_id = track_id, 
         spotify_artist_id = artist_id)

audio_features<-data.frame()
for(row in 1:nrow(df_sp)){
  id<-as.character(df_sp[row, "spotify_track_id"])
  audio_features<-rbind(audio_features,get_track_audio_features(id))
}

audio_features<-unique(audio_features)

final_songs<-songs|>
  left_join(df_sp, by="song_id")|>
  rename(artist = artist.x, spotify_artist = artist.y, spotify_song = track)|>
  left_join(audio_features, by=c("spotify_track_id"="id"))|>
  select(-track_href, -uri, -analysis_url, -type)


write.csv(final_songs, "../data/song.csv", row.names=FALSE)

#MAKE A PLAYLIST -----
#add local host as a redirect uri to spotify account first! located in Spotify Developer Dashboard in the App. plug in your own user id
create_playlist(user_id, name = "RuPaul Lip Syncs", public = TRUE, collaborative = FALSE, description = NULL, authorization = get_spotify_authorization_code())
#Get Playlist ID
playlists<-get_my_playlists()
playlist_id<-playlists$id[playlists$name=="RuPaul Lip Syncs"]
#Create list of song uris
song_uris<-unique(df_sp$spotify_track_id)

#Limit to add <100 tracks at a time, create loop to add tracks in 50 song increments
for(i in seq(from=1, to=length(song_uris), by=50)){
  index1 = i
  if(i+50>=length(song_uris)){index2= length(song_uris)}else{index2 = i+50}
  print(paste(index1, index2))
  add_tracks_to_playlist(playlist_id=playlist_id, uris= song_uris[index1:index2], authorization = get_spotify_authorization_code())
}
