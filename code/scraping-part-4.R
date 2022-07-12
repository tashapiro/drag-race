library(tidyverse)
library(rvest)
library(httr)

#SCRAPE LIP SYNCS

#import season data from previous scraping job (part 1)
df_season<-read.csv("../data/season.csv")|>mutate(premiere_date = as.Date(premiere_date), finale_date = as.Date(finale_date))
df_sc<-read.csv("../data/season_contestant.csv")|>mutate(dummy_id = toupper(str_replace_all(contestant," ","")))
df_episodes<-read.csv("../data/episode.csv")|>mutate(air_date = as.Date(air_date))

#filter data set to completed seasons only based on finale date
df_season_subset<-df_season|>filter(!is.na(finale_date))


get_ls<-function(url,index){
  url%>%
    read_html()%>%
    html_elements("table.wikitable")%>%
    .[[index]]%>%
    html_table()
}

#Get Lip Syncs for all seasons that don't belong to all stars franchise or global (F11, F20, different table set up)
#The Switch Drag Race (F12) does not have lip syncs in a wikitable
sub1<-df_season_subset|>filter(!franchise_id %in% c("F11","F12","F20"))

ls1 <- data.frame()
for(row in 1:nrow(sub1)){
  url<-as.character(sub1[row, "link_wiki"])
  season_id<-as.character(sub1[row, "id"])
  print(season_id)
  temp_ls <- get_ls(url,3)
  names(temp_ls)<-c("episode","contestant","contestant2","contestant3","song","outcome")
  temp_ls$season_id<-season_id
  ls1<-rbind(ls1, temp_ls)
}

ls1<-ls1|>
  filter(contestant!="Contestants")|>
  group_by(season_id, episode, contestant, contestant2, contestant3, song)|>
  summarise(outcome = paste(outcome, collapse=", "))|>
  ungroup()|>
  mutate(contestants = case_when(contestant!=contestant2 & contestant!=contestant3~paste(contestant, contestant2, contestant3),TRUE ~ contestant),
         episode = as.integer(str_replace_all(episode, "\\s*\\[[^\\)]+\\]","")),
         outcome = str_replace_all(outcome, "\\s*\\[[^\\)]+\\]",""),
         episode_id = case_when(episode<10~ paste0(season_id,"E0",episode), TRUE ~ paste0(season_id,"E",episode)))|>
  separate_rows(contestants, sep=" vs. ")|>
  separate(song, into = c("x", "song","artist"), sep='\"')|>
  select(-contestant)|>
  rename(contestant=contestants)|>
  mutate(artist = substr(artist, 2,nchar(artist)-1))|>
  select(episode_id, season_id, contestant, song, artist, outcome)

#Get All Stars Lip Syncs
sub2<-df_season_subset|>filter(franchise_id %in% c("F11","F20"))

ls2 <- data.frame()
for(row in 1:nrow(sub2)){
  url<-as.character(sub2[row, "link_wiki"])
  season_id<-as.character(sub2[row, "id"])
  print(season_id)
  if(season_id == "F11S03"){index = 4}
  else{index=3}
  temp_ls <- get_ls(url,index)
  temp_ls <- temp_ls[,1:6]
  names(temp_ls)<-c("episode","contestant","contestant2","contestant3","song","outcome")
  temp_ls$season_id<-season_id
  ls2<-rbind(ls2, temp_ls)
}

ls2<-ls2|>
  filter(song!="Song")|>
  mutate(
    contestant = case_when(grepl("Team",contestant)~contestant, TRUE ~ str_replace(contestant, "\\s*\\([^\\)]+\\)","")),
    contestant3 = case_when(grepl("Team",contestant)~contestant3, TRUE ~ str_replace(contestant3, "\\s*\\([^\\)]+\\)","")),
    contestants = case_when(contestant!=contestant2 & contestant!=contestant3~paste(contestant, contestant2, contestant3),TRUE ~ contestant),
    episode = as.integer(str_replace_all(episode, "\\s*\\[[^\\)]+\\]","")),
    episode_id = case_when(episode<10~ paste0(season_id,"E0",episode), TRUE ~ paste0(season_id,"E",episode)))|>
  group_by(season_id, episode_id, contestants, song)|>
  summarise(outcome = paste(outcome, collapse=", "))|>
  ungroup()|>
  separate_rows(contestants, sep=" vs. ")|>
  separate(song, into = c("x", "song","artist"), sep='\"')|>
  mutate(artist = substr(artist, 2,nchar(artist)-1))|>
  rename(contestant=contestants)|>
  select(episode_id, season_id, contestant, song, artist, outcome)

#combine two subsets to create lip sync dataframe (df_ls)
df_ls<-rbind(ls1,ls2)

test<-df_ls|>left_join(df_episodes|>select(id, air_date), by=c("episode_id"="id"))|>arrange(air_date)
#create lip sync battle ids
ls_eps<-df_ls|>left_join(df_episodes|>select(id, air_date), by=c("episode_id"="id"))|>arrange(air_date)|>distinct(episode_id, song, artist)
ls_eps$id<-paste0("LS",100:(100+nrow(ls_eps)-1))

songs<-ls_eps|>distinct(song,artist)
songs$id<-paste0("S",100:(100+nrow(songs)-1))


df_ls<-df_ls|>
  left_join(ls_eps|>select(-artist), by=c("episode_id"="episode_id","song"="song"))|>
  rename(lip_sync_id =id)|>
  left_join(songs, by=c("song"="song","artist"="artist"))|>
  rename(song_id = id)|>
  mutate(franchise_id = substr(season_id,1,3))|>
  select(lip_sync_id, episode_id, season_id, franchise_id, contestant, song_id, song, artist, outcome)

write.csv(df_ls, "../data/lip_sync_contestant.csv", row.names = FALSE)
