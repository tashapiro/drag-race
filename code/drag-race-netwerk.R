library(tidyverse)
library(ggimage)
library(GGally)
library(network)
library(showtext)
library(sysfonts)

#aesthetics
font_add_google("roboto", "roboto")
showtext_auto()


df<-read.csv("https://raw.githubusercontent.com/tashapiro/drag-race/main/data/season_contestant.csv")
c<-read.csv("https://raw.githubusercontent.com/tashapiro/drag-race/main/data/contestant.csv")
f<-read.csv("https://raw.githubusercontent.com/tashapiro/drag-race/main/data/franchise.csv")
s<-read.csv("https://raw.githubusercontent.com/tashapiro/drag-race/main/data/season.csv")

df<-df|>mutate(link_image = case_when(contestant_id=="Q296"~"https://static.wikia.nocookie.net/logosrupaulsdragrace/images/5/56/VinegarStrokesDRUK1CastMug.jpg",
                                  TRUE ~ link_image))

abbr<-f|>mutate(abbr = case_when(id=="F10"~"Drag Race",
                                 id=="F11"~"All Stars",
                                 id=="F15"~"Canada",
                                 id=="F20"~"UK vs \n The World",
                                 id=="F23"~"Canada vs The World",
                                 id=="F17"~"Down \n Under",
                                 TRUE ~ str_replace(str_replace(name, "Drag Race",""),"RuPaul's","")
),
abbr = trimws(abbr))|>
  select(id, abbr)

s<-s|>left_join(abbr, by=c("franchise_id"="id"))

abbr


sample<-df|>
  filter(franchise_id %in% c("F16","F15","F20","F14","F17","F18","F19","F21") & !season_id %in% c("F14S04","F15S03")
         & id !="F11S07C06")|>
  distinct(season_id, contestant_id)|>
  select(season_id, contestant_id)|>
  left_join(c, by=c("contestant_id"="id"))|>
  rename(from_id=season_id, to_id=name)|>
  select(from_id, to_id)|>
  rbind(s|>filter(franchise_id %in% c("F16","F15","F14","F17","F18","F19","F21") & !id %in% c("F14S04","F15S03","F18S03"))|>select(abbr, id)|>rename(from_id=abbr, to_id=id))|>
  mutate(from_id = case_when(from_id=="F20S01" ~ "UK vs \n The World", TRUE ~from_id))


sample<-df|>
  distinct(season_id, contestant_id)|>
  select(season_id, contestant_id)|>
  left_join(c, by=c("contestant_id"="id"))|>
  rename(from_id=season_id, to_id=name)|>
  select(from_id, to_id)|>
  rbind(s|>filter(id %in% df$season_id & franchise_id!="F11")|>select(abbr, id)|>rename(from_id=abbr, to_id=id))|>
  mutate(from_id = case_when(from_id=="F20S01" ~ "UK vs \n The World", 
                             substr(from_id,1,3)=="F11"~ "All Stars", 
                             TRUE ~from_id))|>
  distinct(from_id, to_id)


#canada vs the world
cvw<-data.frame(
  from_id = rep("Canada vs \n The World",9),
  to_id = c("Anita Wigl'it","Icesis Couture","Kendall Gender","Ra'Jah O'Hara",
            "Rita Baga","Silky Nutmeg Ganache","Stephanie Prince","Vanity Milan",
            "Victoria Scone")
)

sample<-rbind(sample, cvw)

net <- as.network(x = sample, # the network object
                  directed = TRUE, # specify whether the network is directed
                  loops = FALSE, # do we allow self ties (should not allow them)
                  matrix.type = "edgelist" # the type of input
)


get_image<-function(contestant){
  result = as.character(df$id[df$contestant==contestant][1])
  if(is.na(result)){NA}
  else if(contestant=="The Vivienne"){"F14S01C09.png"}
  else{paste0(result,".png")}
}

#create vetex
net %v% "nodecolor" = ifelse(grepl(paste0(abbr$abbr, collapse="|"),network.vertex.names(net)),"Franchise",
                             ifelse(grepl(paste0(s$id, collapse="|"),network.vertex.names(net)),"Season", "Queen"))

net %v% "size" = ifelse(grepl(paste0(abbr$abbr, collapse="|"),network.vertex.names(net)),14,
                        ifelse(grepl(paste0(s$id, collapse="|"),network.vertex.names(net)),8, 2))



net %v% "season_num" = ifelse(grepl(paste0(abbr$abbr, collapse="|"),network.vertex.names(net)),4,
                              ifelse(grepl(paste0(s$id, collapse="|"),network.vertex.names(net)),3, 2))



net %v% "alt" = ifelse(grepl(paste0(abbr$abbr, collapse="|"),network.vertex.names(net)),network.vertex.names(net),
                       ifelse(grepl(paste0(s$id, collapse="|"),network.vertex.names(net)),substr(network.vertex.names(net),4,6),
                              NA))


net %v% "image" = lapply(network.vertex.names(net), get_image)


net %v% "image"

ggnet2(net, color="nodecolor", size="size", edge.color="grey60",
       color.legend = "Type", size.legend="Size")+
  scale_size_discrete(range=c(4,30), guide="none")+
  geom_image(image=net %v% "image", size=0.016, asp=1.5)+
  scale_color_manual(values=c("#642CA9","#EBEBEB","#D6007D"), guide=guide_legend(title="",override.aes = list(size=4)))+
  geom_text(aes(label = net %v% "alt"), size = 3, color="white", fontface="bold")+
  labs(title="International Drag Race NetWerk",
       subtitle="Drag Race Contestants by Franchise & Season",
       caption = "Data and images from RuPaul's Fandom | Graphic @tanya_shapiro", size=10)+
  theme(legend.position="none",
        legend.background = element_rect(fill="black"),
        plot.title=element_text(face="bold",hjust=0.5, size=25),
        plot.subtitle=element_text(hjust=0.5, size=16),
        plot.caption=element_text(size=14),
        plot.background=element_rect(fill="black", color="black"),
        plot.margin=margin(t=20, b=10, r=10, l=10),
        text = element_text(color="white")
  )

ggsave("drag_netwerk.png",height=20,width=34)
