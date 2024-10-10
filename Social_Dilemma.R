#load req library
#install.packages("ggplot2")
#install.packages("dplyr")
#install.packages("tidyr")
#install.packages("scales")
library(ggplot2)
library(dplyr)
library(tidyr)
library(scales)

#load the package
df <- read.csv("Time-Wasters on Social Media.csv",header=TRUE)

#check the data type
str(df)

#display the first few rows
head(df)

####### Final Data cleaning after preprocessing #######

#1.check if there missing value
colSums(is.na(df))


#calc null
miss_val <- sapply(df ,function(x) sum(is.na(x)))
sum(miss_val)

#Remove duplicates
df_clean <- df%>% distinct()

#preview the cleaned data
head(df_clean)

uniq_watchtime <- unique(df$Watch.Time)
uniq_watchtime

#repair the frequency and watch time col
# Convert the Watch.Time column to POSIXct
df_clean$Watch.Time <- as.POSIXct(df_clean$Watch.Time, format="%I:%M %p")

# Format the Watch.Time column to only show the time in 24-hour format
df_clean$Watch.Time <- format(df_clean$Watch.Time, "%H:%M")

# Print the dataframe to see the changes
print(df_clean)

# Reclassify Frequency based on correct Watch Time
df_clean <- df_clean %>%
  mutate(Frequency = case_when(
    Watch.Time >= 5 & Watch.Time < 12  ~ "Morning",   # 5 AM to 12 PM
    Watch.Time >= 12 & Watch.Time < 17 ~ "Afternoon", # 12 PM to 5 PM
    Watch.Time >= 17 & Watch.Time < 21 ~ "Evening",   # 5 PM to 9 PM
    Watch.Time >= 21 | Watch.Time < 5  ~ "Night"      # 9 PM to 5 AM
  ))



# Print the dataframe to see the changes
print(df_clean)

#save the data in a new csv file
write.csv(df_clean,"Time wasters cleaned.csv",row.names = FALSE)

##### Data Analysis #####

#Basic summary statistics
summary(df_clean)
#the data is cleaaaan

#cor matrix
cor_matrix <- cor(df_clean%>% select(where(is.numeric)))
print(cor_matrix)

#vizual the cor as heatmap
heatmap(cor_matrix,main="col matrix", col=heat.colors(50),scale="none")



#pivot table to show the addiction &productivity loss with platform and gender
pivot_table <- df_clean%>%
  group_by(Platform,Gender)%>%
  summarize(Avg_addic= mean(Addiction.Level,na.rm = TRUE),
            Avg_Prod_Loss = mean(ProductivityLoss,na.rm=TRUE))%>%
  pivot_wider(names_from = Gender, values_from = c(Avg_addic,Avg_Prod_Loss))

print(pivot_table)


#pivot table to show the satisfaction &self control loss with platform and gender
pivot_table2 <- df_clean%>%
  group_by(Platform,Watch.Reason)%>%
  summarize(Avg_satisfaction= mean(Satisfaction,na.rm = TRUE),
            Avg_self_control = mean(Self.Control,na.rm=TRUE))%>%
  pivot_wider(names_from = Watch.Reason, values_from = c(Avg_satisfaction,Avg_self_control))

print(pivot_table2)



# Custom mode function
get_mode <- function(x) {
  uniq_val <- unique(x)
  uniq_val[which.max(tabulate(match(x, uniq_val)))]
}

#pivot table to show the addiction &productivity loss with platform and gender
pivot_table3 <- df_clean %>%
  group_by(Platform, Frequency) %>%
  summarise(
    Most_used_device = get_mode(DeviceType),
    Biggest_Watch_reason = get_mode(Watch.Reason),
    Highest_Watch_time = get_mode(Watch.Time),
  ) %>%
  pivot_wider(names_from = Frequency, values_from = c(Biggest_Watch_reason, Highest_Watch_time))

print(pivot_table3)



##########some visuals###########


# Age distribution
ggplot(df_clean, aes(x=Age)) +
  geom_histogram(binwidth=5, fill="blue", color="black") +
  labs(title="Age Distribution of Social Media Users")

# Addiction Level distribution
ggplot(df_clean, aes(x=Addiction.Level)) +
  geom_histogram(binwidth=1, fill="red", color="black") +
  labs(title="Addiction Level Distribution")

# Bar chart for platforms
ggplot(df_clean, aes(x=Platform)) +
  geom_bar(fill="purple", color="black") +
  theme_minimal() +
  labs(title="Platform Usage Frequency")

# Group by Platform and calculate the mean of Addiction Level and Productivity Loss
platform_analysis <- df_clean %>%
  group_by(Platform) %>%
  summarise(Mean_Addiction = mean(Addiction.Level), Mean_ProductivityLoss = mean(ProductivityLoss))

# Bar plot for Platform vs Addiction Level
ggplot(platform_analysis, aes(x=Platform, y=Mean_Addiction)) +
  geom_bar(stat="identity", fill="steelblue", c="black") +
  theme_minimal() +
  labs(title="Average Addiction Level by Platform")

# Analyze Watch Reason and Addiction Level
wath_reason_analysis <- df_clean %>%
  group_by(Watch.Reason) %>%
  summarise(Mean_Addict = mean(Addiction.Level))

# Bar plot for Watch Reason vs Addiction Level
ggplot(watch_reason_analysis, aes(x=Watch.Reason, y=Mean_Addict)) +
  geom_bar(stat="identity", fill="firebrick1", c="black") +
  theme_minimal() +
  labs(title="Average Addiction Level by Watch Reason")

# Satisfaction and Platform
satisf_plat <- df_clean %>%
  group_by(Platform) %>%
  summarise(Mean_Satisfaction = mean(Satisfaction))

ggplot(satisf_plat, aes(x=Platform, y=Mean_Satisfaction)) +
  geom_bar(stat="identity", fill="green") +
  theme_minimal() +
  labs(title="Average Satisfaction Level by Platform")

# Calculate the average income by location, and gender
Income_by_loc_and_gender <- df_clean %>%
  group_by(Location, Gender) %>%
  summarise(Avg_Income = mean(Income,na.rm=TRUE))

#Avg income by location and gender
ggplot(Income_by_loc_and_gender, aes(x = Location, y = Avg_Income, fill = Gender)) +
  geom_bar(stat = "identity", position = "dodge") +
  labs(title = "Average Income by Location and Gender",x = "Location",y = "Average Income") +
  theme_minimal() +
  theme(axis.text.x = element_text(angle = 45, hjust = 1))


# Calculate the average income by profession, and gender
Income_by_prof_and_gender <- df_clean %>%
  group_by(Profession, Gender) %>%
  summarise(Avg_Income = mean(Income,na.rm=TRUE))

#Avg income by profession and gender
ggplot(Income_by_prof_and_gender, aes(x = Profession, y = Avg_Income, fill = Gender)) +
  geom_bar(stat = "identity", position = "dodge") +
  labs(title = "Average Income by profession and Gender",x = "profession",y = "Average Income") +
  theme_minimal() +
  theme(axis.text.x = element_text(angle = 45, hjust = 1))


#####Box plots for all numeric values#####

# Select only numeric columns from the dataset
numeric_columns <- df_clean %>%
  select_if(is.numeric)

# Convert the data to long format
numeric_long <- numeric_columns %>%
  gather(key = "Variable", value = "Value")

# Create box plots for each numeric variable and separate them using facet_wrap
ggplot(numeric_long, aes(x = "", y = Value)) +
  geom_boxplot(fill = "lightblue") +
  facet_wrap(~ Variable, scales = "free") +  # Separate box plots for each variable
  labs(title = "Box Plots for All Numeric Variables", x = "", y = "Value") +
  scale_y_continuous(labels = comma) + # to remove e(scientific notation)
  theme_minimal()


#Normalization  using diff methods

###log tricks method
df_clean$Satisfaction <- log(df_clean$Satisfaction)
df_clean$Age <- log(df_clean$Age)

###Using cox box method

#cox box function
cox_box <- function(x, lambda){
  if (lambda==0){
    return(log(x))
  }else{
    return((x^lambda-1)/lambda)
  }
}

df_clean$Self.Control <- cox_box(df_clean$Self.Control, lambda = 0.5)
df_clean$ProductivityLoss <- cox_box(df_clean$ProductivityLoss, lambda = 0.5)

#sqrt tricks method
df_clean$Addiction.Level <- sqrt(df_clean$Addiction.Level)

