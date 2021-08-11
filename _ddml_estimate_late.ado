*** ddml estimation: LATE model
* notes:
* add check somewhere that only a single D and a single Z are allowed.

program _ddml_estimate_late, eclass sortpreserve

	syntax namelist(name=mname) [if] [in] ,		/// 
								[				///
								ROBust			///
								show(string)	/// dertermines which to post
								clear			/// deletes all tilde-variables (to be implemented)
								replist(string)	/// list of resamplings to estimate
								avplot			///
								debug			///
								* ]

	// base sample for estimation - determined by if/in
	marksample touse
	// also exclude obs already excluded by ddml sample
	qui replace `touse' = 0 if `mname'_sample==0

	// what does this do?
	if ("`show'"=="") {
		local show opt
	}

	//mata: `mname'.nameDtilde
	mata: st_local("Ztilde",invtokens(`mname'.nameZtilde))
	mata: st_local("Dtilde",invtokens(`mname'.nameDtilde))
	mata: st_local("Ytilde",invtokens(`mname'.nameYtilde))
	mata: st_local("nameD",invtokens(`mname'.nameD))
	mata: st_local("nameY",invtokens(`mname'.nameY))
	mata: st_local("nameZ",invtokens(`mname'.nameZ))

	if ("`debug'"!="") {
		di "`Ytilde'"
		di "`Ztilde'"
		di "`Dtilde'"
	}

	_ddml_allcombos `Ytilde' - `Ytilde' - `Dtilde' - `Dtilde' - `Ztilde' ,	///
		`debug'																///
		addprefix("")

	local ncombos = r(ncombos)
	local tokenlen = `ncombos'*2
	local y0list `r(colstr1)'
	local y1list `r(colstr2)'
	local d0list `r(colstr3)'
	local d1list `r(colstr4)'
	local Zlist `r(colstr5)' 

	// replist empty => do for first resample
	// replist = "all" do for all resamples
	mata: st_local("numreps",strofreal(`mname'.nreps))
	if "`replist'"=="" {
		local replist 1
	}
	else if "`replist'"=="all" {
		numlist "1/`numreps'"
		local replist "`r(numlist)'"
	}
	else {
		numlist "`replist'"
		local replist "`r(numlist)'"
	}

	// do for each specified resamples
	foreach m in `replist' {
		// text used in output below
		if `numreps'>1 {
			local stext " (sample=`m')"
		}
		forvalues i = 1(2)`tokenlen' {
			if "`show'"=="all" {
				tokenize `y0list' , parse("-")
				local y0 ``i''
				tokenize `y1list' , parse("-")
				local y1 ``i''
				tokenize `d0list' , parse("-")
				local d0 ``i''
				tokenize `d1list' , parse("-")
				local d1 ``i''
				tokenize `Zlist' , parse("-")
				local z ``i''
				di
				di as text "DML`stext':" _col(52) "Number of obs   =" _col(70) as res %9.0f e(N)
				di as text "E[y|X,Z=0] = " as res "`y0'_`m'"
				di as text "E[y|X,Z=1] = " as res "`y1'_`m'"
				di as text "E[D|X,Z=0] = " as res "`d0'_`m'"
				di as text "E[D|X,Z=1] = " as res "`d1'_`m'"
				di as text "E[Z|X]     = " as res "`z'_`m'"
				_ddml_late, yvar(`nameY') y0tilde(`y0'_`m') y1tilde(`y1'_`m')	///
							dvar(`nameD') d0tilde(`d0'_`m') d1tilde(`d1'_`m')	///
							zvar(`nameZ') ztilde(`z'_`m')						///
							touse(`touse')
			}
		}
	
		mata: st_local("Y0opt",`mname'.nameY0opt[`m'])
		mata: st_local("Y1opt",`mname'.nameY1opt[`m'])
		mata: st_local("D0opt",`mname'.nameD0opt[`m'])
		mata: st_local("D1opt",`mname'.nameD1opt[`m'])
		mata: st_local("Zopt",`mname'.nameZopt[`m'])
		di
		if `ncombos' > 1 {
			di as text "Optimal DML model`stext':" _c
		}
		else {
			di as text "DML`stext':" _c
		}
		di as text _col(52) "Number of obs   =" _col(70) as res %9.0f e(N)
		di as text "E[y|X,Z=0] = " as res "`Y0opt'_`m'"
		di as text "E[y|X,Z=1] = " as res "`Y1opt'_`m'"
		di as text "E[D|X,Z=0] = " as res "`D0opt'_`m'"
		di as text "E[D|X,Z=1] = " as res "`D1opt'_`m'"
		di as text "E[Z|X]     = " as res "`Zopt'_`m'"
		_ddml_late, yvar(`nameY') y0tilde(`Y0opt'_`m') y1tilde(`Y1opt'_`m')	///
					dvar(`nameD') d0tilde(`D0opt'_`m') d1tilde(`D1opt'_`m')	///
					zvar(`nameZ') ztilde(`Zopt'_`m')						///
					touse(`touse')


	}

	/*
	// display
	tempname b
	tempname V 
	mat `b' = e(b)
	mat `V' = e(V)
	matrix colnames `b' = `nameD'
	matrix rownames `b' = `nameY'
	matrix colnames `V' = `nameD'
	matrix rownames `V' = `nameD'
	local N = e(N)
	ereturn clear
	ereturn post `b' `V', depname(`Yopt') obs(`N') esample(`touse')
	if "`robust'"~="" {
		ereturn local vcetype   robust
	}
	ereturn display
	*/

end
 