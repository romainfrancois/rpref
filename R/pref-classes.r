

# Preference classes
# ------------------

# All functions are internal!

# General preference (only for internal use)
preference <- setRefClass("preference",
  fields = list(expr = "expression", score_id = "numeric", eval_frame = "environment", 
                # cache for Hasse diagram / scorevals
                hasse_mtx = "matrix", scorevals = "data.frame", cache_available = "logical"), 
  methods = list(
    show = function() {
      return(cat(paste0('[Preference] ', unbrace(.self$get_str()))))
    },
    
    # Get string representation
    get_str = function(parent_op = "", static_terms = NULL) {
      return("((empty))") # Outer brackets are removed by "unbrace"
    },
    
    
    # Predecessor/Successor functions
    # -------------------------------
    
    # Initialize cache for Hasse diagram / Scorevals
    init_pred_succ = function(df) {
      .self$scorevals <- .self$get_scorevals(1, df)$scores
      serialized <- .self$serialize()
      .self$hasse_mtx <- t(get_hasse_impl(.self$scorevals, serialized)) + 1
      .self$cache_available <- TRUE
      return()
    },
    
    check_cache = function() {
      if (!isTRUE(.self$cache_available)) stop("No data set avaible. Run `init_succ_pref(df)` first.")
    },
    
    # Hasse diagramm successors
    h_succ = function(inds) {
      .self$check_cache()
      if (length(inds) == 1) {
        return(.self$hasse_mtx[.self$hasse_mtx[,1]==inds,2])
      } else {
        res_inds <- lapply(inds, function(x) .self$hasse_mtx[.self$hasse_mtx[,1]==x,2])
        return(Reduce('union', res_inds[-1], res_inds[[1]]))
      }
    },
      
    # Hasse diagramm predecessors
    h_pred = function(inds) {
      .self$check_cache()
      if (length(inds) == 1) { 
        return(.self$hasse_mtx[.self$hasse_mtx[,2]==inds,1])
      } else {
        res_inds <- lapply(inds, function(x) .self$hasse_mtx[.self$hasse_mtx[,2]==x,1])
        return(Reduce('union', res_inds[-1], res_inds[[1]]))
      }
    },
    
      
    # All succesors
    all_succ = function(inds) {
      .self$check_cache()
      all_inds <- 1:nrow(.self$scorevals)
      if (length(inds) == 1) {
        which(.self$cmp(inds, all_inds, .self$scorevals))
      } else {
        return(which(as.logical(do.call("pmax", lapply(inds, function(x) .self$cmp(x, all_inds, .self$scorevals) )))))
      }
    },
      
    # All predecessors
    all_pred = function(inds) {
      .self$check_cache()
      all_inds <- 1:nrow(.self$scorevals)
      if (length(inds) == 1) {
        which(.self$cmp(all_inds, inds, .self$scorevals))
      } else {
        return(which(as.logical(do.call("pmax", lapply(inds, function(x) .self$cmp(all_inds, x, .self$scorevals) )))))
      }
    }
    
  )
)
is.preference <- function(x) inherits(x, "preference")

# Special empty preference class. All scores are 0
empty.pref <- setRefClass("empty.pref",
  contains = "preference",
  methods = list(
    
    get_scorevals = function(next_id, df) {
      return(list(next_id = next_id + 1, scores = as.data.frame(rep(0, nrow(df)))))
    },
    
    cmp = function(i, j, score_df) { # TRUE if i is better than j
      return(FALSE)
    },
    
    eq = function(i, j, score_df) { # TRUE if i is equal to j
      return(TRUE)
    },
    
    serialize = function() {
      return(list(kind = 's'));
    }
  )    
)
is.empty.pref <- function(x) inherits(x, "empty.pref")

# cmp/eq functions are not needed for C++ BNL algorithms, but for igraph, etc.

# Base preferences 
basepref <- setRefClass("basepref", 
  contains = "preference",
  fields = list(expr = "expression", score_id = "numeric", eval_frame = "environment"),
  methods = list(
    initialize = function(expr_ = expression(), eval_frame_ = environment()) {
      .self$expr <- expr_
      .self$eval_frame <- eval_frame_
      return(.self)
    },
    
    get_scorevals = function(next_id, df) {
      .self$score_id = next_id
      # Calc score of base preference
      scores <- .self$calc_scores(df, .self$eval_frame)
      # Check if length ok
      if (length(scores) != nrow(df)) {
        if (length(scores) == 1) scores <- rep(scores, nrow(df))
        else stop(paste0("Evaluation of base preference ", .self$get_str(), " does not have the same length as the dataset!"))
      }
      # Increase next_id after base preference
      return(list(next_id = next_id + 1, scores = as.data.frame(scores)))
    },
    
    cmp = function(i, j, score_df) { # TRUE if i is better than j
      return(score_df[i, .self$score_id] < score_df[j, .self$score_id])
    },
    
    eq = function(i, j, score_df) { # TRUE if i is equal to j
      return(score_df[i, .self$score_id] == score_df[j, .self$score_id])
    },
      
    get_expr_str = function(static_terms = NULL) {
      if (!is.null(static_terms)) {
        get_expr_evaled <- function(lexpr) {
          lexpr <- lexpr[[1]]
          if (is.symbol(lexpr)) { 
            if (as.character(lexpr) == '...') # ... cannot be eval'd directly!
              return(list(str = '...', final = FALSE)) 
            else if (any(vapply(static_terms, function(x) identical(lexpr, x), TRUE)))
              return(list(str = as.character(lexpr), final = TRUE)) # static_term => final
            else
              return(list(str = deparse(eval(lexpr, .self$eval_frame)), final = FALSE))
          } else if (length(lexpr) == 1) { # Not a symbol => not final
            return(list(str = as.character(lexpr), final = FALSE))   
          } else { # n-ary function/operator
            
            # Go into recursion
            expr_evals <- list()
            for (i in 2:length(lexpr)) expr_evals[[i-1]] <- get_expr_evaled(lexpr[i])
            
            # Check if not final
            if (all(vapply(expr_evals, function(x) x$final, TRUE) == FALSE)) { 
              # ** re-eval
              # Especially eval ... at that level where ... is an operand
              str <- deparse(eval(lexpr, .self$eval_frame)) # May be a vector
              return(list(str = str, final = FALSE)) # still not final
            } else {
              expr_strs <- lapply(expr_evals, function(x) x$str)
              # ** Put term together on string level (no re-eval!) 
              fun_str <- as.character(lexpr[1][[1]])
              if (fun_str == '(') fun_str <- ''
              if (substr(deparse(lexpr[1]), 1, 1) == '`') # check if %-infix/classic operator
                str <- paste0(expr_strs[[1]], ' ', fun_str, ' ', expr_strs[[2]])
              else
                str <- paste0(fun_str, '(', paste(expr_strs, collapse = ', '), ')')
              return(list(str = str, final = TRUE)) # already final!
            }
          }
        } 
        return(get_expr_evaled(.self$expr)$str)
      } else {
        return(as.character(.self$expr))
      }
    },
    
    # Get string representation
    get_str = function(parent_op = "", static_terms = NULL) {
      return(paste0(.self$op(), '(', .self$get_expr_str(static_terms), ')'))
    },
    
    serialize = function() {
      return(list(kind = 's'));
    }
  )
)
is.basepref <- function(x) inherits(x, "basepref")


lowpref <- setRefClass("lowpref", 
  contains = "basepref",
  methods = list(
    op = function() 'low',
    
    calc_scores = function(df, frm) {
      res = eval(.self$expr, df, frm)
      if (!is.numeric(res)) stop("For the low preference ", .self$get_str(), " the expression must be numeric!")
      return(res)        
    }
  )
)
is.lowpref <- function(x) inherits(x, "lowpref")


highpref <- setRefClass("highpref", 
  contains = "basepref",
  methods = list(
    op = function() 'high',
    
    calc_scores = function(df, frm) {
      res = eval(.self$expr, df, frm)
      if (!is.numeric(res)) stop("For the high preference ", .self$get_str(), " the expression must be numeric!")
      return(-res)
    }
  )
)
is.highpref <- function(x) inherits(x, "highpref")


truepref <- setRefClass("truepref", 
  contains = "basepref",
  methods = list(
    op = function() 'true',
    
    calc_scores = function(df, frm) {
      res = eval(.self$expr, df, frm)
      if (!is.logical(res)) stop("For the true preference ", .self$get_str(), " the expression must be logical!")
      return(1 - as.numeric(res))
    }
  )
)
is.truepref <- function(x) inherits(x, "truepref")


# Reverse preference (revrsing the order)
reversepref <- setRefClass("reversepref",
  contains = "preference",
  fields = list(p = "preference"),
  methods = list(
    initialize = function(p_) {
      .self$p <- p_
      return(.self)
    },
    
    get_scorevals = function(next_id, df) {
      res <- p$get_scorevals(next_id, df)
      return(list(next_id = res$next_id + 1, scores = res$scores))
    },
    
    get_str = function(parent_op = "", static_terms = NULL) {
      return(paste0('-', .self$p$get_str(parent_op, static_terms)))
    },
    
    cmp = function(i, j, score_df) { # TRUE if i is better than j
      return(p$cmp(j, i, score_df))
    },
    
    eq = function(...) p$eq(...),
    
    serialize = function() {
      return(list(kind = '-', p = .self$p$serialize()));
    }
  )
)
is.reversepref <- function(x) inherits(x, "reversepref")


# Binary complex preferences
# cmpcom and eqcomp functions are set via constructor and are just compositions (refering to $cmp and $eq)
complexpref <- setRefClass("complexpref",
  contains = "preference",
  fields = list(p1 = "preference", p2 = "preference", op = "character", 
                cmpcomp = "function", eqcomp = "function", prior_chain = "logical"),
  methods = list(
    initialize = function(p1_ = preference(), p2_ = preference(), op_ = '', cmp_ = function() NULL, eq_ = function() NULL) {
      .self$p1      <- p1_
      .self$p2      <- p2_
      .self$op      <- op_
      .self$cmpcomp <- cmp_ # composition of cmp function
      .self$eqcomp  <- eq_
      .self$prior_chain <- FALSE
      return(.self)
    },
      
    # Get Scorevals / check for prior-chain. Called *before* serialize!
    get_scorevals = function(next_id, df) {
      # ** Usual complex preference
      res1 <- .self$p1$get_scorevals(next_id, df)
      res2 <- .self$p2$get_scorevals(res1$next_id, df)
      return(list(next_id = res2$next_id, scores = cbind(res1$scores, res2$scores)))
    },
    
    get_str = function(parent_op = "", static_terms = NULL) {
      res <- paste0(.self$p1$get_str(.self$op, static_terms), ' ', .self$op, ' ', 
                    .self$p2$get_str(.self$op, static_terms))
      if (.self$op != parent_op) res <- embrace(res)
      return(res)
    },
    
    # Serialization for C++ Interface
    serialize = function() {
      return(list(kind = .self$op, p1 = .self$p1$serialize(), p2 = .self$p2$serialize()))
    },
    
    # Simple wrapper for cmp/eq compositions (overwritten by prioritization)
    cmp = function(...) .self$cmpcomp(...),
    eq  = function(...) .self$eqcomp(...)
    
  )
)
is.complexpref <- function(x) inherits(x, "complexpref")

# double has 52 bits significand, thus the largest double number d which surely fulfills "d \neq d+1" is 2^52
MAX_CHAIN_LENGTH <- 52 

priorpref <- setRefClass("priorpref",
  contains = "complexpref",
  fields = list(chain_size = "numeric", prior_chain = "logical", prior_score_id = "numeric"),
  methods = list(   
    
    # Check if we have a purely prioritization chain - calculate highest value
    get_prior_length = function() {
      # Calculate sum 
      len <- 0
      for (p in list(.self$p1, .self$p2)) {
        if (is.priorpref(p)) {
          tres <- p$get_prior_length()
          if (is.null(tres)) return(NULL)
          len <- len + tres
        } else if (is.truepref(p)) {
          len <- len + 1
        } else {
          return(NULL)
        }
        
        # Store chain_size for get_scorevals(..., get_greatest_subtree = TRUE)
        .self$chain_size <- len
      }
      return(len)
    },
    
    # Calculcate prior-chain score
    get_prior_scores = function(next_id, prior_length, df) {
      score_vals <- 0
      for (p in list(.self$p1, .self$p2)) {
        if (is.complexpref(p)) {
          res <- p$get_prior_scores(next_id, prior_length, df) 
          score_vals <- score_vals + res$score_vals
          next_id <- res$next_id
        } else if (is.truepref(p)) {
          score_vals <- score_vals + 2 ^ (prior_length - next_id) * p$get_scorevals(1, df)$scores
          # Increase next_id after true preference
          next_id <- next_id + 1
        }
      }
      
      return(list(next_id = next_id, score_vals = score_vals))
    },
    
    # Get scorevals, specially consider prior-chains. Called *before* serialize!
    get_scorevals = function(next_id, df, get_greatest_subtree = FALSE) {
      
      # By default false
      .self$prior_chain = FALSE
      
      if (get_greatest_subtree) { # It's a prior-chain, but perhaps to large
        
        if (.self$chain_size <= MAX_CHAIN_LENGTH) { # subtree which is sufficiently small
          # Set prior-chain (pseudo score preference)
          .self$prior_chain = TRUE
          .self$prior_score_id = next_id
          scores <- .self$get_prior_scores(1, .self$chain_size, df)$score_vals
          return(list(next_id = next_id + 1, scores = scores))
        } # -> else: see block "** All else-paths"
      
      } else {
      
        # ** Prior chains
        prior_res_len <- .self$get_prior_length()
        # Check if len > 1 (a real chain) 
        if (!is.null(prior_res_len) && (prior_res_len > 1)) {
          # check if maxval is suffcient small to get distinctive score vals (double precision!)
          if (prior_res_len <= MAX_CHAIN_LENGTH) { 
            # Set prior-chain (pseudo score preference)
            .self$prior_chain = TRUE
            .self$prior_score_id = next_id
            scores <- .self$get_prior_scores(1, prior_res_len, df)$score_vals
            return(list(next_id = next_id + 1, scores = scores))
          } else {
            # Limit reached - stop the recursive search for chains
            
            # Give a warning for all unbalanced trees
            if (is.priorpref(.self$p1) && .self$p1$chain_size > MAX_CHAIN_LENGTH && is.truepref(.self$p2) ||
                is.priorpref(.self$p2) && .self$p2$chain_size > MAX_CHAIN_LENGTH && is.truepref(.self$p1))
              warning(paste0("Prioritization chain exceeded maximal size (", MAX_CHAIN_LENGTH, ") and the operator tree is unbalanced. ",
                              "This is a performance issue. It is recommended to build chains like ",
                              "(P1 & ... & P", MAX_CHAIN_LENGTH, ") & ... & (P1 & ... & P", MAX_CHAIN_LENGTH, ") ",
                              "for better performance of the preference evaluation."))
            
            # Change to search with known chain_sizes and use flag get_greatest_subtree = TRUE
            return(.self$get_scorevals(next_id, df, get_greatest_subtree = TRUE))
          }
        }
      }
      
      # ** All else-paths: Handle like usual complex preference, but propagete get_greatest_subtree
      res1 <- if (is.priorpref(.self$p1)) .self$p1$get_scorevals(next_id,      df, get_greatest_subtree) else .self$p1$get_scorevals(next_id,      df)
      res2 <- if (is.priorpref(.self$p2)) .self$p2$get_scorevals(res1$next_id, df, get_greatest_subtree) else .self$p2$get_scorevals(res1$next_id, df)
      return(list(next_id = res2$next_id, scores = cbind(res1$scores, res2$scores)))
    },
    
    # Serialization for C++ Interface
    serialize = function() {
      if (.self$prior_chain)  # Prior chain is like a numerical base preference
        return(list(kind = 's'))
      else
        return(callSuper())
    },
    
    # Wrapper for Compare/Prioritization
    cmp = function(i, j, score_df) {
      if (.self$prior_chain) # Prior-Chain => Score Pref
        return(score_df[i, .self$prior_score_id] < score_df[j, .self$prior_score_id])
      else
        return(.self$cmpcomp(i, j, score_df)) # Usual composition function
    },
    
    # Wrapper for Equal/Prioritization
    eq = function(i, j, score_df) {
      if (.self$prior_chain) # Prior-Chain => Score Pref
        return(score_df[i, .self$prior_score_id] == score_df[j, .self$prior_score_id])
      else
        return(.self$eqcomp(i, j, score_df)) # Usual composition function
    }  
  )
)
  
is.priorpref <- function(x) inherits(x, "priorpref")
  
# Some helper functions
# ---------------------

# Remove brackets from string if existing
unbrace <- function(x) {
  if (substr(x, 1, 1) == "(" && substr(x, nchar(x), nchar(x)) == ")") return(substr(x, 2, nchar(x)-1))
  else return(x)
}

# Add brackets to string
embrace <- function(x) {
  return(paste0('(', x, ')'))
}
  
  