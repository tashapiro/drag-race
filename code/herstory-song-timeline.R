library(tidyverse)
library(showtext)
library(sysfonts)
library(ggimage)

#read data
df_songs <- read.csv("data/song.csv")

df<-df_songs|>
  #not all songs have Spotify info, remove NAs
  filter(!is.na(spotify_track_id))|>
  #format album year and album decade
  mutate(year = as.integer(substr(album_release_date,1,4)),
         decade = year - (year %% 10))

#find top artist per decade
artist_decade<-df|>
  group_by(spotify_artist, spotify_artist_id, decade)|>
  summarise(songs=n_distinct(id))|>
  arrange(-decade, -songs)|>
  group_by(decade)|>
  slice_max(order_by=songs)|>
  mutate(artists = n())

by_decade<-df|>
  #summarize by decade
  group_by(decade)|>
  #get unique song count
  summarise(songs = n_distinct(id))|>
  #join to see top artist per decade, remove if there are ties
  left_join(artist_decade|>filter(artists==1), by="decade")|>
  #rename
  rename(top_artist=spotify_artist, songs=songs.x, top_songs=songs.y)|>
  arrange(-decade)

by_decade$decade<-factor(by_decade$decade)


#aesthetics
pal_acc = '#720091'
pal_bg =  "black"
pal_col = '#F02DB5'

#add font chivo
font_add_google("roboto", "roboto")
showtext_auto()

#timeline notes dataframe
note <-data.frame(
  decade = c(8.9, 4, 6.3),
  pos = c(-36, -32, -45),
  label = c("First sesaon of \n RuPaul's Drag Race \n airs in 2009",
            "RuPaul born in 1960",
            "RuPaul releases first album \n (Supermodel of The World) \n in 1993")
)

#create data frame of artist images
images<-by_decade|>filter(!is.na(top_artist))|>
  mutate(image_name = tolower(str_replace_all(top_artist," ","_")),
         image_path=paste0("images/artists/",image_name,".png"))

#plot
ggplot(by_decade, aes(x=decade, y=songs))+
  geom_segment(mapping=aes(x=decade, xend=decade, y=0, yend=songs), color=pal_col, size=9)+
  #timeline line
  geom_segment(data=data.frame(x1=factor(1930), x2=factor(2030), y=-3), mapping=aes(x=x1, xend=x2, y=y, yend=y), color="white", arrow=arrow(length=unit(0.1, "inches"), ends="both"))+
  #unique song count labels above bars
  geom_text(mapping=aes(label=songs, x=decade, y=songs+3), size=3.5, color="white", fontface="bold")+
  #timeline notes
  geom_segment(data=note, mapping=aes(x=decade, xend=decade, y=-3, yend=pos+3), color="white", linetype="dotted", size=0.5, alpha=0.8)+
  geom_label(data=note, mapping=aes(label=label, x=decade, y=pos), size=3, color="white", fill="black", label.size = NA, fontface="italic")+
  #decade year labels below timeline
  geom_label(mapping=aes(label=decade, x=decade, y=-3), size=3.5, fill="black", color="white")+
  #add top artist per decade
  geom_image(data=images, mapping=aes(image=image_path, x=decade, y=-11), color="white", size=0.0425)+
  geom_image(data=images, mapping=aes(image=image_path, x=decade, y=-11), size=0.04)+
  geom_label(data=images, mapping=aes(label=top_artist, x=decade, y=-17.5), fill="black", color="white",size=2.65, label.size=NA)+
  #annotation about songs
  annotate(geom="text", x=4.2, y=45, label="Total songs by album \n release decade", color="white", size=3)+
  geom_curve(x=4.2, y=40, xend=4.8, yend=28, arrow=arrow(length=unit(0.1, "inch")), size=0.2, color="white", curvature=0.15)+
  #annotation about top artist
  annotate(geom="text",label="TOP \nARTISTS", color="white", x=1, y=-12, size=3, fontface="bold")+
  scale_y_continuous(limits=c(-50, 102))+
  labs(x="", 
       y="",
       title = "Drag Race HERStory",
       subtitle = "Analysis of songs used in Drag Race lip syncs",
       caption = "Data from Wikipedia & Spotify. Lip syncs from all franchises as of July 2022."
       )+
  theme_void()+
  theme(text=element_text(color="white"), 
        plot.background = element_rect(fill=pal_bg),
        plot.caption =element_text(size=7),
        plot.title = element_text(hjust=0.5, color="white", face="bold", size=18),
        plot.subtitle = element_text(hjust=0.5, color="white", size=13),
        plot.margin = margin(t=15, b=10, r=10, l=10))


ggsave("herstory.png", width=8, height=8)
