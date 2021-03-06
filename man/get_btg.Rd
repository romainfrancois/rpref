% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/visualize.r
\name{get_btg}
\alias{get_btg}
\alias{get_btg_dot}
\alias{plot_btg}
\title{Better-Than-Graph}
\usage{
get_btg(df, pref, flip.edges = FALSE)

plot_btg(df, pref, labels = 1:nrow(df), flip.edges = FALSE)

get_btg_dot(df, pref, labels = 1:nrow(df), flip.edges = FALSE,
  file = NULL)
}
\arguments{
\item{df}{A data frame.}

\item{pref}{A preference on the columns of \code{df}, see \code{\link{psel}} for details.}

\item{flip.edges}{(optional) Flips the orientation of edges,
if \code{TRUE} than arrows point from worse nodes to better nodes.}

\item{labels}{(optional) Labels for the vertices. Default values are the row indices.}

\item{file}{(optional) If specified, then \code{get_btg_dot} writes the graph specification to 
given file path. If not specified, the graph specification is returned as a string.}
}
\description{
Returns a Hasse diagram of a preference order (also called the Better-Than-Graph, short BTG) on a given data set. 
Either uses the igraph package or generates output for graphviz/DOT.
}
\details{
The function \code{get_btg} returns a list \code{l} with the following list entries:

\describe{
  \item{\code{l$graph}}{An igraph object, created with the \code{\link{igraph}} package.}
  \item{\code{l$layout}}{A typical Hasse diagram layout for plotting the graph, also created with igraph.}
}

To plot the resulting graph returned from \code{get_btg}, use the \code{plot} function as follows: 

\code{plot(l$graph, layout = l$layout)}. 

For more details, see \code{\link{igraph.plotting}} and the examples below.
The function \code{plot_btg} directly plots the Better-Than-Graph 
some defaults values for e.g., vertex size, using igraph.

The Hasse diagram of a preference visualizes all the better-than-relationships on a given data set.
All edges which can be retrieved by transitivity of the order are omitted.
}
\section{DOT (Graphviz) Output}{


The function \code{get_btg_dot} produces the graph specification of the Better-Than-Graph in the DOT language
of the Graphviz software. To produce the graph from that, you need the DOT interpreter. 
Depending on the \code{file} parameter the output is either written to a file or returned as a string.

As the DOT layouter is suited for strict orders, the layouts of strict oder preference are generelly better
than those generated with igraph. DOT ensures that all edges are oriented in the same direction and
the number of overlaps is low.
}

\section{Additional Parameters}{


By default, the arrows in the diagram point from better to worse nodes w.r.t. the preference. 
This means an arrow can be read as "is better than". If \code{flip.edges = TRUE} is set, 
then the arrows point from worse nodes to better nodes ("is worse than"). 
In any case, the better nodes are plotted at the top and the worse nodes at the bottom of the diagram.

The names of the vertices are characters ranging from \code{"1"} to \code{as.character(nrow(df))} 
and they correspond to the row numbers of \code{df}. 
By default, these are also the labels of the vertices. 
Alternatively, they can be defined manually 
using the \code{labels} parameter of \code{plot_btg} or \code{get_btg_dot}.
}
\examples{

# pick a small data set and create preference and BTG 
df <- mtcars[1:10,]
pref <- high(mpg) * low(wt)

# directly plot the BTG with row numbers as labels
plot_btg(df, pref) 

# create the BTG and labels for the nodes with relevant values
btg <- get_btg(df, pref)
labels <- paste0(df$mpg, "\\n", df$wt)

# plot the graph using igraph
library(igraph)
plot(btg$graph, layout = btg$layout, vertex.label = labels,
     vertex.size = 25)
     
# Create a graph with Graphviz (requires installed Graphviz)
\dontrun{
# creates tmpgraph.dot in the current working directoy
get_btg_dot(df, pref, labels, file = "tmpgraph.dot")
# convert to diagram tmpgraph.png using Graphviz
shell(paste0('"C:/Program Files (x86)/Graphviz2.38/bin/dot.exe"',
             ' -Tpng tmpgraph.dot -o tmpgraph.png'))
# open resulting image
shell("tmpgraph.png")}


# show lattice structure of 3-dimensional Pareto preference in igraph
df <- merge(merge(data.frame(x = 1:3), data.frame(y = 1:3)), data.frame(z = 1:2))
labels <- paste0(df$x, ",", df$y, ",", df$z)
btg <- get_btg(df, low(x) * low(y) * low(z))
plot(btg$graph, layout = btg$layout, vertex.label = labels, 
     vertex.size = 20)


}
\seealso{
\code{\link{igraph.plotting}}
}

