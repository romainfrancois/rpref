#' Base preferences
#' 
#' Base preferences are used to describe the different goals of a preference query. 
#' 
#'
#' @name base_pref
#' @param expr A numerical/logical expression which is the term to evaluate for the current preference. 
#'       The objective is to search for minimal/maximal values of this expression (for \code{low}/\code{high}) or for 
#'       logical true values (for \code{true}). 
#' 
#' @details
#' 
#' Mathematically, all base preferences are strict weak orders (irreflexive, transitive and negative transitive).
#' 
#' The three fundamental base preferences are:
#' 
#' \describe{
#'   \item{\code{low(a), high(a)}}{Search for minimal/maximal values of \code{a}, 
#'         i.e., the induced order is the "smaller than" or "greater than" order on the values of \code{a}.
#'         The values of \code{a} must be numeric values.}
#'   \item{\code{true(a)}}{Search for true values in logical expressions, i.e., \code{TRUE} is considered to be better than \code{FALSE}.
#'         The values of \code{a} must be logical values.
#'         For a tuplewise evaulation of a complex boolean condition one has to use the \code{&} and \code{|} operators for logical AND/OR
#'         (and not the \code{&&} and \code{||} operators).}
#' }
#' 
#' 
#' The term \code{expr} can be just a single attribute or an arbitrary expression, e.g., \code{low(a+2*b+f(c))}.
#' There \code{a}, \code{b} and \code{c} are columns of the addressed dataset and \code{f} is a previously defined function.
#' 
#' Functions contained in \code{expr} are evaluated over the entire dataset, i.e., 
#' it is possible to use aggregate functions (\code{min}, \code{mean}, etc.). 
#' Note that all functions (and also variables which are not columns of the dataset, where \code{expr} will be evaluated on)
#' must be defined in the same environment (e.g. environment of a function) as the base preference.
#' 
#' @section Using expressions in preferences:
#' 
#' The \code{low_(e)}, \code{high_(e)} and \code{true_(e)} preferences have the same functionality,
#' but expects an expression \code{e} or symbol \code{e} as argument.
#' For example, \code{low(a)} is equivalent to \code{low(expression(a))} or \code{low(as.symbol("a"))}. 
#' 
#' 
#' This is very helpful for developing your own base preferences. Assume you want to define a base Preference \code{false}
#' as the dual of \code{true}. A definition like \code{false <- function(x) -true(x)} is the wrong approach, as 
#' \code{psel(data.frame(a = c(1,2)), false(a == 1))} will result in the error "object 'a' not found".
#' This is because \code{a} is handled as a variable and not as a (abstract) symbol to be evaluated later on the data set.
#' By defining
#' 
#' \code{false <- function(x) -true_(substitute(x))}
#' 
#' one gets a preference which behaves like a "built-in" preference. The object \code{false(a == 1)} will output 
#' \code{[Preference] -true(a == 1)} on the console and 
#' \code{psel(data.frame(a = c(1,2)), false(a==1))} returns correctly the second tuple with \code{a==2}.
#' 
#' 
#' @seealso See \code{\link{complex_pref}} how to compose complex preferences to retrieve e.g. the Skyline.
#' 
#' See \code{\link{base_pref_macros}} for more base preferences.
#' 
#' @examples
#' # Define a preference with a score value combining mpg and hp
#' p1 <- high(4 * mpg + hp)
#' # Perform the preference selection
#' psel(mtcars, p1)
#' 
#' # Define a preference with a given function
#' f <- function(x, y) (abs(x - mean(x))/max(x) + abs(y - mean(y))/max(y))
#' p2 <- low(f(mpg, hp))
#' psel(mtcars, p2)
NULL


#' @rdname base_pref
#' @export
low <- function(expr) {
  expr <- as.expression(substitute(expr))
  return(lowpref(expr, parent.frame()))
}

#' @rdname base_pref
#' @export
low_ <- function(expr) {
  return(lowpref(as.expression(expr), parent.frame()))
}

#' @rdname base_pref
#' @export
high <- function(expr) {
  expr <- as.expression(substitute(expr))
  return(highpref(expr, parent.frame()))
}

#' @rdname base_pref
#' @export
high_ <- function(expr) {
  return(highpref(as.expression(expr), parent.frame()))
}

#' @rdname base_pref
#' @export
true <- function(expr) {
  expr <- as.expression(substitute(expr))
  return(truepref(expr, parent.frame()))
}

#' @rdname base_pref
#' @export
true_ <- function(expr) {
  return(truepref(as.expression(expr), parent.frame()))
}