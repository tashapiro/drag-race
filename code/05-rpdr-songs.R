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
get_track<-function(query){
  results=search_spotify(query, type="track", limit=1)
  data=data.frame(track_id = results$id, 
             track = results$name,
             artist_id = rbindlist(results$artists, fill=TRUE)$id,
             artist = rbindlist(results$artists, fill=TRUE)$name,
             album = results$album.name,
             track_url = results$external_urls.spotify)
  data
}

#loop to get spotify track data
spotify_data <- data.frame()
for(row in 1:nrow(songs)){
  song_id<-as.character(songs[row, "song_id"])
  song<-as.character(songs[row, "song"])
  artist<-as.character(songs[row, "artist"])
  q <- paste(song, artist)
  print(q)
  temp_data<-get_track(q)
  if(nrow(temp_data)>0){
  temp_data$song_id<-song_id
  spotify_data<-rbind(spotify_data, temp_data)
  }
}

#clean up spotify song data
df_sp<-spotify_data|>group_by(track_id, song_id, track, track_url)|>mutate(x = row_number())|>filter(x==1)|>
  select(song_id, track_id, artist_id, track, artist, album, track_url)|>
  rename(spotify_track_id = track_id, 
         spotify_artist_id = artist_id)

audio_features<-data.frame()
for(row in 1:nrow(df_sp)){
  id<-as.character(df_sp[row, "spotify_track_id"])
 audio_features<-rbind(audio_features,get_track_audio_features(id))
}
#some songs may appear more than once
audio_features<-unique(audio_features)

final_songs<-songs|>
  left_join(df_sp, by="song_id")|>
  rename(artist = artist.x)|>
  select(-artist.y)|>
  left_join(audio_features, by=c("spotify_track_id"="id"))|>
  select(-track_href, -uri, -analysis_url)

#save dataframe
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
