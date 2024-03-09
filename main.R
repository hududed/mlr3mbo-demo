# %%
library(mlr3mbo)
library(mlr3)
library(mlr3learners)
library(bbotk)
library(data.table)
library(tibble)
source("utils/propose.R") # for colab, adjust this if run locally
#%%
file <- "CuAlMnNi-multi.csv"
data <- as.data.table(read.csv(file))
data

# %%
# clean col names
# remove everything after the first two dots
names(data) <- gsub("\\.{2}.*", "", names(data))
# remove non-alphanumeric characters except dots and underscores
names(data) <- gsub("[^[:alnum:]_.]", "", names(data))
names(data) <- gsub("^_", "", names(data))  # remove leading underscores
names(data) <- gsub("_$", "", names(data))  # remove trailing underscores
names(data) <- gsub("\\.", "_", names(data))  # replace dots with underscores

#%%
column_names <- names(data)
print(column_names)
#%%
# Specify your input and output columns
input_columns <- c("Al", "Mn", "Ni")
# if single output, use e.g. c("DSC_Af")
output_columns <- c("DSC_Af")
# if single output, use e.g. c("minimize"), length must match output_columns!
directions <- c("minimize")

# Concatenate input and output columns
selected_columns <- c(input_columns, output_columns)
# Subset the data
dt <- data[, ..selected_columns]
dt
# %%

metadata <- list(
  seed = 42,
  # The name of the bucket where the archive will be saved
  bucket_name = "my_bucket",
  user_id = "my_id",  # The user ID
  table_name = "CuAlMnNi",  # The name of the table
  batch_number = "1",  # The batch number
  parameter_info = list(
    Al = "float",  # The type of the Al parameter
    Mn = "float",  # The type of the Mn parameter
    Ni = "float"  # The type of the Ni parameter
    # Add more parameters as needed
  ),
  parameter_ranges = list(
    Al = "(14, 20)",  # The range of the Al parameter
    Mn = "(7,15)",  # The range of the Mn parameter
    Ni = "(0,5)"  # The range of the Ni parameter
    # Add more ranges as needed
  ),
  output_column_names = output_columns,  # The names of the output columns
  # Ignored from the search space, but calculated in post-processing
  calculated_column = "Cu",
  # The direction of the optimization ("minimize" or "maximize")
  directions = directions,
  num_random_lines = 10,  # The number of random lines to generate
  to_nearest = 0.2  # The value to round to
)

#%%
# Run the experiment function
result <- propose_experiment(dt, metadata)
# %%



# Import functions (see https://github.com/hududed/mlr3mbo-demo.git for the source files)
# FOR UPDATES MAKE SURE THIS IS SOURCED, NOT mlr3mbo-demo/utils/batch.R!
source("utils/update.R") # for colab, adjust this if run locally

# %%
# Please upload the new updated file in your session (See Folder icon on the left pane)
file <- 'updated_2.csv'
data <- as.data.table(read.csv(file))
data
# %%
metadata <- list(
  seed = 42,  # The seed for reproducibility
  # RECREATE FIRST BATCH FOLDERS FOLLOWING THIS STRUCTURE, AND UPLOAD THE ASSOCIATED THREE RDS FILES there
  # e.g. my_bucket/user_id/CuAlMnNi/1
  bucket_name = "my_bucket",  # The name of the bucket where the archive will be saved
  user_id = "my_id",  # The user ID
  table_name = "CuAlMnNi",  # The name of the table
  parameter_info = list(
    Al = "float",  # The type of the Al parameter
    Mn = "float",  # The type of the Mn parameter
    Ni = "float"  # The type of the Ni parameter
  ),
  parameter_ranges = list(
    Al = "(14, 20)",  # The range of the Al parameter
    Mn = "(7,15)",  # The range of the Mn parameter
    Ni = "(0,5)"  # The range of the Ni parameter
    # Add more ranges as needed
  ),
  output_column_names = output_columns,  # The names of the output columns
  calculated_column = "Cu", # This column is ignored from the search space, but calculated in post-processing
  directions = directions,  # The direction of the optimization ("minimize" or "maximize")
  num_random_lines = 10,  # The number of random lines to generate
  to_nearest = 0.2,  # The value to round to

  # CHANGE THIS
  # If you are running batch 2, it will expect three RDS files in my_bucket/user_id/CuAlMnNi/1
  # If you are running batch 3, it will expect three RDS files in my_bucket/user_id/CuAlMnNi/2
  batch_number = "2"  # The batch number for the second batch
)

# %%
# Run the experiment (FOR UPDATES MAKE SURE mlr3mbo-demo/utils/update.R is sourced, not batch.R)
new_result <- update_experiment(data, metadata)
# %%
