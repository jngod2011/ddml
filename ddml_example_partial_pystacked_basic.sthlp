{smcl}
{* *! version 28july2023}{...}
{smcl}
{pstd}{ul:Partially-linear model - Basic example with {help pystacked}}{p_end}

{pstd}Load the data, define global macros, set the seed and initialize the model.
Use 2-fold cross-fitting with two repetitions (resamples)
Use {help pystacked}'s default learners as the supervised learners: OLS, cross-validated lasso, and gradient boosting.
NB: The model specification and results will be stored on a Mata object
with the default name "m0".{p_end}

{phang2}. {stata "use https://github.com/aahrens1/ddml/raw/master/data/sipp1991.dta, clear"}{p_end}
{phang2}. {stata "global Y net_tfa"}{p_end}
{phang2}. {stata "global D e401"}{p_end}
{phang2}. {stata "global X tw age inc fsize educ db marr twoearn pira hown"}{p_end}
{phang2}. {stata "set seed 42"}{p_end}
{phang2}. {stata "ddml init partial, kfolds(2) reps(2)"}{p_end}
{phang2}. {stata "ddml E[Y|X]: pystacked $Y $X"}{p_end}
{phang2}. {stata "ddml E[D|X]: pystacked $D $X"}{p_end}
{phang2}. {stata "ddml crossfit"}{p_end}
{phang2}. {stata "ddml estimate"}{p_end}

{pstd}Replicate the {opt ddml estimate} results for the 1st cross-fit estimation (resample 1) by hand,
using the estimated conditional expectations generated by {opt ddml} and {help pystacked};
"_1" means resample 1.
Compare using {opt ddml estimate, replay}.{p_end}

{phang2}. {stata "cap drop Yresid"}{p_end}
{phang2}. {stata "cap drop Dresid"}{p_end}
{phang2}. {stata "gen double Yresid = $Y - Y1_pystacked_1"}{p_end}
{phang2}. {stata "gen double Dresid = $D - D1_pystacked_1"}{p_end}
{phang2}. {stata "regress Yresid Dresid"}{p_end}
{phang2}. {stata "ddml estimate, mname(m0) spec(st) rep(1) notable replay"}{p_end}
