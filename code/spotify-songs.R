library(tidyverse)
library(spotifyr)
library(httr)
library(data.table)

df_ls <-read.csv("../data/lip_sync_contestant.csv")

songs<- df_ls|>distinct(song_id, song, artist)

#authenticate spotify - requires personal client and client_secret_id
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
             album_id = results$album.id,
             artist = rbindlist(results$artists, fill=TRUE)$name,
             album = results$album.name,
             album_release_date = results$album.release_date,
             track_url = results$external_urls.spotify)
  head(data,1)
}


get_track("Stronger","Britney Spears")

replace <- data.frame(song_id = c("S106","S156","S452"), 
                      song = c("Cover Girl", "Two To Make It Right","Heartbreak Hotel (Hex Hector)"),
                      artist = c("RuPaul", "Seduction","Whitney Houston ft. Faith Evans, Kelly Price")
)


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
  select(song_id, track_id, artist_id, album_id, track, artist, album, album_release_date, track_url)|>
  rename(spotify_track_id = track_id, 
         spotify_artist_id = artist_id,
         spotify_album_id = album_id)


audio_features<-data.frame()
for(row in 1:nrow(df_sp)){
  id<-as.character(df_sp[row, "spotify_track_id"])
 audio_features<-rbind(audio_features,get_track_audio_features(id))
}

audio_features<-unique(audio_features)

final_songs<-songs|>
  left_join(df_sp, by="song_id")|>
  rename(artist = artist.x, spotify_artist = artist.y, spotify_song = track, id = song_id)|>
  left_join(audio_features, by=c("spotify_track_id"="id"))|>
  select(-track_href, -uri, -analysis_url, -type)


write.csv(final_songs, "../data/song.csv", row.names=FALSE)