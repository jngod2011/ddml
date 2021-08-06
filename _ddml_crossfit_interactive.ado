* last edited: 18 jun 2021

* notes:
* why is crossfitted field set in additive code but not here?
* check it's correct that interactive-type estimation always goes with reporting mse0 and mse1
* are multiple Zs allowed?

*** ddml cross-fitting for the interactive model & LATE
program _ddml_crossfit_interactive, eclass sortpreserve

	syntax [anything] [if] [in] , /// 
							[ kfolds(integer 2)		///
							NOIsily					///
							debug					/// 
							Robust					///
							TABFold					///
							foldlist(numlist)		///
							mname(name)				///
							reps(integer 1)			///
							yrclass					///
							drclass					/// 
							]

	// no checks included yet
	// no marksample yet

	local debugflag		= "`debug'"~=""
	if ("`noisily'"=="") local qui qui
		
	*** extract details of estimation
	
	// model
	mata: st_local("model",`mname'.model)
	di "Model: `model'"
	mata: st_local("numeqns",strofreal(cols(`mname'.eqnlistNames)))
	mata: st_local("numeqnsY",strofreal(cols(`mname'.nameYtilde)))
	mata: st_local("numeqnsD",strofreal(cols(`mname'.nameDtilde)))
	mata: st_local("numeqnsZ",strofreal(cols(`mname'.nameZtilde)))
	mata: st_local("nameY",`mname'.nameY)
	mata: st_local("listYtilde",invtokens(`mname'.nameYtilde))
	di "Number of Y estimating equations: `numeqnsY'"
	if `numeqnsD' {
		mata: st_local("listD",invtokens(`mname'.nameD))
		mata: st_local("listDtilde",invtokens(`mname'.nameDtilde))
		di "Number of D estimating equations: `numeqnsD'"
	}
	if `numeqnsZ' {
		mata: st_local("listZ",invtokens(`mname'.nameZ))
		mata: st_local("listZtilde",invtokens(`mname'.nameZtilde))
		di "Number of Z estimating equations: `numeqnsZ'"
	}		 
	
	// folds and fold IDs
	mata: st_local("hasfoldvars",strofreal(cols(`mname'.idFold)))

	// if empty:
	// add fold IDs to model struct (col 1 = id, col 2 = fold id 1, col 3 = fold id 2 etc.)
	// first initialize with id
	
	if `hasfoldvars'==0 {
		mata: `mname'.idFold = st_data(., ("`mname'_id"))
	}

	forvalues m=1/`reps' {
	
		if `hasfoldvars'==0 {
			*** gen folds
			cap drop `mname'_fid_`m'
			tempvar uni cuni
			qui gen double `uni' = runiform() if `mname'_sample
			qui cumul `uni' if `mname'_sample, gen(`cuni')
			qui gen int `mname'_fid_`m' = ceil(`kfolds'*`cuni') if `mname'_sample
			// add fold id to model struct (col 1 = id, col 2 = fold id)
			mata: `mname'.idFold = (`mname'.idFold , st_data(., ("`mname'_fid_`m'")))
		}
		if ("`tabfold'"!="") {
			di
			di "Overview of frequencies by fold (sample `m'):"
			tab `mname'_fid_`m' if `mname'_sample
			di
		}
	
	}

	// blank eqn - declare this way so that it's a struct and not transmorphic
	// used multiple times below
	tempname eqn
	mata: `eqn' = init_eqnStruct()

	forvalues m=1/`reps' {
	
		di
		di as text "Starting cross-fitting (sample = `m')"

		*** initialize tilde variables
		forvalues i=1/`numeqns' {
			mata: `eqn'=*(`mname'.eqnlist[1,`i'])
			mata: st_local("vtilde",`eqn'.Vtilde)
			/// macro m is resampling counter
			cap drop `vtilde'_`m'
			qui gen double `vtilde'_`m'=.
		}
			
		*** do cross-fitting
		
		forvalues i=1/`numeqns' {
		
			// initialize prior to calling crossfit
			mata: `eqn'=*(`mname'.eqnlist[1,`i'])
			mata: st_local("vtilde",`eqn'.Vtilde)
			mata: st_local("vname",`eqn'.Vname)
			mata: st_local("eststring",`eqn'.eststring)
			mata: st_local("eqntype",`eqn'.eqntype)
			// seems to be unused
			// mata: st_local("vtype",`eqn'.vtype)
			local touse `mname'_sample
			// always request residuals not fitted values
			local resid resid
	
			di as text "Cross-fitting equation `i' (`vname', `vtilde')" _c
	
			/* why not used here but used in interactive code?
			// has the equation already been crossfitted?
			mata: st_numscalar("cvdone",`eqn'.crossfitted)
			if ("`cvdone'"=="1") continue
			*/
			
			if ("`eqntype'"=="yeq") {
				local treatvar	`listD'
			}
			else if ("`eqntype'"=="deq") & ("`model'"=="interactive") {
				local treatvar
			}
			else if ("`eqntype'"=="deq") {
				local treatvar	`listZ'
			}
			else if ("`eqntype'"=="zeq") {
				local treatvar
			}
			else {
				di as err "Unknown equation type `eqntype'"
				exit 198
			}
	
			crossfit if `touse',					///
				eststring(`eststring')				///
				kfolds(`kfolds')					///
				foldvar(`mname'_fid_`m')			///
				vtilde(`vtilde'_`m')				///
				vname(`vname')						///
				treatvar(`treatvar')				///
				`resid'
			
			// store MSE and sample size
			if ("`eqntype'"=="yeq") {
				mata: add_to_eqn01(`mname',`i',"`mname'_id `vtilde'", `r(mse0)',`r(N0)',0)
				mata: add_to_eqn01(`mname',`i',"`mname'_id `vtilde'", `r(mse1)',`r(N1)',1)
			}
			else if ("`eqntype'"=="deq") & ("`model'"=="interactive") {
				mata: add_to_eqn(`mname',`i',"`mname'_id `vtilde'", `r(mse)',`r(N)')
			}
			else if ("`eqntype'"=="deq") {
				mata: add_to_eqn01(`mname',`i',"`mname'_id `vtilde'", `r(mse0)',`r(N0)',0)
				mata: add_to_eqn01(`mname',`i',"`mname'_id `vtilde'", `r(mse1)',`r(N1)',1)
			}
			else if ("`eqntype'"=="zeq") {
				mata: add_to_eqn(`mname',`i',"`mname'_id `vtilde'", `r(mse)',`r(N)')
			}
	
		}
		
		*** print results & find optimal model
	
		di
		di as res "Reporting crossfitting results (sample=`m')

		// interactive model
		if "`model'"=="interactive" {
	
			// dependent variable
			_ddml_report_crossfit_res_mspe `mname', etype(yeq) vlist(`nameY') m(`m') zett(0)
			_ddml_report_crossfit_res_mspe `mname', etype(yeq) vlist(`nameY') m(`m') zett(1)

			// D variable
			_ddml_report_crossfit_res_mspe `mname', etype(deq) vlist(`listD') m(`m')

		}
	
		// late model
		if "`model'"=="late" {
	
			// dependent variable
			_ddml_report_crossfit_res_mspe `mname', etype(yeq) vlist(`nameY') m(`m') zett(0)
			_ddml_report_crossfit_res_mspe `mname', etype(yeq) vlist(`nameY') m(`m') zett(1)
	
			// D variable
			_ddml_report_crossfit_res_mspe `mname', etype(deq) vlist(`listD') m(`m') zett(0)
			_ddml_report_crossfit_res_mspe `mname', etype(deq) vlist(`listD') m(`m') zett(1)
			
			// Z variable
			_ddml_report_crossfit_res_mspe `mname', etype(zeq) vlist(`listZ') m(`m')

		}	
	}

end


mata:

struct eqnStruct init_eqnStruct()
{
	struct eqnStruct scalar		e
	return(e)
}

void add_to_eqn(					struct ddmlStruct m,
									real scalar eqnumber,
									string scalar vnames,
									real scalar mse,
									real scalar n)
{
	pointer(struct eqnStruct) scalar p
	p				= m.eqnlist[1,eqnumber]
	//(*p).idVtilde	= st_data(., tokens(vnames))
	(*p).MSE		= ((*p).MSE \ mse)
	(*p).N			= n
}

void add_to_eqn01(					struct ddmlStruct m,
									real scalar eqnumber,
									string scalar vnames,
									real scalar mse,
									real scalar n, 
									real scalar Z)
{
	pointer(struct eqnStruct) scalar p
	p				= m.eqnlist[1,eqnumber]
	//(*p).idVtilde	= st_data(., tokens(vnames))
	if (Z==0) {
		(*p).MSE0		= ((*p).MSE0 \ mse)
		(*p).N0			= n
	}
	else {
		(*p).MSE1		= ((*p).MSE1 \ mse)
		(*p).N1			= n
	}

}

end
