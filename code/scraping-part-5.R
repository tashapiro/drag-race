library(tidyverse)
library(rvest)
library(httr)

df_franchise<-read.csv("../data/franchise.csv")
df_eps <- read.csv("../data/episode.csv")


#Get Main Judges from Wikipedia page for Drag Race Franchise
get_judges<-function(url){
table<-url%>%
  read_html()%>%
  html_elements("table.wikitable")%>%
  .[[1]]%>%
  html_table()

names(table)<-tolower(as.character(head(table,1)))

table[-1,]|>pivot_longer(-judge, names_to="season_num", values_to="type")
}

#Loop through different Drag Race Franchise pages and collect data
judges <- data.frame()
for(row in 1:nrow(df_franchise)){
  #get url and franchise id
  url <- as.character(df_franchise[row,"link_wiki"])
  franchise_id <- as.character(df_franchise[row,"id"])
  #no judge information table for some seasons, exclude from loop
  if(!franchise_id %in% c("F18", "F19","F20","F21")){
  #print for troubleshooting purposes
  print(franchise_id)
  #grab data, dump in temporary dataframe object
  temp_data<-get_judges(url)
  temp_data$franchise_id <- franchise_id
  #combine dataframe with intialized judges dataframe created prior to loop
  judges<-rbind(judges, temp_data)
  }
}

#reshape & clean data
df_main_judges<-judges|>
  filter(type=="Main")|>
  mutate(season_num = as.integer(season_num),
         season_id = case_when(season_num<10~paste0(franchise_id,"S0",season_num),
                               TRUE ~ paste0(franchise_id,"S",season_num)),
         judge= str_replace(judge, "\\s*\\[[^\\)]+\\]","")
  )


#Custom function to grab information about judges
parse_text<-function(string, expression){
  if(grepl(expression,string)){
    index<-gregexpr(expression, string)[[1]][1]
    start_pos<-nchar(expression)+index+1
    matches<-gregexpr('\\n', string)[[1]]
    end_pos <- matches[matches>index][1]-1
    substr(string,start_pos,end_pos)
  }
  else{NA}
}


#Get Guest Judges, Guest Judges differ by episode 
df_guests<-df_eps|>
  filter(grepl("Guest Judge",description))|>
  mutate(
        #get judge per description
         judge = lapply(description, FUN=parse_text, expression="Guest Judge"),
         #replace and with , --- will help separate rows later
         judge = str_replace(judge, ", and ",", "),
         #remove brackets and text between
         judge= str_replace(judge, "\\s*\\[[^\\)]+\\]",""),
         #remove parentheses and text between
         judge = str_replace(judge, "\\s*\\([^\\)]+\\)",""),
         judge = trimws(str_replace(judge,":","")),
         type="Guest")|>
  select(id, season_id, franchise_id, judge, type)|>
  separate_rows(judge, sep=", ")|>
  separate_rows(judge, sep=" and ")|>
  rename(episode_id=id)

#get list of judges per episode, use main judges and guest judges
df_ep_judges<-df_eps|>
  filter(grepl("Challenge",description))|>
  select(id, season_id, franchise_id)|>
  rename(episode_id = id)|>
  left_join(df_main_judges|>select(-franchise_id, -season_num), by="season_id")|>
  rbind(df_guests)|>
  filter(!is.na(judge))|>
  arrange(episode_id)|>
  rename(judge_type=type)

write.csv(df_ep_judges, "../data/episode_judge.csv", row.names=FALSE)


