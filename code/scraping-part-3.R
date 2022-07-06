library(tidyverse)
library(rvest)
library(httr)

#SCRAPING EPISODES & OUTCOMES

#import season data from previous scraping job (part 1)
df_season<-read.csv("../data/season.csv")|>mutate(premiere_date = as.Date(premiere_date), finale_date = as.Date(finale_date))
df_sc<-read.csv("../data/season_contestant.csv")|>mutate(dummy_id = toupper(str_replace_all(contestant," ","")))

#filter data set to completed seasons only based on finale date
df_season_subset<-df_season|>filter(!is.na(finale_date))

#Create Episodes Dataframe ----
get_episodes<-function(url){
  #get data from table
  data<-url%>%
    read_html()%>%
    html_elements("table.wikiepisodetable")%>%
    .[[1]]%>%
    html_table()
  #format column names
   names(data)<-c("episode_num","season_episode_num","title","air_date","description")
   
  #reshape data
  df<-data|>
    filter(is.na(description))|>
    select(-description)|>
    cbind(data|>filter(!is.na(description))|>select(description))|>
    
  df
}


#Scraping for all franchises except F19 (Drag Race vs The World) - different format ----
df_episodes <- data.frame()
for(row in 1:nrow(df_season_subset%>%filter(id!="F19S01"))){
  url <- df_season_subset[row,"link_wiki"]
  df_temp <- get_episodes(url)
  df_temp$season_id <-df_season_subset[row,"id"]
  df_temp$franchise_id <- df_season_subset[row,"franchise_id"]
  df_episodes <- rbind(df_episodes, df_temp)
}

#get UK vs. The World Seperately for episodes
f19s01<-"https://en.wikipedia.org/wiki/RuPaul%27s_Drag_Race:_UK_vs_the_World"%>%
  read_html()%>%
  html_elements("table.wikiepisodetable")%>%
  .[[1]]%>%
  html_table()

names(f19s01)<-c("episode_num","title","air_date","viewers","description")

f19s01<-f19s01|>
  filter(is.na(description))|>
  select(-description)|>
  cbind(f19s01|>filter(!is.na(description))|>select(description))|>
  mutate(season_episode_num=episode_num,
         franchise_id = "F19",
         season_id = "F19S01")|>
  select(episode_num, season_episode_num, title, air_date, description, season_id, franchise_id)

df_episodes<-rbind(df_episodes, f19s01)|>
  mutate(air_date = as.Date(str_sub(air_date, -11, -2)),
         episode_num = as.integer(episode_num),
         season_epispde_num = as.integer(season_episode_num),
         id= case_when(season_epispde_num<10 ~ paste0(season_id,"E0",season_epispde_num), TRUE ~ paste0(season_id,"E",season_epispde_num))
  )|>
  select(id, season_id, franchise_id, season_episode_num, title, air_date, description)



write.csv(df_episodes,"../data/episode.csv", row.names = FALSE)


#Create Episode Outcomes Dataframe ----
#Function to extract outcomes per contestant and episode. uses data from fandom.
get_season_outcomes<-function(url, table_index){
  table<-url%>%
    read_html()%>%
    html_elements("table.wikitable")%>%
    .[[table_index]]%>%
    html_table()
  
  col_names<-names(table)
  col_eps<-col_names[grepl("Ep.", col_names)]
  
  if("Queen" %in% col_names){
    table<-table%>%rename("Contestant"="Queen")
  }
  
  table[-1,]|>
    select(Contestant, col_eps)|>
    pivot_longer(col_eps, names_to="episode",values_to="outcome")
}


#Loop Through Seasons to scrape episode outcomes on Fandom
data_outcomes<-data.frame()
for(row in 1:nrow(df_season_subset)){
  #use row index to return details like season_id, franchise_id, and url
  season_id<-as.character(df_season_subset[row, "id"])
  franchise_id<-as.character(df_season_subset[row, "franchise_id"])
  url<-as.character(df_season_subset[row, "link_fandom"])
  print(season_id)
  #if show is All Stars or vs The World, table index is different (2), otherwise use 1
  if(franchise_id %in% c("F11","F19")){
    temp_outcomes<-get_season_outcomes(url,2)
  }
  else{temp_outcomes<-get_season_outcomes(url,1)}
  
  temp_outcomes$season_id <- season_id
  temp_outcomes$franchise_id <- franchise_id 
  
  #append data to df_outcomes
  data_outcomes<-rbind(data_outcomes, temp_outcomes)
}


#Clean Outcomes
df_episode_outcomes<-data_outcomes|>
  rename(contestant=Contestant)|>
  filter(outcome!="" & contestant!="Contestant")|>
  mutate(contestant = str_replace(contestant, "\\s*\\([^\\)]+\\)",""),
         contestant = gsub("([a-z])([A-Z])","\\1 \\2",contestant),
         contestant = case_when(contestant=="A'keria Chanel Davenport" ~ "A'keria C.Davenport", 
                                contestant=="Eureka O'Hara" ~ "Eureka",
                                contestant=="Kalorie Karbdashian-Williams" ~ "Kalorie Karbdashian Williams",
                                grepl("Vinegar Str",contestant) ~ "Vinegar Strokes",
                                TRUE ~ contestant),
         episode_num = as.integer(str_replace(episode, "Ep.","")),
         dummy_id = toupper(str_replace_all(contestant," ","")),
         episode_id = case_when(episode_num<10~paste0(season_id,"E0",episode_num), TRUE ~ paste0(season_id,"E",episode_num)),
         detailed_outcome = outcome, 
         outcome = case_when(
           grepl("BTM", detailed_outcome) ~ "BTM",
           grepl("SAFE", detailed_outcome) ~ "SAFE",
           grepl("HIGH", detailed_outcome) ~ "HIGH",
           grepl("LOW", detailed_outcome) ~ "LOW",
           grepl("WIN", detailed_outcome) ~ "WIN",
           grepl("ELIM", detailed_outcome) ~ "ELIM",
           TRUE ~ detailed_outcome
         )
  )|>
  left_join(df_sc|>select(id, contestant_id, season_id, dummy_id)|>rename(season_contestant_id=id),
            by=c("dummy_id"="dummy_id","season_id"="season_id"))|>
  select(season_contestant_id, contestant_id, episode_id, season_id, franchise_id, episode_num, contestant, outcome, detailed_outcome)


write.csv(df_episode_outcomes, "../data/episode_outcome.csv", row.names=FALSE)
