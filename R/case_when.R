#' A general vectorised if.
#'
#' This function allows you to vectorise multiple `if` and `else if`
#' statements. It is an R equivalent of the SQL `CASE WHEN` statement.
#'
#' @param ... A sequence of two-sided formulas. The left hand side (LHS)
#'   determines which values match this case. The right hand side (RHS)
#'   provides the replacement value.
#'
#'   The LHS must evaluate to a logical vector. Each logical vector can
#'   either have length 1 or a common length. All RHSs must evaluate to
#'   the same type of vector.
#'
#'   These dots are evaluated with [explicit splicing][rlang::dots_list].
#' @export
#' @return A vector as long as the longest LHS, with the type (and
#'   attributes) of the first RHS.  Inconsistent lengths or types will
#'   generate an error.
#' @examples
#' x <- 1:50
#' case_when(
#'   x %% 35 == 0 ~ "fizz buzz",
#'   x %% 5 == 0 ~ "fizz",
#'   x %% 7 == 0 ~ "buzz",
#'   TRUE ~ as.character(x)
#' )
#'
#' # Like an if statement, the arguments are evaluated in order, so you must
#' # proceed from the most specific to the most general. This won't work:
#' case_when(
#'   TRUE ~ as.character(x),
#'   x %%  5 == 0 ~ "fizz",
#'   x %%  7 == 0 ~ "buzz",
#'   x %% 35 == 0 ~ "fizz buzz"
#' )
#'
#' # case_when is particularly useful inside mutate when you want to
#' # create a new variable that relies on a complex combination of existing
#' # variables
#' starwars %>%
#'   select(name:mass, gender, species) %>%
#'   mutate(
#'     type = case_when(
#'       height > 200 | mass > 200 ~ "large",
#'       species == "Droid"        ~ "robot",
#'       TRUE                      ~  "other"
#'     )
#'   )
#'
#' # Dots support splicing:
#' patterns <- list(
#'   TRUE ~ as.character(x),
#'   x %%  5 == 0 ~ "fizz",
#'   x %%  7 == 0 ~ "buzz",
#'   x %% 35 == 0 ~ "fizz buzz"
#' )
#' case_when(!!! patterns)
case_when <- function(...) {
  formulas <- dots_list(...)
  n <- length(formulas)

  if (n == 0) {
    stop("No cases provided", call. = FALSE)
  }

  query <- vector("list", n)
  value <- vector("list", n)

  for (i in seq_len(n)) {
    f <- formulas[[i]]
    if (!inherits(f, "formula") || length(f) != 3) {
      non_formula_arg <- substitute(list(...))[[i + 1]]
      stop(
        "Case ", i, " (", deparse_trunc(non_formula_arg),
        ") is not a two-sided formula",
        call. = FALSE
      )
    }

    env <- environment(f)

    query[[i]] <- eval_bare(f[[2]], env)
    if (!is.logical(query[[i]])) {
      stop(
        "LHS of case ", i, " (", deparse_trunc(f_lhs(f)), ") is ",
        typeof(query[[i]]), ", not logical",
        call. = FALSE
      )
    }

    value[[i]] <- eval_bare(f[[3]], env)
  }

  m <- max(vapply(query, length, integer(1)))
  out <- value[[1]][rep(NA_integer_, m)]
  replaced <- rep(FALSE, m)

  for (i in seq_len(n)) {
    check_length(
      query[[i]], out,
      paste0("LHS of case ", i, " (", deparse_trunc(f_lhs(formulas[[i]])), ")"))

    out <- replace_with(
      out, query[[i]] & !replaced, value[[i]],
      paste0("RHS of case ", i, " (", deparse_trunc(f_rhs(formulas[[i]])), ")"))
    replaced <- replaced | (query[[i]] & !is.na(query[[i]]))
  }

  out
}
