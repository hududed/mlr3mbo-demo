# %%
library(mlr3mbo)
library(mlr3)
library(mlr3learners)
library(bbotk)
library(data.table)
library(tibble)
source("utils/batch.R")
#%%
file = 'CuAlMnNi-data.csv'
data <- as.data.table(read.csv(file))
data

# %%
# clean col names
names(data) <- gsub("\\.{2}.*", "", names(data))  # remove everything after the first two dots
names(data) <- gsub("[^[:alnum:]_.]", "", names(data))  # remove non-alphanumeric characters except dots and underscores
names(data) <- gsub("^_", "", names(data))  # remove leading underscores
names(data) <- gsub("_$", "", names(data))  # remove trailing underscores
names(data) <- gsub("\\.", "_", names(data))  # replace dots with underscores

#%%
column_names <- names(data)
print(column_names)
#%%
selected_columns <- c("Al", "Mn", "Ni", "DSC_Af")  # replace with your column names
dt <- data[, ..selected_columns]
dt

# %%

metadata <- list(
  bucket_name = "my_bucket",  # The name of the bucket where the archive will be saved
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
    Al = "(15, 19)",  # The range of the Al parameter
    Mn = "(8,13)",  # The range of the Mn parameter
    Ni = "(0,3)"  # The range of the Ni parameter
    # Add more ranges as needed
  ),
  output_column_names = c("DSC_Af"),  # The names of the output columns
  direction = "minimize",  # The direction of the optimization ("minimize" or "maximize")
  num_random_lines = 30,  # The number of random lines to generate
  to_nearest = 0.2  # The value to round to
)

#%%
# Run the experiment function
result <- experiment(dt, metadata)

