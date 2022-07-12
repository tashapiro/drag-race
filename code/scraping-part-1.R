library(tidyverse)
library(rvest)
library(httr)


#SCRAPING SHOWS

#Initial Scraping ----
#urls for RuPaul's Drag Race Franchise information - Wikipedia & Fandom 
url_wiki <-'https://en.wikipedia.org/wiki/Drag_Race_(franchise)'
url_fandom<-'https://rupaulsdragrace.fandom.com/wiki/Drag_Race_(Franchise)'

#Get list of all RuPaul franchises from Wikipeida
table_franchise<-url_wiki%>%
  read_html()%>%
  html_elements("table.wikitable")%>%
  .[[1]]%>%
  html_table()

#rename columns for table franchise dataset
names(table_franchise)<-c("region","name","network","premier","status","judges","winners")

#scrape related links to shows
links_wiki<-url_wiki%>%
  read_html()%>%
  html_elements("table.wikitable")%>%
  .[[1]]%>%
  html_elements("i")%>%
  html_elements("a")%>%
  html_attrs()
links_wiki<-data.frame(t(as.data.frame(links_wiki)))
rownames(links_wiki) <- 1:nrow(links_wiki) 

#Create Franchise Dataframe ----
df_franchise<-table_franchise|>
  select(name, region, premier, status)|>
  left_join(links_wiki, by=c("name"="title"))|>
  rename(link_wiki = href, premier_date = premier)|>
  mutate(
    status = case_when(premier_date == "TBA"~ "TBA", TRUE ~ status),
    premier_date = str_replace(premier_date, "\\s*\\[[^\\)]+\\]",""),
    premier_date = as.Date(premier_date, "%B %d, %Y"),
    link_wiki = case_when(is.na(link_wiki) ~ "", TRUE ~ paste0("https://en.wikipedia.org",link_wiki)),
    link_fandom = case_when(grepl("The World", name) ~ "https://rupaulsdragrace.fandom.com/wiki/Drag_Race_vs_The_World",
                            TRUE ~ paste0("https://rupaulsdragrace.fandom.com/wiki/",str_replace_all(str_replace_all(name," ","_"),"\\'","%27"))
    )
  )|>
  arrange(premier_date, name)|>
  filter(!name %in% c("RuPaul's Secret Celebrity Drag Race"))

#assign unique IDs per franchise
df_franchise$id<-paste0("F",10:(10+nrow(df_franchise)-1))
df_franchise<-df_franchise|>select(id, name, region, premier_date, status, link_wiki, link_fandom)


#Helper Function to scrape additional contestant information stored on Drag Queen profiles on Fandom Wiki
get_panel_info<-function(url, var){
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

#Create Season Dataframe ----
df_season<-table_franchise|>
  select(name, winners)|>
  #clean up data from franchises
  mutate(winners = str_replace_all(winners, "\\s*\\[[^\\)]+\\]",""),"")|>
  separate_rows(winners, sep = '\\n')|>
  separate(winners, into= c("season", "winner"), sep=": ")|>
  separate(season, into=c("season","season_year"), sep=", ")|>
  mutate(season_year = case_when(grepl("-",season_year)~substr(season_year,6,10),TRUE ~ season_year),
         season_year = as.integer(substr(season_year,1,4)),
         season_num = as.integer(str_replace(season,"Season|Series","")))|>
  inner_join(df_franchise%>%select(id, name, link_wiki, link_fandom), by=c("name"))|>
  rename(franchise_id = id, franchise_name = name)|>
  mutate(id = case_when(season_num<10~paste0(franchise_id, "S0",season_num), TRUE ~ paste0(franchise_id, "S",season_num)),
         link_wiki = case_when(
           id == "F20S01" ~ "https://en.wikipedia.org/wiki/RuPaul%27s_Drag_Race:_UK_vs_the_World",
           id == "F23S01" ~ "https://en.wikipedia.org/wiki/Canada%27s_Drag_Race:_Canada_vs._the_World",
           TRUE ~ paste0(link_wiki,"_(",tolower(str_replace_all(season," ","_")),")")),
         link_fandom = case_when(
           id == "F20S01" ~ "https://rupaulsdragrace.fandom.com/wiki/RuPaul%27s_Drag_Race_UK_vs_The_World_(Season_1)",
           id == "F23S01" ~ "https://rupaulsdragrace.fandom.com/wiki/Canada%27s_Drag_Race_vs_The_World_(Season_1)",
           TRUE ~ str_replace(paste0(link_fandom,"_(Season_",season_num,")"),"ñ","%C3%B1")),
         premiere_date = as.character(lapply(link_fandom, get_panel_info, "premiere")),
         finale_date = as.character(lapply(link_fandom, get_panel_info, "finale"))
  )|>
  mutate(premiere_date = as.Date(str_replace_all(premiere_date, "Friday, ",""),"%B %d, %Y"),
         finale_date = as.Date(str_replace_all(finale_date, "Friday, ",""),"%B %d, %Y"))|>
  select(id, franchise_id, franchise_name, season, season_num, season_year, premiere_date, finale_date, link_wiki, link_fandom)|>
  arrange(id)


missing<-data.frame(
  id = c("F16S02","F15S02","F15S03","F17S02"),
  franchise_id = c("F16","F15","F15","F17"),
  franchise_name = c("Drag Race Holland","Canada's Drag Race","Canada's Drag Race","RuPaul's Drag Race Down Under"),
  season = c("Season 2", "Season 2", "Season 3","Season 2"),
  season_num = c(2, 2, 3, 2),
  season_year = c(2021, 2021, 2022, 2022),
  premiere_date = c(as.Date("2021-08-06"),as.Date("2021-10-14"), as.Date("2022-07-14"), as.Date("2022-07-30")),
  finale_date = c(as.Date("2021-09-24"), as.Date("2021-12-16"), NA, NA),
  link_wiki = c("https://en.wikipedia.org/wiki/Drag_Race_Holland_(season_2)","https://en.wikipedia.org/wiki/Canada%27s_Drag_Race_(season_2)","https://en.wikipedia.org/wiki/Canada%27s_Drag_Race_(season_3)","https://en.wikipedia.org/wiki/RuPaul%27s_Drag_Race_Down_Under_(season_2)"),
  link_fandom = c("https://rupaulsdragrace.fandom.com/wiki/Drag_Race_Holland_(Season_2)","https://rupaulsdragrace.fandom.com/wiki/Canada%27s_Drag_Race_(Season_2)","https://rupaulsdragrace.fandom.com/wiki/Canada%27s_Drag_Race_(Season_3)","https://rupaulsdragrace.fandom.com/wiki/RuPaul%27s_Drag_Race_Down_Under_(Season_2)")
)

df_season<-rbind(df_season, missing)|>arrange(franchise_id)

#Save Data
write.csv(df_franchise, "../data/franchise.csv", row.names=FALSE)
write.csv(df_season, "../data/season.csv", row.names=FALSE)
