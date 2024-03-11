library(mlr3mbo)
library(mlr3)
library(mlr3learners)
library(bbotk)
library(data.table)
library(tibble)

source("mlr3mbo-demo/utils/processing.R") # for colab, adjust this if run locally

propose_experiment <- function(data, metadata) {
  set.seed(metadata$seed)
  data <- as.data.table(data) # data.csv is queried `table`

  # retrieve this from metadata parameter_ranges
  search_space <- ParamSet$new(params = list())
  # Loop through metadata$parameter_info
  for (param_name in names(metadata$parameter_info)) {
    print(param_name)
    param_info <- metadata$parameter_info[[param_name]]
    param_range <- metadata$parameter_ranges[[param_name]]

    print(param_info)
    print(param_range)

    # Check if param_info is 'object', if so, no need to convert to numeric
    if (param_info == "object") {
      search_space$add(ParamFct$new(id = param_name, levels = param_range))
      next
    }

    # Remove the parentheses and split the string at the comma
    param_range_split <- strsplit(gsub("[()]", "", param_range), ",")[[1]]

    # Convert the results to appropriate type
    if (param_info == "integer") {
      lower <- as.integer(param_range_split[1])
      upper <- as.integer(param_range_split[2])
    } else if (param_info == "float") {
      lower <- as.numeric(param_range_split[1])
      upper <- as.numeric(param_range_split[2])
    }

    # Check if lower or upper is NA
    if (is.na(lower) | is.na(upper)) {
      print(paste("lower or upper is NA for param_name:", param_name))
      next
    }

    # Add the parameter to the search space
    if (param_info == "float") {
      values <- seq(lower, upper, by=metadata$to_nearest)
      search_space$add(ParamDbl$new(id = param_name,
                                    lower = lower, upper = upper)) 
    } else if (param_info == "integer") {
      search_space$add(ParamInt$new(id = param_name,
                                    lower = lower, upper = upper))
    }
  }
  # Initialize an empty ParamSet for the codomain
#   codomain <- ParamSet$new(params = list())
  codomain <- ParamSet$new(params = list())

  # Loop through metadata$output_column_names
  for (i in seq_along(metadata$output_column_names)) {
    output_name <- metadata$output_column_names[i]
    direction <- metadata$directions[i]
    # Add the output to the codomain
    codomain$add(ParamDbl$new(id = output_name, tags = direction))
  }

  archive <- Archive$new(search_space = search_space, codomain = codomain)

  # Use parameter_info in the subset operation
  archive$add_evals(xdt = data[, names(metadata$parameter_info), with = FALSE],
                    ydt = data[, metadata$output_column_names, with = FALSE])


  print("Model archive so far: ")
  print(archive)
  # Determine the number of objectives
  num_objectives <- length(metadata$output_column_names)

  if (num_objectives == 1) {
    surrogate <- srlrn(lrn("regr.ranger"), archive = archive)
    acq_function <- acqf("ei", surrogate = surrogate)
  } else {
    surrogate <- srlrn(list(default_rf(), default_rf()), archive = archive)
    acq_function <- acqf("ehvi", surrogate = surrogate)
  }
  # single or multi
  acq_optimizer <- acqo(opt("random_search", batch_size = 1000),
                        terminator = trm("evals", n_evals = 1000),
                        acq_function = acq_function)

  

  q <- as.integer(metadata$num_random_lines)
#   print(q)
#   print(acq_function)
#   print(acq_optimizer)
#   print(data)

  result <- add_evals_to_archive(archive, acq_function,
                                 acq_optimizer, data, q, metadata)

  candidate <- result[[1]]
  archive <- result[[2]]
  acq_function <- result[[3]]

  # print(result)

  x2 <- candidate[, names(metadata$parameter_info), with = FALSE]
  print("New candidates: ")
  print(x2)
  # print("Archive : ")
  # print(archive)

  x2_dt <- as.data.table(x2)
  data <- rbindlist(list(data, x2_dt), fill = TRUE)

#   print("!! Full data after adding new candidates before adding calculated column: ")
#   print(data)

  # Determine the number of columns to exclude
  num_exclude <- if (length(metadata$output_column_names) > 1) 3 else 2

  # Ensure num_exclude does not exceed the number of columns in data
  num_exclude <- min(num_exclude, ncol(data))

  # Exclude the last num_exclude columns from the calculation
  data[, metadata$calculated_column := 100 - Reduce(`+`, .SD),
       .SDcols = -((ncol(data) - num_exclude + 1):ncol(data))]

  # Reorder the columns to move Cu to the left-most position
  setcolorder(data, c(metadata$calculated_column,
                      setdiff(names(data), metadata$calculated_column)))
  print("!! Full data after adding new candidates and calculated column: ")
  print(data)

  # Define the directory path
  dir_path = paste0(metadata$bucket_name, "/",
                    metadata$user_id, "/",
                    metadata$table_name, "/", metadata$batch_number)
  # Save the data table as a CSV file in the same directory
  data.table::fwrite(data, paste0(dir_path, "/output.csv"))
  print(paste0("mlr3mbo proposals finished. Results file is saved at: ",
               dir_path))
  return(data)

}