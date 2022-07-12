library(tidyverse)
library(rvest)
library(httr)
library(utils)

#SCRAPING CONTESTANTS

#import season data from previous scraping job (part 1)
df_season<-read.csv("../data/season.csv")
df_season<-df_season|>mutate(premiere_date = as.Date(premiere_date), finale_date = as.Date(finale_date))

#filter data set to completed seasons only based on finale date
df_season_subset<-df_season|>filter(!is.na(premiere_date))

#Function to get contesant information per season. uses data from wikipedia
get_season_contestants<-function(url, table_index){
  table<-url%>%
    read_html()%>%
    html_elements("table.wikitable")%>%
    .[[table_index]]%>%
    html_table()
  names(table)<-tolower(names(table))
  table|>
    rename(contestant =1)|>
    select(contestant, hometown, age, outcome)|>
    mutate(age = str_replace_all(age, "\\s*\\[[^\\)]+\\]",""),
           contestant = str_replace_all(contestant, "\\s*\\[[^\\)]+\\]",""),
           outcome = str_replace_all(outcome, "\\s*\\[[^\\)]+\\]","")
    )
}


#Create Season Contestants Dataframe ----
#Scrape Initial dataset for season contestants (sc)
data_sc<-data.frame()
for(row in 1:nrow(df_season_subset)){
  #use row index to return details like season_id, franchise_id, and url
  season_id<-as.character(df_season_subset[row, "id"])
  #Skip Over The Switch Drag Race F12, wiki table in different format
  if(!substr(season_id,1,3) %in% c("F12","F122")){
    franchise_id<-as.character(df_season_subset[row, "franchise_id"])
    url<-as.character(df_season_subset[row, "link_wiki"])
    print(season_id)
    #if show is All Stars, table index is different (2), otherwise use 1
    temp_sc<-get_season_contestants(url,1)
    temp_sc$season_id <- season_id
    temp_sc$franchise_id <- franchise_id 
    #append data to df_outcomes
    data_sc<-rbind(data_sc, temp_sc)
  }
}

#Add The Switch Contestants
#Season 1
sc_tsw1<-'https://en.wikipedia.org/wiki/The_Switch_Drag_Race_(season_1)'%>%
  read_html()%>%
  html_elements("table.wikitable")%>%
  .[[1]]%>%
  html_table()%>%
  rename(Hometown = `Country of Origin`,Contestant=1)%>%
  mutate(franchise_id = "F12", season_id="F12S01")%>%
  select(Contestant, Hometown, Age, Outcome, season_id, franchise_id)

#Season 2
sc_tsw2<-'https://en.wikipedia.org/wiki/The_Switch_Drag_Race_(season_2)'%>%
  read_html()%>%
  html_elements("table.wikitable")%>%
  .[[1]]%>%
  html_table()%>%
  rename(Hometown = `Country of Origin`,Contestant=1)%>%
  mutate(franchise_id = "F12", season_id="F12S02")%>%
  select(Contestant, Hometown, Age, Outcome, season_id, franchise_id)

#Combine The Switch S1 & 2 Season Contestants
sc_tsw<-rbind(sc_tsw1, sc_tsw2)
names(sc_tsw)<-tolower(names(sc_tsw))
#clean up dataframe
sc_tsw<-sc_tsw%>%
  mutate(age = str_replace_all(age, "\\s*\\[[^\\)]+\\]",""),
         contestant = str_replace_all(contestant, "\\s*\\[[^\\)]+\\]",""),
         hometown = str_replace_all(hometown, "\\s*\\[[^\\)]+\\]",""),
         outcome = str_replace_all(outcome, "\\s*\\[[^\\)]+\\]",""))
  
#Clean Dataframe for Season Contestants
df_sc<-data_sc|>
  #add The Switch Contestants
  rbind(sc_tsw)|>
  distinct(season_id, franchise_id, contestant, hometown, age, outcome)|>
  left_join(df_season|>select(id, link_fandom), by=c("season_id"="id"))|>
  rename(rank = outcome)|>
  arrange(season_id, contestant)|>
  group_by(season_id)|>
  mutate(temp_id = row_number(),
         season_contestant_id = case_when(temp_id<10 ~ paste0(season_id,"C0",temp_id), TRUE ~ paste0(season_id,"C",temp_id)),
         contestant = str_replace(contestant, "\\s*\\([^\\)]+\\)",""),
         contestant_words = str_count(contestant,"\\S+"),
         contestant = case_when(contestant_words==1 & contestant !="BenDeLaCreme"~gsub("([a-z])([A-Z])","\\1 \\2",contestant), 
                                contestant == 'Sofía "Sabélo" Camará' ~ "Sofía Camará",
                                contestant == 'Fransiska "Pakita" Tólika' ~ 'Pakita',
                                contestant == "Kristina Kox" ~ "Veneno", 
                                contestant == "La Yoyi" ~ "Yoyi", 
                                contestant == "Rubí Blonde"~ "Rubí",
                                contestant == "Stephanie Fox" ~ "Botota Fox",
                                contestant == "Francisca del Solar" ~ "Francisca Del Solar",
                                contestant == "Divina de Campo" ~ "Divina De Campo",
                                contestant == "DiDa Ritz" ~ "Dida Ritz",
                                TRUE ~ contestant)
  )|>
  ungroup()|>
  select(season_contestant_id, season_id, franchise_id, contestant, hometown, age, rank, link_fandom)


#HELPER FUNCTION - scrape image url from wiki fandom per drag queen
get_image_url<-function(url, drag_queen){
  if(http_error(url)){"Bad URL"}
  else{
    path =  paste0('//*[@alt="', drag_queen,'"]') 
    node<-url%>%
      read_html()%>%
      html_nodes(xpath = path)
    if(length(node)==0){"Bad URL"}
    else{node%>%html_attr("data-src")%>%.[[1]]}
  }
}

#Some alt text on images does not match contestant name, 
sc_image_replace <- data.frame(id = c("F10S01C09","F10S04C03",
                                      "F10S07C11","F10S08C02","F10S09C05",
                                      "F10S10C05","F10S10C06","F10S11C01",
                                      "F10S14C10","F11S03C08",
                                      "F11S04C09","F11S05C06","F11S06C02",
                                      "F11S06C01","F14S01C05","F14S01C10",
                                      "F16S01C01","F17S01C07"),
                               image_name = c("Victoria Parker", "Dida Ritz",
                                              "Frisbee Jenkins","Bob The Drag Queen","Eureka!",
                                              "Eureka!","Kalorie Karbdashian-Williams","A'keria Chanel Davenport",
                                              'Kornbread Jeté',"Shangela Laquifa Wadley",
                                              "Trinity The Tuck","Mariah Balenciaga","Eureka",
                                              "A'keria Chanel Davenport","Divina De Campo","Vinegar Strokes&NoBreak",
                                              "ChelseaBoy","Karen From Finance")
)

#Append Image Names
df_sc<- df_sc|>
  left_join(sc_image_replace, by=c("season_contestant_id"="id"))|>
  mutate(image_name = case_when(is.na(image_name)~contestant, TRUE~image_name))


#Loop to scrape image url per season contestant using helper function
sc_images<-data.frame()
for(row in 1:nrow(df_sc)){
  url<-as.character(df_sc[row, "link_fandom"])
  id<-as.character(df_sc[row, "season_contestant_id"])
  queen<-as.character(df_sc[row, "image_name"])
  print(queen)
  image<-get_image_url(url,queen)
  index<-gregexpr("/revision", image)[[1]][1]
  temp_image <- data.frame(id = id, image = substr(image, 1,index-1))
  sc_images <- rbind(sc_images, temp_image)
}

#Append Image information back to df_sc
df_sc<-df_sc|>left_join(sc_images, by=c("season_contestant_id"="id"))

#Create Contestants Dataframe ----

#some contestants appear on multiple shows with different names, standardize before creating unique IDs
name_lookups<-data.frame(sc_id = c("F10S02C09","F11S06C02","F10S09C13","F10S10C11","F11S04C07","F10S02C10"),
                         name = c("Shangela","Eureka","Trinity the Tuck","Mo Heart","Mo Heart","Kylie Sonique Love"))


df_contestants<-df_sc|>
  left_join(df_season|>select(id, premiere_date), by=c("season_id"="id"))|>
  left_join(name_lookups, by=c("season_contestant_id"="sc_id"))|>
  mutate(name = case_when(!is.na(name) ~ name, TRUE ~ contestant))|>
  group_by(name)|>
  mutate(appearence = row_number())|>
  filter(appearence ==1)|>
  ungroup()|>
  arrange(premiere_date, name)|>
  rename(original_season_id = season_id)|>
  select(name, original_season_id)

#create unique IDs, rearrange dataset
df_contestants$id<-paste0("Q",100:(100+nrow(df_contestants)-1))

#HELPER FUNCTION - get panel information from Fandom Wiki
get_panel_info<-function(url, var){
  url=URLencode(url)
  if(http_error(url)){"Bad URL"}
  else{
    path =  paste0('//*[@data-source="', var,'"]') 
    data = url|>
      read_html()|>
      html_elements("aside.portable-infobox")|>
      html_elements("div.pi-item")|>
      html_nodes(xpath = path)|>
      html_elements("div")|>
      html_text()
    if(identical(data, character(0))){"NA"}
    else{str_replace(data,"\\s*\\[[^\\)]+\\]","")}
  }
}

#Loop through contestants to scrape additional information
contestant_details <- data.frame()
for(row in 1:nrow(df_contestants)){
  base_url<-'https://rupaulsdragrace.fandom.com/wiki/'
  name<-as.character(df_contestants[row, "name"])
  id<-as.character(df_contestants[row, "id"])
  url<-paste0(base_url,str_replace_all(name," ","_"))
  print(name)
  temp_details <-data.frame(id= id, 
                            name=name, 
                            real_name=get_panel_info(url, "Real Name"), 
                            ethnicity = get_panel_info(url, "Ethinicity"), 
                            dob=get_panel_info(url, "birth year")[1],
                            gender=get_panel_info(url, "Gender"),
                            hometown=get_panel_info(url, "Hometown"),
                            location=get_panel_info(url, "Location")
  )
  contestant_details <- rbind(contestant_details, temp_details)
}






#df_contestants<- df_contestants|>select(id, original_season_id, name)

final_contestants<-df_contestants|>left_join(contestant_details|>select(-name, -ethnicity), by="id")|>
  select(id, name, original_season_id, real_name, dob, gender, hometown, location)


#Adjust Season Contestants to include Contestant ID
df_sc<-df_sc|>
  left_join(name_lookups, by=c("season_contestant_id"="sc_id"))|>
  mutate(name = case_when(!is.na(name) ~ name, TRUE ~ contestant))|>
  left_join(df_contestants, by="name")|>
  rename(contestant_id = id)|>
  select(season_contestant_id, contestant_id, season_id, franchise_id, contestant, hometown, age, rank, image)|>
  rename(link_image = image,
         id = season_contestant_id)


write.csv(df_sc, "../data/season_contestant.csv" , row.names=FALSE)
write.csv(final_contestants, "../data/contestant.csv", row.names=FALSE)
