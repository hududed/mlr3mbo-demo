library(mlr3mbo)
library(mlr3)
library(mlr3learners)
library(bbotk)
library(data.table)
library(tibble)
library(R.utils)

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
    # Get a list of all *.rds files in the bucket
    files = list.files(path = paste0(metadata$bucket_name, "/", metadata$user_id, "/", metadata$table_name, "/", metadata$batch_number), pattern = "*.rds", full.names = TRUE)

    # Load the acqf-, acqopt-, and archive- files
    acqf = load_file(files, "acqf-")
    acqopt = load_file(files, "acqopt-")
    archive = load_file(files, "archive-")

    acqf$surrogate$archive = archive
    return(list(archive, acqf, acqopt))
}

save_archive <- function(archive, acq_function, acq_optimizer, metadata) {
    # Get the current timestamp
    timestamp = format(Sys.time(), "%Y%m%d%H%M%S")

    new_batch_number = as.integer(metadata$batch_number) + 1

    # Define the directory path
    dir_path = paste0(metadata$bucket_name, "/", metadata$user_id, "/", metadata$table_name, "/", new_batch_number)
    
    # Create the directory if it doesn't exist
    if (!dir.exists(dir_path)) {
        dir.create(dir_path, recursive = TRUE)
    }
    
    # Save the objects to files
    saveRDS(archive, paste0(dir_path, "/archive-", timestamp, ".rds"))
    saveRDS(acq_function, paste0(dir_path, "/acqf-", timestamp, ".rds"))
    saveRDS(acq_optimizer, paste0(dir_path, "/acqopt-", timestamp, ".rds"))
}

update_and_optimize <- function(acq_function, acq_optimizer, tmp_archive, candidate_new, lie) {
    acq_function$surrogate$update()
    acq_function$update()
    tmp_archive$add_evals(xdt = candidate_new, xss_trafoed = transform_xdt_to_xss(candidate_new, tmp_archive$search_space), ydt = lie)
    candidate_new = acq_optimizer$optimize()
    return(candidate_new)
}

add_evals_to_archive <- function(archive, acq_function, acq_optimizer, data, q, metadata) {
    lie = data.table()
    liar = min
    acq_function$surrogate$update()
    acq_function$update()
    candidate = acq_optimizer$optimize()
    print(candidate)
    tmp_archive = archive$clone(deep = TRUE)
    acq_function$surrogate$archive = tmp_archive
    lie[, archive$cols_y := liar(archive$data[[archive$cols_y]])]
    candidate_new = candidate

    # Check if lie is a data.table
    if (!is.data.table(lie)) {
        stop("lie is not a data.table")
    }
    candidate_new = candidate
    for (i in seq_len(q)[-1L]) {
        candidate_new = update_and_optimize(acq_function, acq_optimizer, tmp_archive, candidate_new, lie)
        candidate = rbind(candidate, candidate_new)
    }
    candidate_new = update_and_optimize(acq_function, acq_optimizer, tmp_archive, candidate_new, lie)
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
experiment <- function(data, metadata) {
    set.seed(42)
    result = load_archive(metadata)
    full_data = as.data.table(data)
    # print(data)
    data <- tail(full_data, n=metadata$num_random_lines)
    print(data)
        
    archive = result[[1]]
    acq_function = result[[2]]
    acq_optimizer = result[[3]]
    
    # Check if metadata$output_column_names is NULL or empty
    if (is.null(metadata$output_column_names) || length(metadata$output_column_names) == 0) {
        stop("metadata$output_column_names is NULL or empty")
    }

    # Check if all output_column_names exist in data
    if (!all(metadata$output_column_names %in% names(data))) {
        stop("Some names in metadata$output_column_names do not exist in data")
    }

    # print(class(archive))
    # print(methods(class=class(archive)))


    # Now you can safely call the add_evals method
    archive$add_evals(xdt = data[, names(metadata$parameter_info), with=FALSE], ydt = data[, metadata$output_column_names, with=FALSE])
    print("Model archive so far: ")
    print(archive)
    q = metadata$num_random_lines
    result = add_evals_to_archive(archive, acq_function, acq_optimizer, data, q, metadata)

    candidate = result[[1]]
    archive = result[[2]]
    acq_function = result[[3]]

    print(result)

    x2 <- candidate[, names(metadata$parameter_info), with=FALSE]
    print("New candidates: ")
    print(x2)
    print("New archive: ")
    print(archive)

    x2_dt <- as.data.table(x2)
    full_data <- rbindlist(list(full_data, x2_dt), fill = TRUE)
    print(full_data)
    print(paste0("mlr3mbo update is finished. Results file is saved at: ", dir_path))

    return(full_data)

    }