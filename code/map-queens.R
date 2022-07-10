library(tidyverse)
library(tidygeocoder)
library(leaflet)
library(htmltools)
library(htmlwidgets)

#import data
df<- read.csv("https://raw.githubusercontent.com/tashapiro/drag-race/main/data/contestant.csv")
df_sc<-read.csv("https://raw.githubusercontent.com/tashapiro/drag-race/main/data/season_contestant.csv")
season<-read.csv("https://raw.githubusercontent.com/tashapiro/drag-race/main/data/season.csv")

#shape data
data<-df_sc|>
  left_join(season%>%select(id, franchise_name, season_num, premiere_date), by=c("season_id"="id"))|>
  arrange(contestant_id, premiere_date)|>
  mutate(season_name = paste0(franchise_name," S",season_num))|>
  group_by(contestant_id)|>
  summarise(link_image = last(link_image),
            hometown = first(hometown),
            seasons=paste(season_name, collapse="<br>"))|>
  left_join(df|>select(-hometown), by=c("contestant_id"="id"))|>
  select(contestant_id, name, real_name, hometown, dob, seasons, link_image)



#use tidygeocoder to add lat longs for hometowns
data_geo<-data|>geocode(hometown, method = 'osm', lat = latitude , long = longitude)


#format map data -- add fandom link and create html label
map_data<-data_geo|>
  mutate(fandom = paste0("https://rupaulsdragrace.fandom.com/wiki/",str_replace(name," ","_")),
         label=paste0("<center>",
                      '<img src= "',link_image,'" style="width:70px;height:70px">',"</br>",
                      "<b><a href=",fandom,' style="text-decoration:none;">',toupper(name),"</a></b>",
                      "<br>📍",hometown,"</br>",
                      "<br><b> Shows: </b><br>",
                      seasons,
                      "</center>"))


#create custom icons using drag queen image link
leafIcons <- icons(
  iconUrl = ~link_image,
  iconWidth = 40, iconHeight = 40,
  iconAnchorX = 22, iconAnchorY = 30,
  shadowWidth = 50, shadowHeight = 50,
  shadowAnchorX = 4, shadowAnchorY = 62
)


#create map using LeafletR
map<-leaflet(map_data) %>% 
  addProviderTiles(providers$CartoDB.Positron)%>%
  setView(lng=-38.6, lat=27.6,  zoom = 3)%>%
  addMarkers(
  lng = ~longitude, 
  lat = ~latitude,
  popup = ~label,
  icon = leafIcons,
  clusterOptions = markerClusterOptions(zoomToBoundsOnClick = TRUE)
)

saveWidget(map, "map-queens.html", selfcontained=TRUE)
