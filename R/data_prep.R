# General validation -----------------------------------------------------------

#' Ensure cookie attributes are valid
#'
#' @inheritParams .shared-parameters
#'
#' @return A list of attributes.
#' @keywords internal
.validate_attributes <- function(expiration,
                                 secure_only,
                                 domain,
                                 path,
                                 same_site,
                                 http_only) {
  secure_only <- .validate_secure_only(secure_only)
  http_only <- .validate_http_only(http_only)
  same_site <- .validate_same_site(same_site, secure_only)
  expiration <- .validate_expiration(expiration)
  domain <- .validate_domain(domain)
  path <- .validate_path(path)
  attributes <- list(
    expiration = expiration,
    secure_only = secure_only,
    domain = domain,
    path = path,
    same_site = same_site,
    http_only = http_only
  )
  return(attributes)
}

#' Ensure the argument is a single logical value
#'
#' @param arg_value The value of the argument.
#' @param arg_name The name of the argument for error messages.
#' @param arg_type The expected class for error messages.
#'
#' @return The value (if it is length-1).
#' @keywords internal
.validate_scalar <- function(arg_value, arg_name, arg_type = "logical") {
  if (length(arg_value) > 1) {
    cli::cli_abort("{.arg {arg_name}} must be a length-1 {.cls {arg_type}} or NULL.")
  }
  return(arg_value)
}

#' Ensure the argument is a single logical value
#'
#' @inheritParams .validate_scalar
#'
#' @return `NULL` or `TRUE`.
#' @keywords internal
.validate_logical_scalar <- function(arg_value, arg_name) {
  .validate_scalar(arg_value, arg_name)

  arg_value <- vctrs::vec_cast(arg_value, logical())

  if (isTRUE(arg_value)) {
    return(arg_value)
  } else {
    return(NULL)
  }
}

#' Ensure secure_only is valid
#'
#' @inheritParams .shared-parameters
#'
#' @return `NULL` or `TRUE`.
#' @keywords internal
.validate_secure_only <- function(secure_only) {
  return(
    .validate_logical_scalar(secure_only, "secure_only")
  )
}

#' Ensure http_only is valid
#'
#' @inheritParams .shared-parameters
#'
#' @return `NULL` or `TRUE`.
#' @keywords internal
.validate_http_only <- function(http_only) {
  return(
    .validate_logical_scalar(http_only, "http_only")
  )
}

#' Ensure same_site is valid
#'
#' @inheritParams .shared-parameters
#'
#' @return One of `NULL`, "Strict", "Lax", or "None".
#' @keywords internal
.validate_same_site <- function(same_site, secure_only) {
  if (is.null(same_site)) {
    return(same_site)
  }

  .validate_scalar(same_site, "same_site", "character")

  # Capitalize only the first letter.
  same_site <- gsub("^(.)", "\\U\\1\\E", tolower(same_site), perl = TRUE)

  if (!(same_site %in% c("Strict", "Lax", "None"))) {
    cli::cli_abort("same_site must be one of Strict, Lax, or None.")
  }

  if (same_site == "None" && !isTRUE(secure_only)) {
    cli::cli_abort("When same_site is None, secure_only must be TRUE.")
  }

  return(same_site)
}

#' Ensure expiration is valid
#'
#' @inheritParams .shared-parameters
#'
#' @return `NULL` or the expiration as a double.
#' @keywords internal
.validate_expiration <- function(expiration) {
  .validate_scalar(expiration, "expiration", "double")

  # Anything NULL-like should return NULL.
  if (length(expiration) == 0 || is.na(expiration) || expiration == 0) {
    return(NULL)
  }

  return(
    vctrs::vec_cast(expiration, double())
  )
}

#' Ensure domain is valid
#'
#' @inheritParams .shared-parameters
#'
#' @return `NULL` or `domain` as a character.
#' @keywords internal
.validate_domain <- function(domain) {
  if (is.null(domain)) {
    return(domain)
  }

  .validate_scalar(domain, "domain", "character")

  return(
    vctrs::vec_cast(domain, character())
  )
}

#' Ensure path is valid
#'
#' @inheritParams .shared-parameters
#'
#' @return `NULL` or `path` as a character.
#' @keywords internal
.validate_path <- function(path) {
  if (is.null(path)) {
    return(path)
  }

  .validate_scalar(path, "path", "character")

  return(
    vctrs::vec_cast(path, character())
  )
}

# Prepare data for javascript --------------------------------------------------

#' Prepare cookie attributes for javascript
#'
#' @inheritParams .shared-parameters
#'
#' @return A list of attributes with the names expected by js-cookie.
#' @keywords internal
.javascript_attributes <- function(expiration,
                                   secure_only,
                                   domain,
                                   path,
                                   same_site) {
  attributes <- .validate_attributes(
    expiration = expiration,
    secure_only = secure_only,
    domain = domain,
    path = path,
    same_site = same_site,
    http_only = NULL
  )

  # The Javascript names don't match the R names.
  js_attributes <- list(
    expires = attributes$expiration,
    secureOnly = attributes$secure_only,
    domain = attributes$domain,
    path = attributes$path,
    sameSite = attributes$same_site
  )

  return(purrr::compact(js_attributes))
}

#' Prep data for javascript
#'
#' This is an unexported function in shiny, and has been directly copy/pasted
#' (other than the name and documentation). This function formats things in the
#' way shiny's JS functions expect.
#'
#' @inheritParams jsonlite::toJSON
#' @inheritDotParams jsonlite::toJSON
#' @param use_signif Passed on to a print method.
#' @param UTC Passed on to a print method.
#' @param rownames Passed on to a print method.
#' @param keep_vec_names Passed on to a print method.
#' @param strict_atomic Used to deal with atomic vectors and/or unboxing.
#'
#' @return Jsonified text.
#' @keywords internal
.shiny_toJSON <- function(x, ..., dataframe = "columns", null = "null",
                          na = "null", auto_unbox = TRUE,
                          digits = getOption("shiny.json.digits", 16),
                          use_signif = TRUE, force = TRUE, POSIXt = "ISO8601",
                          UTC = TRUE, rownames = FALSE, keep_vec_names = TRUE,
                          strict_atomic = TRUE) {
  if (strict_atomic) {
    x <- I(x)
  }

  # I(x) is so that length-1 atomic vectors get put in [].
  jsonlite::toJSON(
    x,
    dataframe = dataframe, null = null, na = na,
    auto_unbox = auto_unbox, digits = digits,
    use_signif = use_signif, force = force, POSIXt = POSIXt,
    UTC = UTC, rownames = rownames,
    keep_vec_names = keep_vec_names, json_verbatim = TRUE, ...
  )
}


# Prepare data for HTTP --------------------------------------------------------

#' Condense cookie attributes to a set-cookie string
#'
#' @inheritParams .shared-parameters
#'
#' @return A string in the form "Set-Cookie: cookie-name=cookie-value;
#'   Expires=date", etc.
#' @keywords internal
.http_cookie_string <- function(cookie_name,
                                cookie_value,
                                expiration,
                                secure_only,
                                domain,
                                path,
                                same_site,
                                http_only) {
  cookie_name <- utils::URLencode(cookie_name, reserved = TRUE)
  cookie_value <- utils::URLencode(cookie_value, reserved = TRUE)
  main_string <- glue::glue("{cookie_name}={cookie_value}")
  attributes_string <- .attributes_string(
    expiration = expiration,
    secure_only = secure_only,
    domain = domain,
    path = path,
    same_site = same_site,
    http_only = http_only
  )
  return(
    glue::glue_collapse(c(main_string, attributes_string), sep = "; ")
  )
}

#' Condense attributes to a string
#'
#' @inheritParams .shared-parameters
#'
#' @return A string with a format like "Domain=domain-value; Secure;
#'   HttpOnly".
#' @keywords internal
.attributes_string <- function(expiration,
                               secure_only,
                               domain,
                               path,
                               same_site,
                               http_only) {
  # Unfortunately the canonical names and the javascript names are close but not
  # QUITE identical. We also convert the expiration (days) to an Expires (date)
  # in here.
  http_attributes <- .http_attributes(
    expiration = expiration,
    secure_only = secure_only,
    domain = domain,
    path = path,
    same_site = same_site,
    http_only = http_only
  )

  separate_strings <- .generate_http_attribute_strings(http_attributes)

  return(
    glue::glue_collapse(separate_strings, "; ")
  )
}

#' Prepare cookie attributes for HTTP
#'
#' @inheritParams .shared-parameters
#'
#' @return A list of attributes ready for HTTP.
#' @keywords internal
.http_attributes <- function(expiration,
                             secure_only,
                             domain,
                             path,
                             same_site,
                             http_only) {
  attributes <- .validate_attributes(
    expiration = expiration,
    secure_only = secure_only,
    domain = domain,
    path = path,
    same_site = same_site,
    http_only = http_only
  )

  http_attributes <- list(
    Expires = .http_date(attributes$expiration),
    Domain = attributes$domain,
    Path = attributes$path,
    Secure = attributes$secure_only,
    HttpOnly = attributes$http_only,
    SameSite = attributes$same_site
  )

  return(purrr::compact(http_attributes))
}

#' Convert expiration days to the expected date format
#'
#' @inheritParams .shared-parameters
#'
#' @return A string of the date in the required format.
#' @keywords internal
.http_date <- function(expiration) {
  if (is.null(expiration)) {
    return(NULL)
  }

  expires_date <- clock::add_days(
    clock::sys_time_now(),
    expiration
  )

  # Convert to the target format as specified at
  # https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Date
  # Date: <day-name>, <day> <month> <year> <hour>:<minute>:<second> GMT
  return(
    clock::date_format(
      clock::as_date_time(expires_date, zone = "GMT"),
      format = "%a, %d %b %Y %H:%M:%S GMT"
    )
  )
}

#' Generate the separate attribute strings
#'
#' @param http_attributes A list of attributes with the names expected by
#'   Set-Cookie.
#'
#' @return A character vector of either the names (for Secure or HttpOnly) or
#'   name=value pairs.
#' @keywords internal
.generate_http_attribute_strings <- function(http_attributes) {
  return(
    purrr::imap_chr(
      http_attributes,
      function(value, name) {
        if (isTRUE(value)) {
          return(name)
        } else {
          return(
            glue::glue("{name}={value}")
          )
        }
      }
    )
  )
}
