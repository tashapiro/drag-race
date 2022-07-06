library(reactablefmtr)
library(tidyverse)
library(htmltools)
library(htmlwidgets)


#import data
df_episode_outcomes <- read.csv("../data/episode_outcome.csv")
df_sc<- read.csv("../data/season_contestant.csv")
df_season <-read.csv("../data/season.csv")

#aggregate results from episode outcomes
results<-df_episode_outcomes|>
  distinct(episode_id, season_contestant_id, outcome)|>
  mutate(counter =1)|>
  filter(outcome %in% c("ELIM","BTM","LOW","SAFE","HIGH","WIN"))|>
  group_by(season_contestant_id)|>
  summarise(challenges = n(),
            btm = sum(counter[outcome %in% c("BTM","ELIM")]),
            low = sum(counter[outcome=="LOW"]),
            safe = sum(counter[outcome=="SAFE"]),
            high = sum(counter[outcome=="HIGH"]),
            win = sum(counter[outcome=="WIN"]),
            #percentages
            btm_perc = round(btm/challenges,4),
            low_perc = round(low/challenges,4),
            safe_perc = round(safe/challenges,4),
            high_perc = round(high/challenges,4),
            win_perc = round(win/challenges,4)
            )
  

data <- df_sc|>
  filter(link_image!="")|>
  left_join(df_season|>select(id, franchise_name, season_num), by=c("season_id"="id"))|>
  mutate(dummy_id = toupper(str_replace_all(contestant," ","")),
         franchise_name = str_replace(franchise_name,"RuPaul's ",""),
         contestant = case_when(contestant=="Ben De La Creme"~"BenDeLaCreme",TRUE ~ contestant),
         franchise_name = case_when(!franchise_name %in% c("Drag Race","Drag Race vs The World") ~str_replace(franchise_name,"Drag Race",""), TRUE ~ franchise_name),
         franchise_name = str_replace(franchise_name,"'s",""))|>
  left_join(results, by=c("id"="season_contestant_id"))|>
  mutate(link_fandom = paste0('https://rupaulsdragrace.fandom.com/wiki/',str_replace_all(contestant," ","_")))|>
  select(link_image, contestant, hometown, age, franchise_name, season_num, challenges, rank, btm_perc, low_perc, safe_perc, high_perc, win_perc, link_fandom)|>
  filter(win_perc!="")

pal<-colorRampPalette(c("#4D0076","#FF3EB2"))
pal_greens<-colorRampPalette(c("#017640", "#75EE29"))

ru_table<-reactable(data,
          searchable=TRUE,
          theme = reactableTheme(
            headerStyle = list(borderColor='#000000')
          ),
          defaultSorted = list(win_perc = "desc", high_perc = "desc"),
          columnGroups = list(
            colGroup(name="Contestant", columns=c("contestant","hometown","age")),
            colGroup(name="Show", columns=c("franchise_name","season_num","challenges", "rank")),
            colGroup(name="Challenge Outcomes", columns=c("btm_perc","low_perc","safe_perc","high_perc","win_perc"))
          ),
          defaultColDef = colDef(
            style = color_scales(data, span= 9:13, colors = pal(8)),
            footerStyle = list(fontSize=13),
            vAlign="center"
          ),
          columns = list(
            link_fandom = colDef(show=FALSE),
            link_image = colDef(name="", cell=embed_img(height=60, width=60)),
            contestant = colDef(name='NAME', html=TRUE, 
                                style =  list(fontWeight = 900), 
                                vAlign="center", 
                                cell= function(value,index){
                                  sprintf('<a style=text-decoration:none;color:#0BA3E9; href="%s" target="_blank">%s</a>', data$link_fandom[index], value)
                                }),
            hometown = colDef(name="HOMETOWN"),
            age = colDef(name="AGE",align="center", footer = "Age at time of competition"),
            franchise_name = colDef(name="SHOW"),
            season_num = colDef(name="SEASON", align="center"),
            rank = colDef(name="RANK", align="center"),
            challenges = colDef(name="CHLS", footer = "Challenges completed", align="center", 
                                cell = icon_sets(data, icons=c("crown"),colors= pal_greens(4))),
            btm_perc = colDef(name="BTM %", align="center", format = colFormat(percent=TRUE)),
            low_perc = colDef(name="LOW %", align="center", format = colFormat(percent=TRUE)),
            safe_perc = colDef(name="SAFE %", align="center", format = colFormat(percent=TRUE)),
            high_perc = colDef(name="HIGH %", align="center", format = colFormat(percent=TRUE)),
            win_perc = colDef(name="WIN %", align="center", format = colFormat(percent=TRUE))
          )
          )%>%
  google_font(font_family="Chivo", font_weight=300)

ru_table

table_html<-htmlwidgets::prependContent(
  ru_table,
  htmltools::tags$h1("RuPaul's Drag Queens",
                     style=paste0(
                       "font-family:","Chivo;", 
                       "font-weight: bold !important;",
                       "font-size: 28px;" ,
                       "margin-left: 20px;"
                     )),
  htmltools::tags$h2("Drag queens featured in RuPaul's Drag Race or related franchises. Data from RuPaul's Fandom Wiki & Wikipedia.",
                     style = paste0(
                       "font-family:", "Chivo;" ,
                       "font-size: 20px;" ,
                       "font-weight: normal;" ,
                       "margin-left: 20px;",
                       "margin-top: -10px;"
                     ))
)

table_html

saveWidget(table_html, "../html/drag_queens.html", selfcontained=TRUE)
