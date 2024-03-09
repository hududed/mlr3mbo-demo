library(mlr3mbo)
library(mlr3)
library(mlr3learners)
library(bbotk)
library(data.table)
library(tibble)

# Define the transformation functions
remove_after_dots <- function(names) gsub("\\.{2}.*", "", names)
remove_non_alnum <- function(names) gsub("[^[:alnum:]_.]", "", names)
remove_leading_underscore <- function(names) gsub("^_", "", names)
remove_trailing_underscore <- function(names) gsub("_$", "", names)
replace_dots <- function(names) gsub("\\.", "_", names)
capitalize <- function(names) paste0(toupper(substr(names, 1, 1)),
                                     tolower(substr(names, 2, nchar(names))))

# Create a list of transformations
transformations <- list(remove_after_dots, remove_non_alnum, 
                        remove_leading_underscore, remove_trailing_underscore, 
                        replace_dots, capitalize)

# Apply the transformations
clean_names <- function(names, transformations) {
  for (transformation in transformations) {
    names <- transformation(names)
  }
  return(names)
}

round_to_nearest <- function(x, metadata) {
  to_nearest = metadata$to_nearest
  if (is.data.table(x) || is.data.frame(x)) {
    x = lapply(x, function(col) {
      if (is.numeric(col)) {
        return(round(col / to_nearest) * to_nearest)
      } else {
        return(col)
      }
    })
    x = setDT(x) # Convert the list to a data.table
  } else if (is.numeric(x)) {
    x = round(x / to_nearest) * to_nearest
  }
  return(x)
}
save_archive <- function(archive, acq_function, acq_optimizer, metadata) {
    # Get the current timestamp
    timestamp = format(Sys.time(), "%Y%m%d%H%M%S")

    # Define the directory path
    dir_path = paste0(metadata$bucket_name, "/", metadata$user_id, "/", metadata$table_name, "/", metadata$batch_number)
    
    # Create the directory if it doesn't exist
    if (!dir.exists(dir_path)) {
        dir.create(dir_path, recursive = TRUE)
    }
    
    # Save the objects to files
    saveRDS(archive, paste0(dir_path,  "/archive-", timestamp, ".rds"))
    saveRDS(acq_function, paste0(dir_path, "/acqf-", timestamp, ".rds"))
    saveRDS(acq_optimizer, paste0(dir_path, "/acqopt-", timestamp, ".rds"))
    # Print the directory path
    print(paste("RDS files saved in directory:", dir_path))
}
update_and_optimize <- function(acq_function, acq_optimizer, tmp_archive, candidate_new, lie, metadata) {
    acq_function$surrogate$update()
    acq_function$update()

    # print(">>>>>>>> UPDATE_AND_OPTIMIZE <<<<<<<<<<<")
    # print("BEFORE ADD acq_function$surrogate$archive$data:")
    # print(acq_function$surrogate$archive$data)

    tmp_archive$add_evals(xdt = candidate_new, xss_trafoed = transform_xdt_to_xss(candidate_new, tmp_archive$search_space), ydt = lie)
    # print("AFTER ADD acq_function$surrogate$archive$data:")
    # print(acq_function$surrogate$archive$data)

    candidate_new = acq_optimizer$optimize()
    # Round the candidates to the nearest 0.2
    candidate_new = round_to_nearest(candidate_new, metadata)
    return(candidate_new)
}
add_evals_to_archive <- function(archive, acq_function, acq_optimizer, data, q, metadata) {
    lie <- data.table()
    liar <- min
    acq_function$surrogate$update()
    acq_function$update()
    candidate <- acq_optimizer$optimize()
    # Round the candidates to the nearest 0.2
    candidate <- round_to_nearest(candidate, metadata)

    # print("########## INIT ADD_EVALS_TO_ARCHIVE ##########")
    # print("FIRST CANDIDATE PROPOSED:")
    # print(candidate)
    tmp_archive = archive$clone(deep = TRUE)
    acq_function$surrogate$archive = tmp_archive

    # print("acq_function$surrogate$archive$data:")
    # print(acq_function$surrogate$archive$data)

    # print("acq_function$surrogate$archive$cols_y:")
    # print(acq_function$surrogate$archive$cols_y)

    # Apply the liar function to each column in archive$cols_y
    for (col_name in archive$cols_y) {
        lie[, (col_name) := liar(archive$data[[col_name]])]
    }

    # print("After applying liar function to each column in archive$cols_y:")
    # print(lie)

    # print("Before lie[, archive$cols_y := liar(archive$data[[archive$cols_y]])]")
    # # lie[, archive$cols_y := liar(archive$data[[archive$cols_y]])]
    # print("After lie[, archive$cols_y := liar(archive$data[[archive$cols_y]])]")


    # lie[, archive$cols_y := liar(archive$data[[archive$cols_y]])]
    # candidate_new = candidate
    
    # Check if lie is a data.table
    if (!is.data.table(lie)) {
        stop("lie is not a data.table")
    }
    candidate_new = candidate
    for (i in seq_len(q)[-1L]) {
      candidate_new <- update_and_optimize(acq_function, acq_optimizer,
                                           tmp_archive, candidate_new,
                                           lie, metadata)
      candidate <- rbind(candidate, candidate_new)
    }
    candidate_new <- update_and_optimize(acq_function, acq_optimizer,
                                         tmp_archive, candidate_new,
                                         lie, metadata)

    print("New candidates after constant liar batch loop: ")
    print(candidate)
    
    # Iterate over each column in candidate
    for (col in names(candidate_new)) {
        # If the column is numeric, round and format it
        if (is.double(candidate_new[[col]])) {
            candidate_new[[col]] <- format(round(candidate_new[[col]], 2), nsmall = 2)
        }
    }
    
    save_archive(archive, acq_function, acq_optimizer, metadata)
    return(list(candidate, archive, acq_function))
    }


load_file <- function(files, pattern) {
    # Check if there are files that match the pattern
    matched_files = grep(pattern, files, value = TRUE)
    if (length(matched_files) == 0) {
        stop(paste("No", pattern, "files found"))
    }

    # Filter for the latest file
    latest_file = max(matched_files)

    # Check if latest_file is a valid file
    if (!file.exists(latest_file)) {
        stop(paste("File does not exist:", latest_file))
    }

    # Load the file
    loaded_file = readRDS(latest_file)

    return(loaded_file)
}

# load_archive must be modified to load the latest metadata-*.json 
load_archive <- function(metadata) {
    # Subtract 1 from batch_number to load from the previous batch
    previous_batch_number = as.integer(metadata$batch_number) - 1
    # Get a list of all *.rds files in the bucket
    files = list.files(path = paste0(metadata$bucket_name, "/", metadata$user_id, "/", metadata$table_name, "/", previous_batch_number), pattern = "*.rds", full.names = TRUE)

    # # Print out the files and metadata for debugging
    # print(files)
    # print(metadata)


    # Load the acqf-, acqopt-, and archive- files
    acqf = load_file(files, "acqf-")
    acqopt = load_file(files, "acqopt-")
    archive = load_file(files, "archive-")

    acqf$surrogate$archive = archive
    return(list(archive, acqf, acqopt))
}