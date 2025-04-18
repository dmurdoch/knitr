#' A wrapper for rst2pdf
#'
#' Convert reST to PDF using \command{rst2pdf} (which converts from rst to PDF
#' using the ReportLab open-source library).
#' @param input The input rst file.
#' @param command Character string giving the path of the
#'   \command{rst2pdf} program. If the program is not in your PATH, the full path has to be
#'   given here.
#' @param options Extra command line options, e.g. \code{'-v'}.
#' @author Alex Zvoleff and Yihui Xie
#' @return An input file \file{*.rst} will produce \file{*.pdf} and this output
#'   filename is returned if the conversion was successful.
#' @export
#' @seealso \code{\link{knit2pdf}}
#' @references \url{https://github.com/rst2pdf/rst2pdf}
rst2pdf = function(input, command = 'rst2pdf', options = '') {
  out = with_ext(input, 'pdf')
  system2(command, paste(shQuote(input), '-o', shQuote(out), options))
  if (file.exists(out)) out else stop('conversion by rst2pdf failed!')
}

#' Convert various input files to various output files using \code{knit()} and
#' Pandoc
#'
#' Knits the input file and compiles to an output format using Pandoc.
#' @inheritParams knit
#' @param to Character string giving the Pandoc output format to use.
#' @param pandoc_wrapper An R function used to call Pandoc. If \code{NULL} (the
#'   default), \code{rmarkdown::\link[rmarkdown]{pandoc_convert}()} will be used
#'   if \pkg{rmarkdown} is installed, otherwise \code{\link{pandoc}()}.
#' @param ... Options to be passed to the \code{pandoc_wrapper} function.
#' @param encoding Ignored (always assumes UTF-8).
#' @author Trevor L. Davis
#' @return Returns the output of the \code{pandoc_wrapper} function.
#' @export
knit2pandoc = function(
  input, output = NULL, tangle = FALSE, text = NULL, quiet = FALSE,
  envir = parent.frame(), to = 'html', pandoc_wrapper = NULL, ..., encoding = 'UTF-8'
) {
  knit_output = knit(input, output, tangle, text, quiet, envir)
  if (!is.null(pandoc_wrapper)) return(pandoc_wrapper(knit_output, to, ...))
  if (!has_package('rmarkdown')) return(pandoc(knit_output, to, ...))
  output = gsub(paste0(file_ext(knit_output), '$'), to, knit_output)
  rmarkdown::pandoc_convert(knit_output, to, output = output, ...)
}

#' Convert Rnw or Rrst files to PDF
#'
#' Knit the input Rnw or Rrst document, and compile to PDF using
#' \code{tinytex::\link[tinytex]{latexmk}()} or \code{\link{rst2pdf}()}.
#' @inheritParams knit
#' @param compiler A character string giving the LaTeX engine used to compile
#'   the tex document to PDF. For an Rrst file, setting \code{compiler} to
#'   \code{'rst2pdf'} will use \code{\link{rst2pdf}} to compile the rst file to
#'   PDF using the ReportLab open-source library.
#' @param ... Options to be passed to \code{tinytex::\link[tinytex]{latexmk}()}
#'   or \code{\link{rst2pdf}()}.
#' @author Ramnath Vaidyanathan, Alex Zvoleff and Yihui Xie
#' @return The filename of the PDF file.
#' @note The \code{output} argument specifies the output filename to be passed
#'   to the PDF compiler (e.g. a tex document) instead of the PDF filename.
#' @export
#' @examples #' compile with xelatex
#' ## knit2pdf(..., compiler = 'xelatex')
#'
#' #' compile a reST file with rst2pdf
#' ## knit2pdf(..., compiler = 'rst2pdf')
knit2pdf = function(
  input, output = NULL, compiler = NULL, envir = parent.frame(), quiet = FALSE, ...
) {
  out = knit(input, output = output, envir = envir, quiet = quiet)
  owd = setwd(dirname(out)); on.exit(setwd(owd))
  if (is.null(compiler)) {
    compiler = if (grepl('\\.rst$', out)) 'rst2pdf' else 'pdflatex'
  }
  if (identical(compiler, 'rst2pdf')) {
    if (tolower(file_ext(out)) != 'rst')
      stop('for rst2pdf compiler input must be a .rst file')
    rst2pdf(basename(out), ...)
  } else {
    tinytex::latexmk(basename(out), engine = compiler, ...)
  }
  with_ext(out, 'pdf')
}

#' Convert an \file{Rnw} document to PDF
#'
#' Call \code{\link{knit}()} to compile the \file{.Rnw} input to \file{.tex},
#' and then \code{tinytex::\link[tinytex]{latexmk}()} to convert \file{.tex} to
#' \file{.pdf}.
#'
#' This function is similar to \code{\link{knit2pdf}()}, with the following differences:
#' \enumerate{
#'   \item The default compiler is "xelatex" instead of "pdflatex".
#'   \item \code{output} uses the file extension ".pdf" instead of ".tex".
#'   \item Before knitting, it tries to remove the \code{output} file and will throw a clear error if the file cannot be removed.
#'   \item \code{output} could be under any dir, not necessarily the same directory as \code{input}.
#'   \item It cleans up intermediate files by default, including the ".tex" file.
#'   \item It stops knitting when any error occurs (by setting the chunk option \code{error = FALSE}).
#' }
#' @inheritParams knit
#' @param output Path of the PDF output file. By default, it uses the same name
#'   as the \code{input}, but changes the file extension to ".pdf".
#' @param compiler,... The LaTeX engine and other arguments to be passed to
#'   \code{tinytex::\link[tinytex]{latexmk}()}. The default compiler is
#'   \code{xelatex}.
#' @param clean If \code{TRUE}, the intermediate files will be removed.
#' @param error If \code{FALSE}, knitting stops when any error occurs.
#' @return The \code{output} file path.
#' @export
rnw2pdf = function(
  input, output = with_ext(input, 'pdf'), compiler = 'xelatex',
  envir = parent.frame(), quiet = FALSE, clean = TRUE, error = FALSE, ...
) {
  # On Windows, when tweaking the content, users may forget to close the PDF
  # file (thus can't be written). Since knitting may take quite some time, it's
  # better to check the write permission of the output file in advance.
  if (xfun::file_exists(output) && !file.remove(output)) stop(
    "The file '", output, "' cannot be removed (may be locked by a PDF reader)."
  )
  old = opts_chunk$set(error = error)
  on.exit(opts_chunk$set(old), add = TRUE)
  file_tex = knit(input, envir = envir, quiet = quiet)
  if (clean) on.exit(file.remove(file_tex), add = TRUE)
  file_pdf = tinytex::latexmk(file_tex, engine = compiler, clean = clean, ...)
  if (!xfun::same_path(output, file_pdf)) file.rename(file_pdf, output)
  output
}

#' Convert markdown to HTML using knit() and mark_html()
#'
#' This is a convenience function to knit the input markdown source and call
#' \code{markdown::\link[markdown]{mark_html}()} in the \pkg{markdown}
#' package to convert the result to HTML.
#' @inheritParams knit
#' @param ... Options passed to
#'   \code{markdown::\link[markdown]{mark_html}()}.
#' @param force_v1 Boolean; whether to force rendering the input document as an
#'   R Markdown v1 document, even if it is for v2.
#' @export
#' @seealso \code{\link{knit}}, \code{markdown::\link[markdown]{mark_html}}
#' @return If the argument \code{text} is NULL, a character string (HTML code)
#'   is returned; otherwise the result is written into a file and the filename
#'   is returned.
#' @note The \pkg{markdown} package is for R Markdown v1, which is much less
#'   powerful than R Markdown v2, i.e. the \pkg{rmarkdown} package
#'   (\url{https://rmarkdown.rstudio.com}). To render R Markdown v2 documents to
#'   HTML, please use \code{rmarkdown::render()} instead.
#' @examples # a minimal example
#' writeLines(c("# hello markdown", '```{r hello-random, echo=TRUE}', 'rnorm(5)', '```'), 'test.Rmd')
#' knit2html('test.Rmd')
#' if (interactive()) browseURL('test.html')
#'
#' unlink(c('test.Rmd', 'test.html', 'test.md'))
knit2html = function(
  input, output = NULL, ..., envir = parent.frame(), text = NULL,
  quiet = FALSE, encoding = 'UTF-8', force_v1 = getOption('knitr.knit2html.force_v1', FALSE)
) {
  if (is_cran_check() && !has_package('markdown'))
    return(vweave_empty(input, .reason = 'markdown'))

  is_lite = FALSE
  if (!force_v1 && is.null(text)) {
    # test if an Rmd input should be rendered via rmarkdown::render() or (mark|lite)down::mark()
    res = xfun::yaml_body(read_utf8(input))$yaml[['output']]
    if (is.list(res)) res = names(res)
    rmd_v2 = length(res) > 0 && is.character(res) && {
      is_lite = any(grepl('^litedown::', res) | res == 'html')
      !is_lite && !any(grepl('^markdown::', res))
    }
    if (rmd_v2) warning2(
      'It seems you should call rmarkdown::render() instead of knitr::knit2html() ',
      'because ', input, ' appears to be an R Markdown v2 document.'
    )
  }
  out = knit(input, text = text, envir = envir, quiet = quiet)
  mark = if (is_lite) litedown::mark else markdown::mark_html
  if (is.null(text)) {
    output = with_ext(if (is.null(output) || is.na(output)) out else output, 'html')
    mark(out, output, ...)
    invisible(output)
  } else mark(text = out, ...)
}

#' Knit an R Markdown document and post it to WordPress
#'
#' This function is a wrapper around the \pkg{RWordPress} package. It compiles
#' an R Markdown document to HTML and post the results to WordPress. Please note
#' that \pkg{RWordPress} has not been updated for several years, which is
#' \href{https://github.com/yihui/knitr/issues/1866}{not a good sign}. For
#' blogging with R, you may want to try the \pkg{blogdown} package instead.
#' @param input Filename of the Rmd document.
#' @param title Title of the post.
#' @param ... Other meta information of the post, e.g. \code{categories = c('R',
#'   'Stats')} and \code{mt_keywords = c('knitr', 'wordpress')}, et cetera.
#' @param shortcode A length-2 logical vector: whether to use the shortcode
#'   \samp{[sourcecode lang='lang']}, which can be useful to WordPress.com users
#'   for syntax highlighting of source code and output. The first element
#'   applies to source code, and the second applies to text output. By default,
#'   both are \code{FALSE}.
#' @param action Whether to create a new post, update an existing post, or
#'   create a new page.
#' @param postid If \code{action} is \code{editPost}, the post id \code{postid}
#'   must be specified.
#' @param publish Boolean: publish the post immediately?
#' @inheritParams knit
#' @export
#' @references \url{https://yihui.org/knitr/demo/wordpress/}
#' @author William K. Morris, Yihui Xie, and Jared Lander
#' @note This function will convert the encoding of the post and the title to
#'   UTF-8 internally. If you have additional data to send to WordPress (e.g.
#'   keywords and categories), you may have to manually convert them to the
#'   UTF-8 encoding with the \code{\link{iconv}(x, to = 'UTF-8')} function
#'   (especially when using Windows).
#' @examples # see the reference
knit2wp = function(
  input, title = 'A post from knitr', ..., envir = parent.frame(), shortcode = FALSE,
  action = c('newPost', 'editPost', 'newPage'), postid, publish = TRUE
) {
  do.call('library', list(package = 'RWordPress', character.only = TRUE))
  xfun::do_once(
    warning2(
      'This function is based on the RWordPress package, which is no longer actively ',
      'maintained (https://github.com/yihui/knitr/issues/1866). For blogging with R, ',
      'you may try the blogdown package instead.'
    ), 'knitr.knit2wp.warning'
  )
  out = knit(input, envir = envir); on.exit(unlink(out))
  content = read_utf8(out)
  if (missing(title) && length(title2 <- xfun::yaml_body(content)$yaml$title) == 1)
    title = title2
  content = markdown::mark(text = content)
  shortcode = rep(shortcode, length.out = 2L)
  if (shortcode[1]) content = gsub(
    '<pre><code class="([[:alpha:]]+)">(.+?)</code></pre>',
    '[sourcecode language="\\1"]\\2[/sourcecode]', content
  )
  content = gsub(
    '<pre><code( class="no-highlight"|)>(.+?)</code></pre>',
    if (shortcode[2]) '[sourcecode]\\2[/sourcecode]' else '<pre>\\2</pre>', content
  )

  content = enc2utf8(content)
  title = enc2utf8(title)

  # figure out if we are making a newPost or overwriting an existing post
  action = match.arg(action)

  # build a list of arguments to be fed into either newPost or editPost
  # the first argument is the content, which itself is a list containing
  #     description
  #     title
  #     ...
  # then there is the publish argument
  WPargs = list(content = list(description = content, title = title, ...), publish = publish)

  # if we are editing the post, also include the argument for postid
  if (action == "editPost") WPargs = c(postid = postid, WPargs)

  do.call(action, args = WPargs)
}

#' Watch an input file continuously and knit it when it is updated
#'
#' Check the modification time of an input file continously in an infinite loop.
#' Whenever the time indicates the file has been modified, call a function to
#' recompile the input file.
#'
#' This is actually a general function not necessarily restricted to
#' applications in \pkg{knitr}. You may specify any \code{compile} function to
#' process the \code{input} file. To stop the infinite loop, press the
#' \samp{Escape} key or \samp{Ctrl + C} (depending on your editing environment
#' and operating system).
#' @param input An input file path, or a character vector of mutiple input file paths.
#' @param compile A function to compile the \code{input} file. This could be e.g.
#'   \code{\link{knit}} or \code{\link{knit2pdf}}, depending on the input file
#'   and the output you want.
#' @param interval A time interval to pause in each cycle of the infinite loop.
#' @param ... Other arguments to be passed to the \code{compile} function.
#' @export
#' @examples # knit_watch('foo.Rnw', knit2pdf)
#'
#' # knit_watch('foo.Rmd', rmarkdown::render)
knit_watch = function(input, compile = knit, interval = 1, ...) {
  mtime = function(...) file.info(...)[, 'mtime']
  last_time = mtime(input)
  updated = function() {
    this_time = mtime(input)
    on.exit(last_time <<- this_time, add = TRUE)
    this_time > last_time
  }
  for (f in input) compile(f, ...)
  while (TRUE) {
    for (f in input[updated()]) compile(f, ...)
    Sys.sleep(interval)
  }
}
