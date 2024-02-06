library(mlr3mbo)
library(mlr3)
library(mlr3learners)
library(bbotk)
library(data.table)
library(tibble)

source("mlr3mbo-demo/utils/processing.R")

# # same as in utils/update.R?
# round_to_nearest <- function(x, metadata) {
#   to_nearest = metadata$to_nearest
#   if (is.data.table(x) || is.data.frame(x)) {
#     x = lapply(x, function(col) {
#       if (is.numeric(col)) {
#         return(round(col / to_nearest) * to_nearest)
#       } else {
#         return(col)
#       }
#     })
#     x = setDT(x) # Convert the list to a data.table
#   } else if (is.numeric(x)) {
#     x = round(x / to_nearest) * to_nearest
#   }
#   return(x)
# }
# # same as in utils/update.R?
# save_archive <- function(archive, acq_function, acq_optimizer, metadata) {
#     # Get the current timestamp
#     timestamp = format(Sys.time(), "%Y%m%d%H%M%S")

#     # Define the directory path
#     dir_path = paste0(metadata$bucket_name, "/", metadata$user_id, "/", metadata$table_name, "/", metadata$batch_number)
    
#     # Create the directory if it doesn't exist
#     if (!dir.exists(dir_path)) {
#         dir.create(dir_path, recursive = TRUE)
#     }
    
#     # Save the objects to files
#     saveRDS(archive, paste0(dir_path,  "/archive-", timestamp, ".rds"))
#     saveRDS(acq_function, paste0(dir_path, "/acqf-", timestamp, ".rds"))
#     saveRDS(acq_optimizer, paste0(dir_path, "/acqopt-", timestamp, ".rds"))
#     # Print the directory path
#     print(paste("RDS files saved in directory:", dir_path))
# }
# # same as in utils/update.R?
# update_and_optimize <- function(acq_function, acq_optimizer, tmp_archive, candidate_new, lie) {
#     acq_function$surrogate$update()
#     acq_function$update()
#     tmp_archive$add_evals(xdt = candidate_new, xss_trafoed = transform_xdt_to_xss(candidate_new, tmp_archive$search_space), ydt = lie)
#     candidate_new = acq_optimizer$optimize()
#     # Round the candidates to the nearest 0.2
#     candidate_new = round_to_nearest(candidate_new, metadata)
#     return(candidate_new)
# }
# # same as in utils/update.R?
# add_evals_to_archive <- function(archive, acq_function, acq_optimizer, data, q, metadata) {
#     lie = data.table()
#     liar = min
#     acq_function$surrogate$update()
#     acq_function$update()
#     candidate = acq_optimizer$optimize()
#     # Round the candidates to the nearest 0.2
#     candidate = round_to_nearest(candidate, metadata)
#     print(candidate)
#     tmp_archive = archive$clone(deep = TRUE)
#     acq_function$surrogate$archive = tmp_archive
#     lie[, archive$cols_y := liar(archive$data[[archive$cols_y]])]
#     candidate_new = candidate
    
#     # Check if lie is a data.table
#     if (!is.data.table(lie)) {
#         stop("lie is not a data.table")
#     }
#     candidate_new = candidate
#     for (i in seq_len(q)[-1L]) {
#         candidate_new = update_and_optimize(acq_function, acq_optimizer, tmp_archive, candidate_new, lie)
#         candidate = rbind(candidate, candidate_new)
#     }
#     candidate_new = update_and_optimize(acq_function, acq_optimizer, tmp_archive, candidate_new, lie)
#     # Iterate over each column in candidate
#     for (col in names(candidate_new)) {
#         # If the column is numeric, round and format it
#         if (is.double(candidate_new[[col]])) {
#             candidate_new[[col]] <- format(round(candidate_new[[col]], 2), nsmall = 2)
#         }
#     }
    
#     save_archive(archive, acq_function, acq_optimizer, metadata)
#     return(list(candidate, archive, acq_function))
#     }

propose_experiment <- function(data, metadata) {
    set.seed(42)
    data = as.data.table(data) # data.csv is queried `table`

    # retrieve this from metadata parameter_ranges
    search_space = ParamSet$new(params = list())
    # Loop through metadata$parameter_info
    for (param_name in names(metadata$parameter_info)) {
        print(param_name)
        param_info = metadata$parameter_info[[param_name]]
        param_range = metadata$parameter_ranges[[param_name]]

        print(param_info)
        print(param_range)

        # Check if param_info is 'object', if so, no need to convert to numeric
        if (param_info == 'object') {
            search_space$add(ParamFct$new(id = param_name, levels = param_range))
            next
        }

        # Remove the parentheses and split the string at the comma
        param_range_split = strsplit(gsub("[()]", "", param_range), ",")[[1]]

        # Convert the results to appropriate type
        if (param_info == 'integer') {
            lower = as.integer(param_range_split[1])
            upper = as.integer(param_range_split[2])
        } else if (param_info == 'float') {
            lower = as.numeric(param_range_split[1])
            upper = as.numeric(param_range_split[2])
        }

        # Check if lower or upper is NA
        if (is.na(lower) | is.na(upper)) {
            print(paste("lower or upper is NA for param_name:", param_name))
            next
        }

        
        # Add the parameter to the search space
        if (param_info == 'float') {
            values = seq(lower,upper, by=0.2)
            search_space$add(ParamDbl$new(id = param_name, lower = lower, upper = upper)) # TODO: Trafo since levels are inf, but id doesnt work with p_int
        } else if (param_info == 'integer') {
            search_space$add(ParamInt$new(id = param_name, lower = lower, upper = upper))
        }
    }
    # Initialize an empty ParamSet for the codomain
    codomain = ParamSet$new(params = list())

    # Loop through metadata$output_column_names
    for (output_name in metadata$output_column_names) {
        # Add the output to the codomain
        codomain$add(ParamDbl$new(id = output_name, tags = metadata$direction))
    }

    archive = Archive$new(search_space = search_space, codomain = codomain)

    # Use parameter_info in the subset operation
    archive$add_evals(xdt = data[, names(metadata$parameter_info), with=FALSE], ydt = data[, metadata$output_column_names, with=FALSE])


    print("Model archive so far: ")
    print(archive)
    surrogate = srlrn(lrn("regr.ranger"), archive = archive)
    acq_function = acqf("ei", surrogate = surrogate)
    acq_optimizer = acqo(opt("random_search", batch_size = 1000),
                        terminator = trm("evals", n_evals = 1000),
                        acq_function = acq_function)
    q = as.integer(metadata$num_random_lines)
    # print(q)
    # print(acq_function)
    # print(acq_optimizer)
    # print(data)
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
    data <- rbindlist(list(data, x2_dt), fill = TRUE)

    data[, Cu := 100 - Reduce(`+`, .SD), .SDcols = -ncol(data)]
    # Reorder the columns to move Cu to the left-most position
    setcolorder(data, c("Cu", setdiff(names(data), "Cu")))

    print(data)
      # Define the directory path
    dir_path = paste0(metadata$bucket_name, "/", metadata$user_id, "/", metadata$table_name, "/", metadata$batch_number)
    
    # Save the data table as a CSV file in the same directory
    data.table::fwrite(data, paste0(dir_path, "/output.csv"))
    print(paste0("mlr3mbo proposals finished. Results file is saved at: ", dir_path))
    return(data)

    }