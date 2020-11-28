*** ddml cross-fitting
program _ddml_crossfit_partial, eclass sortpreserve

	syntax [anything] [if] [in] , /// 
							[ kfolds(integer 2) ///
							NOIsily ///
							debug /// 
							Robust ///
							TABFold ///
							yrclass ///
							drclass /// 
							mname(name)	///
							]

	// no checks included yet
	// no marksample yet

	local debugflag		= "`debug'"~=""
		
	*** extract details of estimation
	
	// model
	mata: st_local("model",`mname'.model)
	mata: st_local("numeqns",strofreal(cols(`mname'.eqnlistNames)))
	mata: st_local("numeqnsY",strofreal(cols(`mname'.nameYtilde)))
	mata: st_local("numeqnsD",strofreal(cols(`mname'.nameDtilde)))
	mata: st_local("numeqnsZ",strofreal(cols(`mname'.nameZtilde)))
	di "Model: `model'"
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
	
	*** gen folds
	// create foldvar if not empty
	// Stata name will be mname_fid
	cap count if `mname'_fid < .
	if _rc > 0 {
		// fold var does not exist or is not a valid identifier
		cap drop `mname'_fid
		tempvar uni cuni
		qui gen double `uni' = runiform()
		qui cumul `uni', gen(`cuni')
		qui gen int `mname'_fid = ceil(`kfolds'*`cuni')
	}
	// add fold id to model struct (col 1 = id, col 2 = fold id)
	mata: `mname'.idFold = st_data(., ("`mname'_id", "`mname'_fid"))
	if ("`tabfold'"!="") {
		di
		di "Overview of frequencies by fold:"
		tab `mname'_fid
		di
	}
	//

	// blank eqn - declare this way so that it's a struct and not transmorphic
	// used multiple times below
	tempname eqn
	mata: `eqn' = init_eqnStruct()

	*** initialize tilde variables
	forvalues i=1/`numeqns' {
		mata: `eqn'=*(`mname'.eqnlist[1,`i'])
		mata: st_local("vtilde",`eqn'.Vtilde)
		cap drop `mname'_`vtilde'
		qui gen double `mname'_`vtilde'=.
	}

	*** estimate equations that do not require crossfitting
	// also report estimates for full sample for debugging purposes
	tempname crossfit
	forvalues i=1/`numeqns' {
		mata: `eqn'=*(`mname'.eqnlist[1,`i'])
		mata: st_numscalar("`crossfit'",`eqn'.crossfit)
		if `crossfit'==0 | `debugflag' {
			mata: st_local("vtilde",`eqn'.Vtilde)
			mata: st_local("vname",`eqn'.Vname)
			mata: st_local("eststring",`eqn'.eststring)
			local 0 "`eststring'"
			syntax [anything] , [*]
			local est_main `anything'
			local est_options `options'
			if `debugflag' {
				if `crossfit'==0 {
					di
					di "Estimating equation `i' (full sample, for debugging; no crossfit):"
				}
				else {
					di
					di "Estimating equation `i' (no crossfit):"
				}
				di "  est_main: `est_main'"
				di "  est_options: `est_options'"
			}
			else {
				// set quietly flag
				local quietly quietly
			}
			// estimate
			`quietly' `est_main', `est_options'
			// get fitted values and residuals for no-crossfit case
			if `crossfit'==0 {
				tempvar vtilde_i
				qui predict double `vtilde_i'
				qui replace `mname'_`vtilde' = `vname' - `vtilde_i'
			}
		}
	}
	
	*** do cross-fitting
	di
	di as text "Cross-fitting fold " _c
	forvalues k = 1(1)`kfolds' {
	
		if (`k'==`kfolds') {
			di as text "`k'"
		}
		else {
			di as text "`k' " _c
		}
		// ML is applied to I^c sample (all data ex partition k)
		qui {

			forvalues i=1/`numeqns' {
				mata: `eqn'=*(`mname'.eqnlist[1,`i'])
				mata: st_numscalar("r(crossfit)",`eqn'.crossfit)
				if r(crossfit) {
					mata: st_local("vtilde",`eqn'.Vtilde)
					mata: st_local("vname",`eqn'.Vname)
					mata: st_local("eststring",`eqn'.eststring)
					local 0 "`eststring'"
					syntax [anything] , [*]
					local est_main `anything'
					local est_options `options'
					di "Estimating equation `i':"
					di "  est_main: `est_main'"
					di "  est_options: `est_options'"
	
					// estimate excluding kth fold
					`est_main' if `mname'_fid!=`k', `est_options'
					// get fitted values and residuals for kth fold	
					tempvar vtilde_i
					qui predict double `vtilde_i' if `mname'_fid==`k' 
					qui replace `mname'_`vtilde' = `vname' - `vtilde_i' if `mname'_fid==`k'
				}
			}
		}
	}

	*** calculate MSE, store orthogonalized variables, etc.
	forvalues i=1/`numeqns' {
		mata: `eqn'=*(`mname'.eqnlist[1,`i'])
		mata: st_local("vtilde",`eqn'.Vtilde)
		tempvar vtilde_sq
		qui gen double `vtilde_sq' = `mname'_`vtilde'^2
		qui sum `vtilde_sq', meanonly
		mata: add_to_eqn(`mname',`i',"`mname'_id `mname'_`vtilde'", `r(mean)',`r(N)')
	}

	// loop through equations, display results, and save names of tilde vars with smallest MSE
	// dep var
	di
	di as res "Mean-squared error for y|X:"
	di _col(2) "Name" _c
	di _col(20) "Orthogonalized" _c
	di _col(40) "Command" _c
	di _col(54) "N" _c
	di _col(65) "MSPE"
	di "{hline 75}"
	display_mspe `mname', vname(`nameY')
	mata: `mname'.nameYopt		= "`r(optname)'"

	// loop through D vars (if any)
	if `numeqnsD' {
		di
		di as res "Mean-squared error for D|X:"
		di _col(2) "Name" _c
		di _col(20) "Orthogonalized" _c
		di _col(40) "Command" _c
		di _col(54) "N" _c
		di _col(65) "MSPE"
		di "{hline 75}"
		foreach var of varlist `listD' {
			display_mspe `mname', vname(`var')
			mata: `mname'.nameDopt		= (`mname'.nameDopt, "`r(optname)'")
		}
	}
	
	// loop through Z vars (if any)
	if `numeqnsZ' {
		di
		di as res "Mean-squared error for Z|X:"
		di _col(2) "Name" _c
		di _col(20) "Orthogonalized" _c
		di _col(40) "Command" _c
		di _col(54) "N" _c
		di _col(65) "MSPE"
		di "{hline 75}"
		foreach var of varlist `listZ' {
			display_mspe `mname', vname(`var')
			mata: `mname'.nameZopt		= (`mname'.nameZopt, "`r(optname)'")
		}
	}


end

program define display_mspe, rclass

	syntax name(name=mname), vname(varname)

	// blank eqn - declare this way so that it's a struct and not transmorphic
	// used multiple times below
	tempname eqn
	mata: `eqn' = init_eqnStruct()
	mata: st_local("numeqns",strofreal(cols(`mname'.eqnlistNames)))

	// initialize
	local minmse = .
	forvalues i=1/`numeqns' {
		mata: `eqn'=*(`mname'.eqnlist[1,`i'])
		mata: st_global("r(vname)",`eqn'.Vname)
		mata: st_local("vtilde",`eqn'.Vtilde)
		if "`vname'"==r(vname) {
			mata: st_local("command",`eqn'.command)
			mata: st_local("MSE",strofreal(`eqn'.MSE))
			mata: st_local("N",strofreal(`eqn'.N))
			if `MSE' < `minmse' {
				local optname `vtilde'
				local minmse `MSE'
			}
			di _col(2) "`vname'" _c
			di _col(20) "`vtilde'" _c
			di _col(40) "`command'" _c
			di _col(50) %6.0f `N' _c
			di _col(60) %10.6f `MSE'
		}
	}
	
	return local optname	`optname'
	return scalar minmse	=`minmse'
	
	mata: mata drop `eqn'
	
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
	(*p).idVtilde	= st_data(., tokens(vnames))
	(*p).MSE		= mse
	(*p).N			= n
}

end
