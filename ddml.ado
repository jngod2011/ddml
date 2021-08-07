*** feb 1, 2021
* ddml v0.3

* notes:
* e.command		= tokens(estcmd)[1,1] fails if command string starts with a prefix e.g. capture

program ddml, eclass

	version 13
	
	local allargs `0'
	tokenize "`allargs'", parse(",")
	local mainargs `1'
	macro shift
	local restargs `*'

	// local subcmd : word 1 of `mainargs'
	tokenize "`mainargs'"
	local subcmd `1'
	macro shift
	// restmainargs is main args minus the subcommand
	local restmainargs `*'
	
	local allsubcmds	update describe save export use drop copy sample init yeq deq zeq crossfit estimate dheq
	if strpos("`allsubcmds'","`subcmd'")==0 {
		di as err "error - unknown subcommand `subcmd'"
		exit 198
	}

	*** get latest version
	if "`subcmd'"=="update" {
		net install ddml, from(https://raw.githubusercontent.com/aahrens1/ddml/master/)
	} 
	
	*** describe model
	if substr("`subcmd'",1,4)=="desc" {
		local 0 "`restargs'"
		syntax , [ mname(name)  * ]
		if "`mname'"=="" {
			local mname m0 // sets the default name
		}
		check_mname "`mname'"
		_ddml_describe `mname', `options'
	}

	*** save model
	if "`subcmd'"=="save" {
		local fname: word 2 of `mainargs'
		local 0 "`restargs'"
		syntax , [ mname(name) * ]
		if "`mname'"=="" {
			local mname m0 // sets the default name
		}
		check_mname "`mname'"
		_ddml_save, mname(`mname') fname(`fname') `options'

	}
	
	*** export model
	if "`subcmd'"=="export" {
		local using: word 2 of `mainargs'
		if "`using'"~="using" {
			di as err "invalid syntax - missing destination filename"
			exit 198
		}
		local fname: word 3 of `mainargs'
		local 0 "`restargs'"
		syntax ,[ mname(name) * ]
		if "`mname'"=="" {
			local mname m0 // sets the default name
		}
		check_mname "`mname'"
		_ddml_export, mname(`mname') fname(`fname') `options'

	}
	
	*** use model
	if "`subcmd'"=="use" {
		local fname: word 2 of `mainargs'
		local 0 "`restargs'"
		syntax , [ mname(name) * ]
		if "`mname'"=="" {
			local mname m0 // sets the default name
		}
		// no need to check name
		_ddml_use, mname(`mname') fname(`fname') `options'
	}

	*** drop model
	if "`subcmd'"=="drop" {
		local 0 "`restargs'"
		syntax , [mname(name)]
		if "`mname'"=="" {
			local mname m0 // sets the default name
		}
		check_mname "`mname'"
		_ddml_drop, mname(`mname')
	}

	*** copy model
	if "`subcmd'"=="copy" {
		local 0 "`restargs'"
		syntax , mname(name) newmname(name)
		if "`mname'"=="" {
			local mname m0 // sets the default name
		}
		check_mname "`mname'"
		_ddml_copy, mname(`mname') newmname(`newmname')
	}

	*** initialize new estimation
	if "`subcmd'"=="init" {
		local model: word 2 of `mainargs'
		if ("`model'"!="partial"&"`model'"!="iv"&"`model'"!="interactive"&"`model'"!="late"&"`model'"!="optimaliv") {
			di as err "no or wrong model specified." 
			exit 1
		}
		local 0 "`restargs'"
		// fold variable is option; default is ddmlfold
		syntax , [mname(name) nolie]

		if "`mname'"=="" {
			local mname m0 // sets the default name
		}

		// distinct model: no-LIE optimal IV
		if "`model'"=="optimaliv"&"`nolie'"!="" local model optimaliv_nolie

		mata: `mname'=init_ddmlStruct()
		// create and store id variable
		cap drop `mname'_id
		qui gen double `mname'_id	= _n
		mata: `mname'.id			= st_data(., "`mname'_id")
		// create and store sample indicator; initialized so all obs are used
		cap drop `mname'_sample
		qui gen byte `mname'_sample = 1
		// add sample indicator to model struct (col 1 = id, col 2 = fold id)
		mata: `mname'.idSample		= st_data(., ("`mname'_id", "`mname'_sample"))
		// fill by hand
		mata: `mname'.model			= "`model'"
	}
	
	*** set sample, foldvar, etc.
	if "`subcmd'"=="sample" {
		local 0 "`restmainargs' `restargs'"
		syntax [if] [in] , [mname(name)  * ]
		if "`mname'"=="" {
			local mname m0 // sets the default name
		}
		check_mname "`mname'"
		_ddml_sample `if' `in' , mname(`mname') `options'
	}

	*** add equation  
	if "`subcmd'"=="yeq"|"`subcmd'"=="deq"|"`subcmd'"=="zeq"|"`subcmd'"=="dheq" {

		** parsing
		// macro options has eqn to be estimated set off from the reset by a :
		tokenize `" `restargs' "', parse(":")
		// parse character is in macro `2'
		local eqn `3'
		local 0 "`1'"
		syntax ,	///			
					gen(name)		///
					[				///
					vname(name)		///
					genh(name)	/// (intended for LIE)
					mname(name)		///
					vtype(string)   ///  "double", "float" etc
					REPlace         ///
					NOPrefix 		/// don't add model name as prefix
					]

		** check that ddml has been initialized
		// to add
		if "`mname'"=="" {
			local mname m0 // sets the default name
		}
		check_mname "`mname'"

		** vname: use 2nd word of eq as the default 
		di "`eqn'"
		if "`vname'"=="" {
			local vname : word 2 of `eqn'
		}

		** drop gen var if it already exists
		if "`replace'"!="" {
			cap drop `gen'
		}

		** check that equation is consistent with model
		mata: st_local("model",`mname'.model)
		if ("`subcmd'"=="zeq"&("`model'"=="optimaliv"|"`model'"=="optimaliv_nolie"|"`model'"=="partial"|"`model'"=="interactive")) {
			di as err "not allowed; zeq not allowed with `model'"
		}
		if ("`subcmd'"=="dheq"&("`model'"!="optimaliv_nolie")) {
			di as err "not allowed; dheq not allowed with `model'"
		}

		** add prefix to vtilde
		if "`noprefix'"=="" {
			local prefix `mname'_
		}
		else {
			local prefix
		}

		** split equation -- only required for D-eq with LIE
		if "`model'"=="optimaliv" {
			tokenize `" `eqn' "', parse("|")
			// parse character is in macro `2'
			local eqn `1'
			local eqn_h `3'
			if "`2'`3'"=="" {
				di as err "estimation command for E[D|X,Z] missing"
				exit 198
			}
		}

		if "`model'"=="optimaliv"&"`genh'"=="" {
			local genh `genh'_h
		}

		// subcmd macro tells add_eqn(.) which list to add it to
		mata: add_eqn(`mname', "`subcmd'", "`vname'", "`prefix'`gen'","`eqn'","`vtype'","`noprefix'","`eqn_h'","`prefix'`genh'")
		local newentry `r(newentry)'
		if "`subcmd'"=="yeq" {
			// check if nameY is already there; if it is, must be identical to vname here
			mata: st_global("r(vname)",`mname'.nameY)
			if "`r(vname)'"=="" {
				mata: `mname'.nameY		= "`vname'"
			}
			else if "`r(vname)'"~="`vname'" {
				di as err "error - incompatible y variables"
				exit 198
			}
		}
		if "`subcmd'"=="deq" {
			// check if nameD already has vname; if not, add it to the list
			mata: st_global("r(vname)",invtokens(`mname'.nameD))
			if "`r(vname)'"=="" {
				mata: `mname'.nameD		= "`vname'"
			}
			else {
				local dlist `r(vname)' `vname'
				local dlist : list uniq dlist
				mata: `mname'.nameD		= tokens("`dlist'")
			}
		}
		if "`subcmd'"=="dheq" {
			// check if nameDH already has vname; if not, add it to the list
			mata: st_global("r(vname)",invtokens(`mname'.nameDH))
			if "`r(vname)'"=="" {
				mata: `mname'.nameDH	= "`vname'"
			}
			else {
				local dhlist `r(vname)' `vname'
				local dhlist : list uniq dhlist
				mata: `mname'.nameDH	= tokens("`dhlist'")
			}
		}
		if "`subcmd'"=="zeq" {
			// check if nameZ already has vname; if not, add it to the list
			mata: st_global("r(vname)",invtokens(`mname'.nameZ))
			if "`r(vname)'"=="" {
				mata: `mname'.nameZ		= "`vname'"
			}
			else {
				local zlist `r(vname)' `vname'
				local zlist : list uniq zlist
				mata: `mname'.nameZ		= tokens("`zlist'")
			}
		}
		if `newentry' {
			di as text "Equation successfully added."
		}
		else {
			di as text "Equation successfully replaced."
		}
	}

	*** cross-fitting
	if "`subcmd'" =="crossfit" {

		local 0 "`restargs'"
		syntax , [ mname(name) * ]
		if "`mname'"=="" {
			local mname m0 // sets the default name
		}
		check_mname "`mname'"

		mata: st_global("r(model)",`mname'.model)

		if ("`r(model)'"=="partial") {
		_ddml_crossfit_additive , `options' mname(`mname') 
		}
		if ("`r(model)'"=="iv") {
		_ddml_crossfit_additive , `options' mname(`mname') 
		}
		if ("`r(model)'"=="interactive") {
		_ddml_crossfit_interactive , `options' mname(`mname') 
		}
		if ("`r(model)'"=="late") {
		_ddml_crossfit_interactive , `options' mname(`mname') 
		}
		if ("`r(model)'"=="optimaliv") {
		_ddml_crossfit_additive , `options' mname(`mname') 
		}
		if ("`r(model)'"=="optimaliv_nolie") {
		_ddml_crossfit_additive , `options' mname(`mname') 
		}
	}

	*** estimate
	if "`subcmd'" =="estimate" {
		local 0 "`restargs'"
		// mname is required; could make optional with a default name
		syntax , [mname(name) * resample(integer 1)]

		if "`mname'"=="" {
			local mname m0 // sets the default name
		}

		check_mname "`mname'"

		mata: st_global("r(model)",`mname'.model)

		if (`resample'<=1) {
			if ("`r(model)'"=="partial") {
				_ddml_estimate_partial `mname', `options'
			}
			if ("`r(model)'"=="iv") {
				_ddml_estimate_iv `mname', `options'
			}
			if ("`r(model)'"=="interactive") {
				_ddml_estimate_interactive `mname', `options'
			}
			if ("`r(model)'"=="late") {
				_ddml_estimate_late `mname', `options'
			}
			if ("`r(model)'"=="optimaliv") {
				_ddml_estimate_optimaliv `mname', `options'
			}
			if ("`r(model)'"=="optimaliv_nolie") {
				_ddml_estimate_optimaliv_nolie `mname', `options'
			}
		} 
		else {
			tempname b_resample v_resample bi vi b V
			mat `b_resample' = J(1,`resample',.)
			mat `v_resample' = J(1,`resample',.)
			forvalues i= 1(1)`resample' {
				if ("`r(model)'"=="partial") {
					_ddml_estimate_partial `mname', `options'
				}
				if ("`r(model)'"=="iv") {
					_ddml_estimate_iv `mname', `options'
				}
				if ("`r(model)'"=="interactive") {
					_ddml_estimate_interactive `mname', `options'
				}
				if ("`r(model)'"=="late") {
					_ddml_estimate_late `mname', `options'
				}
				if ("`r(model)'"=="optimaliv") {
					_ddml_estimate_optimaliv `mname', `options'
				}
				if ("`r(model)'"=="optimaliv_nolie") {
					_ddml_estimate_optimaliv_nolie `mname', `options'
				}
				mat bi = e(b)
				mat vi = e(V)
				mat `b_resample'[1,`i'] = `bi'[1,1]
				mat `v_resample'[1,`i'] = `vi'[1,1]
			}
			mata: st_matrix("`b'",mean(st_matrix("`b_resample'")))
			mata: st_matrix("`V'",mean(st_matrix("`v_resample'")))
			ereturn clear
			ereturn post `b' `V' //, depname(`Yopt') obs(`N') esample(`touse')
		}
	}
end

prog define check_mname

	args mname

	mata: st_local("isnull",strofreal(findexternal("`mname'")==NULL))
	if `isnull' {
		di as err "model `mname' not found"
		exit 3259
	}
	
	mata: st_local("eltype",eltype(`mname'))
	if "`eltype'"~="struct" {
		di as err "model `mname' is not a struct"
		exit 3259
	}

	mata: st_local("structname",structname(`mname'))
	if "`structname'"~="ddmlStruct" {
		di as err "model `mname' is not a ddmlStruct"
		exit 3000
	}

end

********************************************************************************
*** Mata section															 ***
********************************************************************************

mata:

struct ddmlStruct init_ddmlStruct()
{
	struct ddmlStruct scalar	d

	d.eqnlist		= J(1,0,NULL)
	d.nameY			= ""
	d.nameYtilde	= J(1,0,"")
	d.nameYopt		= ""
	d.nameD			= J(1,0,"")
	d.nameDtilde	= J(1,0,"")
	d.nameDopt		= J(1,0,"")
	d.nameDH		= J(1,0,"")
	d.nameDHtilde	= J(1,0,"")
	d.nameDHopt		= J(1,0,"")
	d.nameZ			= J(1,0,"")
	d.nameZtilde	= J(1,0,"")
	d.nameZopt		= J(1,0,"")
	return(d)
}

struct ddmlStruct use_model(		string scalar fname)
{
	struct ddmlStruct scalar	m
	fh = fopen(fname,"r")
	m = fgetmatrix(fh,1)	// nonzero second argument required for "strict"
	fclose(fh)
	return(m)
}

struct eqnStruct init_eqnStruct()
{
	struct eqnStruct scalar		e
	return(e)
}

void add_eqn(						struct ddmlStruct m,
									string scalar eqntype,
									string scalar vname,
									string scalar vtilde,
									string scalar estcmd,
									string scalar vtype,
									string scalar noprefix,
									string scalar estcmd_h,
									string scalar vtilde_h
									)
{
	struct eqnStruct scalar		e, e0

	e.eqntype		= eqntype
	e.Vname			= vname
	e.Vtilde		= vtilde
	e.Vtilde_h 		= vtilde_h
	e.eststring		= estcmd
	e.command		= tokens(estcmd)[1,1]
	if (estcmd_h~="") {
		e.eststring_h 	= estcmd_h
		e.command_h		= tokens(estcmd_h)[1,1]
	}
	e.vtype		 	= vtype
	e.crossfitted	= 0

	newentry		= 1

	if (cols(m.eqnlist)==0) {
		m.eqnlist		= &e
		m.eqnlistNames	= vtilde
	}
	else {
		// look for existing entry
		for (i=1;i<=cols(m.eqnlist);i++) {
			e0 = *(m.eqnlist[i])
			if (e0.Vtilde==vtilde) {
				// replace
				m.eqnlist[i]		= &e
				// unnecessary?
				m.eqnlistNames[i]	= vtilde
				newentry = 0
			}
		}
		if (newentry==1) {
			// new entry
			m.eqnlist		= (m.eqnlist, &e)
			m.eqnlistNames	= (m.eqnlistNames, vtilde)
		}
	}

	// add to appropriate list of tilde variables if a new entry
	if (newentry) {
		if (eqntype=="yeq") {
			m.nameYtilde	= (m.nameYtilde, vtilde)
		}
		else if (eqntype=="deq") {
			m.nameDtilde	= (m.nameDtilde, vtilde)
			if (estcmd_h!="") {
				m.nameDHtilde	= (m.nameDHtilde, vtilde_h)
			}
		}
		else if (eqntype=="dheq") {
			m.nameDHtilde	= (m.nameDHtilde, vtilde)
		}
		else if (eqntype=="zeq") {
			m.nameZtilde	= (m.nameZtilde, vtilde)
		}
	}
	
	st_global("r(newentry)",strofreal(newentry))
}

end 
