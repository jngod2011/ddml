{smcl}
{* *! version 26july2023}{...}
{smcl}
{pstd}{ul:Partially-linear model - Detailed example with stacking regression using {help pystacked}}

{pstd}Preparation: we load the data, define global macros and set the seed.{p_end}

{phang2}. {stata "use https://github.com/aahrens1/ddml/raw/master/data/sipp1991.dta, clear"}{p_end}
{phang2}. {stata "global Y net_tfa"}{p_end}
{phang2}. {stata "global D e401"}{p_end}
{phang2}. {stata "global X tw age inc fsize educ db marr twoearn pira hown"}{p_end}
{phang2}. {stata "set seed 42"}{p_end}

{pstd}We next initialize the ddml estimation and select the model.
{it:partial} refers to the partially linear model.
The model will be stored on a Mata object with the default name "m0"
unless otherwise specified using the {opt mname(name)} option.{p_end}

{pstd}We set the number of random folds to 2 so that 
the model runs quickly. The default is {opt kfolds(5)}. We recommend 
considering at least 5-10 folds and even more if your sample size is small.{p_end}

{pstd}We recommend re-running the model multiple times on 
different random folds; see options {opt reps(integer)}.
Here we set the number of repetions to 2, again only so that the model runs quickly.{p_end}

{phang2}. {stata "ddml init partial, kfolds(2) reps(2)"}{p_end}

{pstd}Stacking regression is a simple and powerful method for 
combining predictions from multiple learners.
Here we use {help pystacked} with the partially linear model,
but it can be used with any model supported by {cmd:ddml}.{p_end}

{pstd}Note: the additional support provided by {opt ddml} for {help pystacked} (see {help ddml##pystacked:above})
is available only if, as in this example, {help pystacked} is the only learner for each conditional expectation.
Mutliple learners are provided to {help pystacked}, not directly to {opt ddml}.

{pstd}Add supervised machine learners for estimating conditional expectations.
The first learner in the stacked ensemble is OLS.
We also use cross-validated lasso, ridge and two random forests with different settings, 
which we save in the following macros:{p_end}

{phang2}. {stata "global rflow max_features(5) min_samples_leaf(1) max_samples(.7)"}{p_end}
{phang2}. {stata "global rfhigh max_features(5) min_samples_leaf(10) max_samples(.7)"}{p_end}

{phang2}. {stata "ddml E[Y|X]: pystacked $Y $X || method(ols) || method(lassocv) || method(ridgecv) || method(rf) opt($rflow) || method(rf) opt($rfhigh), type(reg)"}{p_end}
{phang2}. {stata "ddml E[D|X]: pystacked $D $X || method(ols) || method(lassocv) || method(ridgecv) || method(rf) opt($rflow) || method(rf) opt($rfhigh), type(reg)"}{p_end}

{pstd}Note: Options before ":" and after the first comma refer to {cmd:ddml}. 
Options that come after the final comma refer to the estimation command. 
Make sure to not confuse the two types of options.{p_end}

{pstd}Check if learners were correctly added:{p_end}

{phang2}. {stata "ddml desc, learners"}{p_end}

{pstd} Cross-fitting: The learners are iteratively fitted on the training data.
This step may take a while, depending on the number of learners, repetitions, folds, etc.
In addition to the standard stacking done by {help pystacked},
also request short-stacking to be done by {opt ddml}.
Whereas stacking relies on (out-of-sample) cross-validated predicted values
to obtain the relative weights for the base learners,
short-stacking uses the (out-of-sample) cross-fitted predicted values.{p_end}

{phang2}. {stata "ddml crossfit, shortstack"}{p_end}

{pstd}Finally, we estimate the coefficients of interest.{p_end}

{phang2}. {stata "ddml estimate, robust"}{p_end}

{pstd}Examine the standard ({cmd:pystacked}) stacking weights as well as the {opt ddml} short-stacking weights.{p_end}

{phang2}. {stata "ddml extract, show(stweights)"}{p_end}
{phang2}. {stata "ddml extract, show(ssweights)"}{p_end}

{pstd}Replicate the {opt ddml estimate} short-stacking results for resample 2 by hand,
using the estimated conditional expectations generated by {opt ddml},
and compare using {opt ddml estimate, replay}:{p_end}

{phang2}. {stata "cap drop Yresid"}{p_end}
{phang2}. {stata "cap drop Dresid"}{p_end}
{phang2}. {stata "gen double Yresid = $Y - Y_net_tfa_ss_2"}{p_end}
{phang2}. {stata "gen double Dresid = $D - D_e401_ss_2"}{p_end}
{phang2}. {stata "regress Yresid Dresid, robust"}{p_end}
{phang2}. {stata "ddml estimate, mname(m0) spec(ss) rep(2) notable replay"}{p_end}

{pstd}Obtain the estimated coefficient using ridge - the 3rd {help pystacked} learner - 
as the only learner for the 2nd cross-fit estimation (resample 2),
using the estimated conditional expectations generated by {opt ddml} and {help pystacked}.
This can be done using {opt ddml estimate} with the {opt y(.)} and {opt d(.)} options:
"L3" means the 3rd learner and "_2" means resample 2.
Then replicate by hand.{p_end}

{phang2}. {stata "ddml estimate, y(Y1_pystacked_L3_2) d(D1_pystacked_L3_2) robust"}{p_end}
{phang2}. {stata "cap drop Yresid"}{p_end}
{phang2}. {stata "cap drop Dresid"}{p_end}
{phang2}. {stata "gen double Yresid = $Y - Y1_pystacked_L3_2"}{p_end}
{phang2}. {stata "gen double Dresid = $D - D1_pystacked_L3_2"}{p_end}
{phang2}. {stata "regress Yresid Dresid, robust"}{p_end}
