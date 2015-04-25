##############################################################################
#
# This block of code will run when the application launches
# It will one once.
# Useful for loading/downloading data so any reactive parts will not cause
# a re-downloading of data or re-loading of data
#
###############################################################################
# server.R

library(RCurl)
library(ggplot2)
library(stringr)
library(reshape2)
library(magrittr)
library(dplyr)
library(scales)
library(shiny)
library(foreign)
library(RColorBrewer)

make_function_exp_growth <- function(y_0, r) {
    # This function should take a numeric vector and return a numeric vector
    function(t) {
        y_0 * exp(r * t)
    }
}

# url <- "https://raw.githubusercontent.com/cmrivers/ebola/master/country_timeseries.csv"
#
# data <- getURL(url, ssl.verifypeer = FALSE)
# df <- read.csv(textConnection(data))

# I hard coded this
df <- read.csv('/home/dchen/git/2015-04-25-rstatsnyc-ebola/data/country_timeseries.csv', stringsAsFactors = FALSE)

#Drop the Date col
df <- df[, !names(df) %in% c("Date")]

#Convert to long table (day, type_place, count)
long <- na.omit(melt(df, id.vars = c("Day")))
#Split by _
long[, c("type", "place")] <- colsplit(long$variable, "_", c("type", "place"))

long <- long[,-2] #Drop old _-delimited col

long$type[long$type == "Case"] <- "Cases"
names(long)[1] <- "absolute.days"
names(long)[2] <- "count"

long <- long %>%
    group_by(place) %>%
    mutate(relative.days = absolute.days - min(absolute.days)) %>%
    mutate(count = as.numeric(count))

all <- unique(long$place)
c_colors <- brewer.pal(length(all), 'Set1')
names(c_colors) <- all

theme_set(theme_minimal())



shinyServer(function(input, output) {
    ###########################################################################
    #
    # This block of code will run when a user visits the application
    #
    ###########################################################################
    data_plot <- reactive({
        ###########################################################################
        #
        # Any render and ractive call will run when there is a change to a widget
        # that is mapped to an output
        #
        ###########################################################################

        # copy the df so the name is same as before
        df_plot <- long

        # get list of countries from checkbox
        selection <- input$countries
        if("All" %in% input$countries || length(input$countries) == 0){
            # if nothing is selected, select all countries
            selection <- all
        }else{
            selection <- input$countries
        }
        # subset data based on selection
        df_plot <- df_plot %>%
            filter(place %in% selection)

        df_plot <- df_plot[df_plot$absolute.days %in%
                               c(input$time_range[1]:input$time_range[2]), ]
    })

    output$countriesList <- renderUI({
        checkboxGroupInput("countries",
                           label = h3("Countries to display"),
                           choices = all,
                           selected = "All")
    })

    output$time_range <- renderUI({
        sliderInput("time_range", label = "Subset 'time'",
                    min = min(df_plot$absolute.days),
                    max = max(df_plot$absolute.days),
                    value = c(min, max))
    })

    plot <- reactive({
        # unused from ui
        y_0 <- input$y_0
        r <- input$r
        t <- input$t
        exp_growth_line <- make_function_exp_growth(y_0, r)
        #

        type = paste0(input$date_offset, ".days")
        g <- ggplot(data = data_plot(),
                    aes_string(x = type, y = "count",
                               group = "place", color = "place")) +
            geom_point() + geom_line() +
            facet_grid(~ type) +
            scale_x_continuous(name = "Days after first report") +
            scale_y_continuous(name = "Counts") +
            scale_colour_manual(name = "Country", values = c_colors) +
            ggtitle("Number of observations for days after first report") #+
            # stat_function(fun=exp_growth_line, n = 300)

        if(!input$log){
            return(g)
        } else{
            h <- g + scale_y_continuous(trans = log10_trans()) +
                scale_y_log10(name = "Counts") +
                ggtitle("Number of observations for days after first report (log10 scale)")
            return(h)
        }
    })

    output$plot <- renderPlot({
        print(plot())
    })
})