\name{take.samples}
\alias{take.samples}
\title{Sample from normal distribution, given summary stats}
\usage{
  take.samples(summary, sample.size = 10^6)
}
\arguments{
  \item{trait}{data.frame with values of mean and sd}

  \item{sample.size}{}
}
\value{
  sample of length sample.size
}
\description{
  sample from normal distribution, given summary stats
}
\examples{
## return the mean when stat = NA
take.samples(summary = data.frame(mean = 10, stat = NA))
## return vector of length \\code{sample.size} from N(mean,stat)
take.samples(summary = data.frame(mean = 10, stat = 10), sample.size = 10)
}
\author{
  David LeBauer, Carl Davidson
}

