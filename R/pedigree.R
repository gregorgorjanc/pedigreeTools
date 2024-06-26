#### "pedigree" class methods

#' @title Constructor for pedigree objects
#'
#' @description A simple constructor for a pedigree object. The main point for
#'   the constructor is to use coercions to make later function calls easier.
#'
#' @param sire integer vector or factor representation of the sires (see details)
#' @param dam integer vector or factor representation of the dams (see details)
#' @param label integer or character vector of individual labels/names
#'   (see details)
#'
#' @return an pedigree object of class \linkS4class{pedigree}
#'
#' @details \code{sire}, \code{dam} and \code{label} must all have the
#'   same length and all labels in \code{sire} and \code{dam} must occur
#'   in \code{label} unless they are unknown (represented either with \code{0}
#'   or \code{NA} - see examples).
#'
#'   Parents must precede (=appear in a row before) progeny.
#'
#'   See examples on requirements and capability of this function with respect
#'   to encoding and ordering of the parents and progeny. The key point is that
#'   \code{sire} and \code{dam} are first converted to a factor (hence any label
#'   and their order are allowed) and then the factors are converted to an
#'   integer considering \code{label} as the allowed levels and their order.
#'   Importantly, ordering in \code{label} determines the order (see examples).
#'
#'   \code{label} is converted to character internally representing individual
#'   labels/names.
#'
#' @seealso \code{link{editPed}}, \code{link{prunePed}}, and \code{link{ped2DF}}
#'
#' @export
#' @examples
#' # Parent labels as integers with NA as unknown
#' ped <- pedigree(sire = c(NA, NA, 1,  1, 4, 5),
#'                 dam =  c(NA, NA, 2, NA, 3, 2),
#'                 label = 1:6)
#' ped
#'
#' # Parent labels as integers with 0 as unknown
#' ped <- pedigree(sire = c(0, 0, 1, 1, 4, 5),
#'                 dam =  c(0, 0, 2, 0, 3, 2),
#'                 label = 1:6)
#' ped
#'
#' # Parent labels as factors with NA as unknown
#' ids <- letters[1:6]
#' ped <- pedigree(sire = factor(c(NA, NA, "a", "a", "d", "e")),
#'                 dam =  factor(c(NA, NA, "b",  NA, "c", "b")),
#'                 label = ids)
#' ped
#'
#' # Parent labels as factors with 0 as unknown
#' ids <- letters[1:6]
#' ped <- pedigree(sire = factor(c(0, 0, "a", "a", "d", "e")),
#'                 dam =  factor(c(0, 0, "b",   0, "c", "b")),
#'                 label = ids)
#' ped
#'
#' # Showcase ordering requirement/capability (parents precede progeny)
#'     pedigree(sire = c(  0,   1), dam =  c( 0,  0), label = c(  1,   2))  #   correct
#' try(pedigree(sire = c(  1,   0), dam =  c( 0,  0), label = c(  1,   2))) # incorrect
#'     pedigree(sire = c( NA, "A"), dam =  c(NA, NA), label = c("A", "B"))  #   correct
#' try(pedigree(sire = c("A",  NA), dam =  c(NA, NA), label = c("A", "B"))) # incorrect
#'     pedigree(sire = c( NA, "B"), dam =  c(NA, NA), label = c("B", "A"))  #   correct
#' try(pedigree(sire = c("B",  NA), dam =  c(NA, NA), label = c("B", "A"))) # incorrect
#'
#' # Showcase ordering and encoding requirement/capability
#' pedigree(sire = c(NA, NA, "A"), dam =  c(NA, NA, "B"), label = c("A", "B", "D"))
#' pedigree(sire = c(NA, NA, "D"), dam =  c(NA, NA, "B"), label = c("D", "B", "A"))
#' pedigree(sire = c(NA, NA,   1), dam =  c(NA, NA,   4), label = c(  1,   4,   6))
#' pedigree(sire = c(NA, NA,   6), dam =  c(NA, NA,   4), label = c(  6,   4,   1))
pedigree <- function(sire, dam, label) {
    n <- length(sire)
    if (0 %in% label) {
        stop("0 is not an allowed label")
    }
    labelex <- c(label, NA, 0)
    stopifnot(n == length(dam),
              n == length(label),
              all(sire %in% labelex),
              all(dam %in% labelex))
    sire <- as.integer(factor(sire, levels = label))
    dam <- as.integer(factor(dam, levels = label))
    sire[sire < 1 | sire > n] <- NA
    dam[dam < 1 | dam > n] <- NA
    new("pedigree", sire = sire, dam = dam,
        label = as.character(label))
}

setAs("pedigree", "sparseMatrix", # representation as T^{-1}
      function(from) {
	  sire <- from@sire
	  n <- length(sire)
	  animal <- seq_along(sire)
	  j <- c(sire, from@dam)
	  ind <- !is.na(j)
	  as(new("dtTMatrix", i = rep.int(animal, 2)[ind] - 1L,
		 j = j[ind] - 1L, x = rep.int(-0.5, sum(ind)),
		 Dim = c(n,n), Dimnames = list(from@label, NULL),
		 uplo = "L", diag = "U"), "CsparseMatrix")
      })

## these data frames are now storage efficient but print less nicely
setAs("pedigree", "data.frame",
      function(from)
      data.frame(sire = from@sire, dam = from@dam,
		 row.names = from@label))

#' @title Convert a pedigree to a data frame
#'
#' @description Express a pedigree as a data frame with \code{sire} and
#'   \code{dam} stored as factors. If the pedigree is an object of
#'   class \linkS4class{pedinbred} then the inbreeding coefficients are
#'   appended as the variable \code{F}
#'
#' @param x \code{\link{pedigree}}
#' @return a data frame
#' @export
#' @examples
#' ped <- pedigree(sire = c(NA, NA, 1,  1, 4, 5),
#'                 dam =  c(NA, NA, 2, NA, 3, 2),
#'                 label = 1:6)
#' ped2DF(ped)
ped2DF <- function(x) {
    stopifnot(is(x, "pedigree"))
    lab <- x@label
    lev <- seq_along(lab)
    ans <- data.frame(sire = factor(x@sire, levels = lev, labels = lab),
                      dam  = factor(x@dam,  levels = lev, labels = lab),
                      row.names = lab)
    if (is(x, "pedinbred")) ans <- cbind(ans, F = x@F)
    ans
}

setMethod("show", signature(object = "pedigree"),
	  function(object) print(ped2DF(object)))

setMethod("head", "pedigree", function(x, ...)
	  do.call("head", list(x = ped2DF(x), ...)))

setMethod("tail", "pedigree", function(x, ...)
	  do.call("tail", list(x = ped2DF(x), ...)))

#' @useDynLib pedigreeTools pedigree_chol
setMethod("chol", "pedigree",
          function(x, pivot, LINPACK) {
              ttrans <- Matrix::solve(Matrix::t(as(x, "dtCMatrix")))
              .Call(pedigree_chol, x,
                    as(.Call("Csparse_diagU2N", Matrix::t(ttrans), PACKAGE = "Matrix"),
                       "dtCMatrix"))
          })

#' @title Inbreeding coefficients from a pedigree
#'
#' @description Create the inbreeding coefficients according to the algorithm
#'   given in "Comparison of four direct algorithms for computing inbreeding
#'   coefficients" by Mehdi Sargolzaei and Hiroaki Iwaisaki, Animal Science
#'   Journal (2005) 76, 401--406.
#'
#' @param ped \code{\link{pedigree}}
#' @return the inbreeding coefficients as a numeric vector
#' @export
#' @useDynLib pedigreeTools pedigree_inbreeding
#' @examples
#' ped <- pedigree(sire = c(NA, NA, 1,  1, 4, 5),
#'                 dam =  c(NA, NA, 2, NA, 3, 2),
#'                 label = 1:6)
#' (F <- inbreeding(ped))
#'
#' # Test for correctness
#' FExp <- c(0.000, 0.000, 0.000, 0.000, 0.125, 0.125)
#' stopifnot(!any(abs(F - FExp) > .Machine$double.eps))
inbreeding <- function(ped) {
    stopifnot(is(ped, "pedigree"))
    .Call(pedigree_inbreeding, ped)
}

#' @title Mendelian sampling variance
#'
#' @description Determine the diagonal factor in the decomposition of the
#'   relationship matrix A as TDT' where T is unit lower triangular.
#'
#' @param ped \code{\link{pedigree}}
#' @param vector logical, return a vector or sparse matrix
#' @return a numeric vector
#' @export
#' @examples
#' ped <- pedigree(sire = c(NA, NA, 1,  1, 4, 5),
#'                 dam =  c(NA, NA, 2, NA, 3, 2),
#'                 label = 1:6)
#' (D <- getD(ped))
#' (DInv <- getDInv(ped))
#'
#' # Test for correctness
#' DExp <- c(1.00, 1.00, 0.50, 0.75, 0.50, 0.46875)
#' stopifnot(!any(abs(D - DExp) > .Machine$double.eps))
#'
#' DInvExp <- 1 / DExp
#' stopifnot(!any(abs(DInv - DInvExp) > .Machine$double.eps))
Dmat <- function(ped, vector = TRUE) {
    F <- inbreeding(ped)
    sire <- ped@sire
    dam <- ped@dam
    Fsire <- ifelse(is.na(sire), -1, F[sire])
    Fdam <- ifelse(is.na(dam), -1, F[dam])
    ans <- 1 - 0.25 * (2 + Fsire + Fdam)
    if (vector) {
        names(ans) <- ped@label
    } else {
        ans <- Matrix::Diagonal(x = ans)
        dimnames(ans) <- list(ped@label, ped@label)
    }
    ans
}

#' @describeIn Dmat Mendelian sampling variance
#' @export
getD <- Dmat

#' @describeIn Dmat  Mendelian sampling precision (= 1 / variance)
#' @export
getDInv <- function(ped, vector = TRUE) {
    ans <- 1 / getD(ped)
    if (!vector) {
        ans <- Matrix::Diagonal(x = ans)
        dimnames(ans) <- list(ped@label, ped@label)
    }
    ans
}

#' @title Inverse gene flow from a pedigree
#'
#' @description Get inverse gene flow matrix from a pedigree.
#'
#' @param ped \code{\link{pedigree}}
#' @return matrix (\linkS4class{dtCMatrix} - lower unitriangular sparse)
#' @export
#' @examples
#' ped <- pedigree(sire = c(NA, NA, 1,  1, 4, 5),
#'                 dam =  c(NA, NA, 2, NA, 3, 2),
#'                 label = 1:6)
#' (TInv <- getTInv(ped))
#'
#' # Test for correctness
#' TInvExp <- matrix(data = c( 1.0,  0.0,  0.0,  0.0,  0.0,  0.0,
#'                             0.0,  1.0,  0.0,  0.0,  0.0,  0.0,
#'                            -0.5, -0.5,  1.0,  0.0,  0.0,  0.0,
#'                            -0.5,  0.0,  0.0,  1.0,  0.0,  0.0,
#'                             0.0,  0.0, -0.5, -0.5,  1.0,  0.0,
#'                             0.0, -0.5,  0.0,  0.0, -0.5,  1.0),
#'                   byrow = TRUE, nrow = 6)
#' stopifnot(!any(abs(TInv  - TInvExp) > .Machine$double.eps))
#' stopifnot(is(TInv, "sparseMatrix"))
getTInv <- function(ped) {
    stopifnot(is(ped, "pedigree"))
    TInv <- as(ped, "sparseMatrix")
    dimnames(TInv) <- list(ped@label, ped@label)
    TInv
}

#' @title Gene flow from a pedigree
#'
#' @description Get gene flow matrix from a pedigree.
#'
#' @param ped \code{\link{pedigree}}
#' @return matrix (\linkS4class{dtCMatrix} - lower unitriangular sparse)
#' @export
#' @examples
#' ped <- pedigree(sire = c(NA, NA, 1,  1, 4, 5),
#'                 dam =  c(NA, NA, 2, NA, 3, 2),
#'                 label = 1:6)
#' (T <- getT(ped))
#'
#' # Test for correctness
#' TExp <- matrix(data = c(1.00, 0.000, 0.00, 0.00, 0.0, 0,
#'                         0.00, 1.000, 0.00, 0.00, 0.0, 0,
#'                         0.50, 0.500, 1.00, 0.00, 0.0, 0,
#'                         0.50, 0.000, 0.00, 1.00, 0.0, 0,
#'                         0.50, 0.250, 0.50, 0.50, 1.0, 0,
#'                         0.25, 0.625, 0.25, 0.25, 0.5, 1),
#'                byrow = TRUE, nrow = 6)
#' stopifnot(!any(abs(T  - TExp) > .Machine$double.eps))
getT <- function(ped) {
    T <- Matrix::solve(getTInv(ped))
    dimnames(T) <- list(ped@label, ped@label)
    T
}

#' @title Relationship factor from a pedigree
#'
#' @description Determine the right Cholesky factor of the relationship matrix
#'   for the pedigree \code{ped}, possibly restricted to the specific labels
#'   that occur in \code{labs}.
#'
#' @param ped \code{\link{pedigree}}
#' @param labs a character vector or a factor giving individual labels to
#'   which to restrict the relationship matrix and corresponding factor using
#'   Colleau et al. (2002) algorithm. If \code{labs} is a factor then the levels
#'   of the factor are used as the labels. Default is the complete set of
#'   individuals in the pedigree.
#'
#' @details Note that the right Cholesky factor is returned, which is upper
#'   triangular, that is from A = LL' = R'R (lower %*% upper) we get R = L'
#'   (upper triangular) and not L (lower triangular).
#'
#' @references Colleau, J.-J. An indirect approach to the extensive calculation of
#'   relationship coefficients. Genet Sel Evol 34, 409 (2002).
#'   https://doi.org/10.1186/1297-9686-34-4-409
#'
#' @return matrix (\linkS4class{dtCMatrix} - upper triangular sparse)
#' @export
#' @examples
#' ped <- pedigree(sire = c(NA, NA, 1,  1, 4, 5),
#'                 dam =  c(NA, NA, 2, NA, 3, 2),
#'                 label = 1:6)
#' (L <- getL(ped))
#' chol(getA(ped))
#'
#' # Test for correctness
#' LExp <- matrix(data = c(1.0000, 0.0000, 0.5000, 0.5000, 0.5000, 0.2500,
#'                         0.0000, 1.0000, 0.5000, 0.0000, 0.2500, 0.6250,
#'                         0.0000, 0.0000, 0.7071, 0.0000, 0.3536, 0.1768,
#'                         0.0000, 0.0000, 0.0000, 0.8660, 0.4330, 0.2165,
#'                         0.0000, 0.0000, 0.0000, 0.0000, 0.7071, 0.3536,
#'                         0.0000, 0.0000, 0.0000, 0.0000, 0.0000, 0.6847),
#'                byrow = TRUE, nrow = 6)
#' stopifnot(!any(abs(round(L, digits = 4) - LExp) > .Machine$double.eps))
#' LExp <- chol(getA(ped))
#' stopifnot(!any(abs(L - LExp) > .Machine$double.eps))
#'
#' (L <- getL(ped, labs = 4:6))
#' (LExp <- chol(getA(ped)[4:6, 4:6]))
#' stopifnot(!any(abs(L - LExp) > .Machine$double.eps))
relfactor <- function(ped, labs = NULL) {
    stopifnot(is(ped, "pedigree"))
    if (is.null(labs)) {
        # A = TDT' = TSST'
        #   = LL' = R'R --> L' = ST' = R
        return(sqrt(getD(ped, vector = FALSE)) %*% Matrix::t(getT(ped)))
    }
    # Drop unused levels and set possible levels
    labs <- factor(labs, levels = ped@label)
    stopifnot(all(labs %in% ped@label))
    # Right Cholesky factor L' = R
    LSubset <- Matrix::chol(getASubset(ped = ped, labs = labs)) # dgCMatrix (sparse)
    # TODO: why is LSubset dense matrix (standard) and not sparse upper triangular?
    dimnames(LSubset) <- list(labs, labs)
    LSubset
}

#' @describeIn relfactor Relationship factor from a pedigree
#' @export
getL <- relfactor

#' @title Inverse relationship factor from a pedigree
#'
#' @description Get inverse of the left Cholesky factor of the relationship
#'   matrix for the pedigree \code{ped}.
#'
#' @details Note that the inverse of the left Cholesky factor is returned,
#'   which is lower triangular, that is from A = LL' (lower %*% upper) and
#'   inv(A) = inv(LL') = inv(L)' inv(L) (upper %*% lower) we get inv(L) (lower
#'   triangular).
#'
#' @param ped \code{\link{pedigree}}
#' @return matrix (\linkS4class{dtCMatrix} - triangular sparse)
#' @export
#' @examples
#' ped <- pedigree(sire = c(NA, NA, 1,  1, 4, 5),
#'                 dam =  c(NA, NA, 2, NA, 3, 2),
#'                 label = 1:6)
#' (LInv <- getLInv(ped))
#' solve(Matrix::t(getL(ped)))
#'
#' # Test for correctness
#' LInvExp <- matrix(data = c( 1.0000,  0.0000,  0.0000,  0.0000,  0.0000, 0.0000,
#'                             0.0000,  1.0000,  0.0000,  0.0000,  0.0000, 0.0000,
#'                            -0.7071, -0.7071,  1.4142,  0.0000,  0.0000, 0.0000,
#'                            -0.5774,  0.0000,  0.0000,  1.1547,  0.0000, 0.0000,
#'                             0.0000,  0.0000, -0.7071, -0.7071,  1.4142, 0.0000,
#'                             0.0000, -0.7303,  0.0000,  0.0000, -0.7303, 1.4606),
#'                   byrow = TRUE, nrow = 6)
#' stopifnot(!any(abs(round(LInv, digits = 4) - LInvExp) > .Machine$double.eps))
#' L <- t(chol(getA(ped)))
#' LInvExp <- solve(L)
#' stopifnot(!any(abs(LInv - LInvExp) > .Machine$double.eps))
#' stopifnot(is(LInv, "sparseMatrix"))
relfactorInv <- function(ped) {
    # A = LL' (lower %*% upper)
    # inv(A) = inv(LL')
    #        = inv(L') inv(L) (upper %*% lower)
    #        = inv(L)' inv(L) (upper %*% lower)
    # A = TDT' (lower %*% diag %*% upper)
    # inv(A) = inv(TDT')
    #        = inv(T') inv(D) inv(T) (upper %*% diag %*% lower)
    #        = inv(T)' inv(D) inv(T) (upper %*% diag %*% lower)
    # --> We must premultiply inv(T) with sqrt(inv(D))
    TInv <- getTInv(ped) # dtCMatrix (lower triangular sparse)
    DSqInv <- Matrix::Diagonal(x = sqrt(getDInv(ped))) # ddiMatrix (diagonal sparse)
    LInv <- DSqInv %*% TInv  # dtCMatrix (lower triangular sparse)
    dimnames(LInv) <- list(ped@label, ped@label)
    LInv
}

#' @describeIn relfactorInv Inverse relationship factor from a pedigree
#' @export
getLInv <- relfactorInv

#' @title Inverse of the additive relationship matrix
#'
#' @description Returns the inverse of additive relationship matrix for the
#'   pedigree.
#'
#' @param ped \code{\link{pedigree}}
#' @return matrix (\linkS4class{dsCMatrix} - symmetric sparse)
#' @export
#' @examples
#' ped <- pedigree(sire = c(NA, NA, 1,  1, 4, 5),
#'                 dam =  c(NA, NA, 2, NA, 3, 2),
#'                 label = 1:6)
#' (AInv <- getAInv(ped))
#'
#' # Test for correctness
#' AInvExp <- matrix(data = c( 1.833,  0.500, -1.000, -0.667,  0.000,  0.000,
#'                             0.500,  2.033, -1.000,  0.000,  0.533, -1.067,
#'                            -1.000, -1.000,  2.500,  0.500, -1.000,  0.000,
#'                            -0.667,  0.000,  0.500,  1.833, -1.000,  0.000,
#'                             0.000,  0.533, -1.000, -1.000,  2.533, -1.067,
#'                             0.000, -1.067,  0.000,  0.000, -1.067,  2.133),
#'                   byrow = TRUE, nrow = 6)
#' stopifnot(!any(abs(round(AInv, digits = 3) - AInvExp) > .Machine$double.eps))
#' AInvExp <- solve(getA(ped))
#' stopifnot(!any(abs(round(AInv, digits = 14) - round(AInvExp, digits = 14)) > .Machine$double.eps))
#' stopifnot(is(AInv, "sparseMatrix"))
#' stopifnot(Matrix::isSymmetric(AInv))
getAInv <- function(ped) {
    # A = LL' (lower %*% upper)
    # inv(A) = inv(LL')
    #        = inv(L') inv(L) (upper %*% lower)
    #        = inv(L)' inv(L) (upper %*% lower)
    # crossprod() does X'X --> inv(L)' inv(L)
    stopifnot(is(ped, "pedigree"))
    AInv <- Matrix::crossprod(getLInv(ped)) # dsCMatrix (symmetric sparse)
    dimnames(AInv) <- list(ped@label, ped@label)
    AInv
}

#' @title Additive relationship matrix
#'
#' @description Returns the additive relationship matrix for the pedigree.
#'
#' @param ped \code{\link{pedigree}}
#' @param labs a character vector or a factor giving individual labels to
#'   which to restrict the relationship matrix and corresponding factor. If
#'   \code{labs} is a factor then the levels of the factor are used as the
#'   labels. Default is the complete set of individuals in the pedigree.
#'
#' @return matrix (\linkS4class{dsCMatrix} - symmetric sparse)
#' @export
#' @examples
#' ped <- pedigree(sire = c(NA, NA, 1,  1, 4, 5),
#'                 dam =  c(NA, NA, 2, NA, 3, 2),
#'                 label = 1:6)
#' (A <- getA(ped))
#'
#' # Test for correctness
#' AExp <- matrix(data = c(1.0000, 0.0000, 0.5000, 0.5000, 0.5000, 0.2500,
#'                         0.0000, 1.0000, 0.5000, 0.0000, 0.2500, 0.6250,
#'                         0.5000, 0.5000, 1.0000, 0.2500, 0.6250, 0.5625,
#'                         0.5000, 0.0000, 0.2500, 1.0000, 0.6250, 0.3125,
#'                         0.5000, 0.2500, 0.6250, 0.6250, 1.1250, 0.6875,
#'                         0.2500, 0.6250, 0.5625, 0.3125, 0.6875, 1.1250),
#'                byrow = TRUE, nrow = 6)
#' stopifnot(!any(abs(A - AExp) > .Machine$double.eps))
#' stopifnot(Matrix::isSymmetric(A))
getA <- function(ped, labs = NULL) {
    if (is.null(labs)) {
        # A = LL' = R'R
        # crossprod() does X'X --> R'R
        aMx <- Matrix::crossprod(getL(ped, labs = labs))
        dimnames(aMx) <- list(ped@label, ped@label)
    } else {
        aMX <- getASubset(ped = ped, labs = labs)
    }
    aMx
}

#' @title Subset of additive relationship matrix
#'
#' @description Returns subset of the additive relationship matrix for the pedigree.
#'
#' @param ped \code{\link{pedigree}}
#' @param labs a character vector or a factor giving individual labels to
#'   which to restrict the relationship matrix and corresponding factor using
#'   Colleau et al. (2002) algorithm. If \code{labs} is a factor then the levels
#'   of the factor are used as the labels. Default is the complete set of
#'   individuals in the pedigree.
#'
#' @references Colleau, J.-J. An indirect approach to the extensive calculation of
#'   relationship coefficients. Genet Sel Evol 34, 409 (2002).
#'   https://doi.org/10.1186/1297-9686-34-4-409
#'
#' @return matrix (\linkS4class{dsCMatrix} - symmetric sparse)
#' @export
#' @examples
#' ped <- pedigree(sire = c(NA, NA, 1,  1, 4, 5),
#'                 dam =  c(NA, NA, 2, NA, 3, 2),
#'                 label = 1:6)
#' (A <- getA(ped))
#' (ASubset  <- A[4:6, 4:6])
#' (ASubset2 <- getASubset(ped, labs = 4:6))
#'
#' (ASubset3  <- A[6:4, 6:4])
#' (ASubset4 <- getASubset(ped, labs = 6:4))
#'
#' # Test for correctness
#' stopifnot(!any(abs(ASubset - ASubset2) > .Machine$double.eps))
#' stopifnot(!any(abs(ASubset3 - ASubset4) > .Machine$double.eps))
#' stopifnot(Matrix::isSymmetric(ASubset2))
#' stopifnot(Matrix::isSymmetric(ASubset4))
#' # ... with pedigree that does not have individuals coded 1:n
#' ped2 <- pedigree(sire = c(NA, NA, 2,  2, 5, 6),
#'                  dam =  c(NA, NA, 3, NA, 4, 3),
#'                  label = 2:7)
#' ASubsetShift <- getASubset(ped2, labs = 5:7)
#' stopifnot(!any(abs(ASubset2 - ASubsetShift) > .Machine$double.eps))
getASubset <- function(ped, labs) {
    stopifnot(is(ped, "pedigree"))
    stopifnot(!missing(labs))
    nLabs <- length(labs)
    nInd <- length(ped@label)
    # A x = y; if x is all 0s and a 1 in the k-th position then y is A[, k]
    # inv(A) A x = inv(A) y
    # inv(A) y = x; solve for y to get A[, k] - column
    # inv(A) Y = X; solve for Y to get A[, k] - matrix
    numLabs <- match(x = labs, table = ped@label, nomatch = 0)
    check <- numLabs == 0
    if (any(check)) {
        stop(paste0("These labs are no present in the pedigree: ", labs[check]))
    }
    X <- Matrix::sparseMatrix(i = numLabs, j = 1:nLabs,
                              x = 1, dims = c(nInd, nLabs)) # dgCMatrix (sparse)
    ASubset <- Matrix::solve(getAInv(ped), X)[numLabs, ] # dgCMatrix (sparse)
    ASubset <- as(ASubset, "symmetricMatrix") # dsCMatrix (sparse)
    dimnames(ASubset) <- list(labs, labs)
    ASubset
}

#' @title Counts number of generations of ancestors for one subject. Use recursion.
#'
#' @param ped data.frame with a pedigree and a column for the number of
#'   generations of each subject.
#' @param id subject for which we want the number of generations.
#' @param ngen number of generation
#' @return a data frame object with the pedigree and generation of
#'   ancestors for subject id.
#' @export
#' @examples
#' ped <- pedigree(sire = c(NA, NA, 1,  1, 4, 5),
#'                 dam =  c(NA, NA, 2, NA, 3, 2),
#'                 label = 1:6)
#' ped <- ped2DF(ped)
#' ped$id <- row.names(ped)
#' ped$generation <- NA
#' (tmp1 <- getGenAncestors(ped, id = 1))
#' (tmp2 <- getGenAncestors(ped, id = 4))
#' (tmp3 <- getGenAncestors(ped, id = 6))
#'
#' # Test for correctness
#' stopifnot(tmp1$generation[1] == 0)
#' stopifnot(all(is.na(tmp1$generation[-1])))
#' stopifnot(all(tmp2$generation[c(1, 4)] == c(0, 1)))
#' stopifnot(all(is.na(tmp2$generation[-c(1, 4)])))
#' stopifnot(all(tmp3$generation == c(0, 0, 1, 1, 2, 3)))
getGenAncestors <- function(ped, id, ngen = NULL) {
    j <- which(ped$id == id)
    parents <- c(ped$sire[j], ped$dam[j])
    parents <- parents[!is.na(parents)]
    np <- length(parents)
    if (np == 0) {
        ped$generation[j] <-0
        return(ped)
    }
    ## get the number of generations in parent number one
    tmpgenP1 <- ped$generation[ped$id == parents[1]]
    if (is.na(tmpgenP1)) {
        #if ngen is not null, and not cero, ngen<- ngen-1
        #if ngen is cero, do not call recurrsively anymore
        ped <- getGenAncestors(ped, parents[1])
        genP1  <- 1 + ped$generation[ped$id == parents[1]]
    } else {
        genP1 <- 1 + tmpgenP1
    }
    ## find out if there is a parent number two
    if (np == 2) {
        tmpgenP2 <- ped$generation[ped$id == parents[2]]
        if(is.na(tmpgenP2)) {
            ped <- getGenAncestors(ped, parents[2])
            genP2  <- 1 + ped$generation[ped$id == parents[2]]
        } else {
            genP2 <- 1 + tmpgenP2
        }
        genP1 <- max(genP1, genP2)
    }
    ped$generation[j] <- genP1
    ## print(paste('id:', id, ', gen:', genP1, ', row:', j))
    ped
}

#' @title Edits a disordered or incomplete pedigree
#'
#' @description Edits a disordered or incomplete pedigree by:
#'   1) adding labels for the sires and dams not listed as labels before and
#'   2) ordering pedigree based on recursive calls to \code{\link{getGenAncestors}}.
#'
#' @param sire integer vector or factor representation of the sires
#' @param dam integer vector or factor representation of the dams
#' @param label character vector of labels
#' @param verbose logical to print the row of the pedigree that the
#'   function is ordering. Default is FALSE.
#' @return a data frame with the pedigree ordered.
#' @export
#' @examples
#' ped <- data.frame(sire=as.character(c(NA,NA,NA,NA,NA,1,3,5,6,4,8,1,10,8)),
#'                   dam=as.character(c(NA,NA,NA,NA,NA,2,2,NA,7,7,NA,9,9,13)),
#'                   label=as.character(1:14))
#' ped <- ped[sample(replace=FALSE, 1:14),]
#' ped <- editPed(sire = ped$sire, dam = ped$dam, label = ped$label)
#' ped <- with(ped, pedigree(label = label, sire = sire, dam = dam))
editPed <- function(sire, dam, label, verbose = FALSE) {
    nped <- length(sire)
    if (nped != length(dam))  stop("sire and dam have to be of the same length")
    if (nped != length(label)) stop("label has to be of the same length than sire and dam")
    tmp <- unique(sort(c(as.character(sire), as.character(dam))))

    missingP <- NULL
    if (any(completeId <- !(tmp %in% as.character(label)))) {
        missingP <- tmp[completeId]
    }
    labelOl <- c(as.character(missingP),as.character(label))
    sireOl <- c(rep(NA, times = length(missingP)), as.character(sire))
    damOl  <- c(rep(NA, times = length(missingP)), as.character(dam))
    sire <- as.integer(factor(sireOl, levels = labelOl))
    dam <- as.integer(factor(damOl, levels = labelOl))
    nped <-length(labelOl)
    label <-1:nped
    sire[!is.na(sire) & (sire < 1 | sire > nped)] <- NA
    dam[!is.na(dam) & (dam < 1 | dam > nped)] <- NA
    ped <- data.frame(id = label, sire = sire, dam = dam,
                      generation = rep(NA, times = nped))
    noParents <- (is.na(ped$sire) & is.na(ped$dam))
    ped$generation[noParents] <- 0
    for (i in 1:nped) {
        if(verbose) print(i)
        if(is.na(ped$generation[i])){
            id <-ped$id[i]
            ped <-getGenAncestors(ped, id)
        }
    }
    ord <- order(ped$generation)
    ans <- data.frame(label = labelOl, sire = sireOl, dam = damOl,
                      generation = ped$generation, stringsAsFactors = FALSE)
    ans[ord,]
}

#' @title Subsets a pedigree for a specified vector of individuals up to a
#' specified number of previous generations using recursion.

#' @param ped Data Frame pedigree to be subset
#' @param selectVector Vector of individuals to select from pedigree
#' @param ngen Number of previous generations of parents to select starting from selectVector.

#' @return Returns Subsetted pedigree as a DataFrame.
#' @export
#' @examples
#' ped <- pedigree(sire = c(NA, NA, 1,  1, 4, 5),
#'                 dam =  c(NA, NA, 2, NA, 3, 2),
#'                 label = 1:6)
prunePed <- function(ped, selectVector, ngen = 2) {

  ped <- as.matrix(ped)

  returnPed <- matrix(c(NA, NA, NA), nrow = 1, ncol = 3)

  findBase <- ped[, "label"] %in% selectVector
  basePed <- ped[findBase, ]
  findSire <- ped[, "label"] %in% basePed[, "sire"]
  findDam <- ped[, "label"] %in% basePed[, "dam"]

  newSelVec <- ped[findSire | findDam, "label"]
  newSelVec <- newSelVec[!(newSelVec %in% selectVector)]

  if (ngen != -1) {
    returnPed <- basePed
    returnPed <- unique(rbind(returnPed, prunePed(ped, newSelVec, ngen - 1)))
    returnPed <- returnPed[rowSums(is.na(returnPed)) != 3, ]
  } else {
    return(returnPed)
  }

  return(as.data.frame(returnPed))
}
