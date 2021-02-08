program define qddml, eclass					//  sortpreserve handled in _ivlasso
	syntax [anything] [if] [in] [aw pw],		/// note no "/" after pw
		[										///
		model(name)								///
		method(string)							///
		verbose 								///
		mname(name)								///
		///lasso								/// use lasso instead (not implemented yet)
		///type(string)							///
		debug 									///
		seed(int 0)								///
		cmd(name)								///
		CMDOPTions(string asis)					///
		* ]

	mata: s_ivparse("`anything'")

	local depvar	`s(depvar)'
	local dendog	`s(dendog)'
	local dexog		`s(dexog)'
	local xctrl		`s(xctrl)'
	local exexog	`s(exexog)'
	if "`debug'"!="" {
		di "`depvar'"
		di "`dendog'"
		di "`dexog'"
		di "`xctrl'"
		di "`exexog'"		
	}

	if "`verbose'"=="" local qui qui
	if "`cmd'"=="" local cmd pystacked

	**** syntax checks
	if ("`model'"=="optimaliv") {
		if "`dexog'"!="" {
			di as error "no exogenous treatments allowed"
			exit 198
		}
	} 
	else if ("`model'"=="iv") {
		if "`dexog'"!="" {
			di as error "no exogenous treatments allowed"
			exit 198
		}
		if ("`xctrl'"=="") {
			di as error "no (high-dimensional) controls specified"
			exit 198
		}
	}
	else if ("`model'"=="late") {
		if "`dexog'"!="" {
			di as error "no exogenous treatments allowed"
			exit 198
		}
		if ("`xctrl'"=="") {
			di as error "no (high-dimensional) controls specified"
			exit 198
		}
	}
	else if ("`model'"=="partial") {
		if "`dendog'"!="" {
			di as error "no endogenous treatments allowed"
			exit 198
		}
		if "`exexog'"!="" {
			di as error "no excluded instruments allowed"
			exit 198
		}
		if ("`xctrl'"=="") {
			di as error "no (high-dimensional) controls specified"
			exit 198
		}
	}
	else if ("`model'"=="interactive") {
		if "`dendog'"!="" {
			di as error "no endogenous treatments allowed"
			exit 198
		}
		if "`exexog'"!="" {
			di as error "no excluded instruments allowed"
			exit 198
		}
		if ("`xctrl'"=="") {
			di as error "no (high-dimensional) controls specified"
			exit 198
		}
	}		

	*** estimation
	`qui' ddml init `model', mname(`mname')
	if ("`model'"=="optimaliv") {
		`qui' ddml yeq, gen(y) mname(`mname'): `cmd' `depvar' `xctrl', `cmdoptions'  
		`qui' ddml deq, gen(d) mname(`mname'): `cmd' `dendog' `xctrl', `cmdoptions' 
		`qui' ddml dheq, gen(z) mname(`mname'): `cmd' `dendog' `xctrl' `exexog', `cmdoptions' 
	} 
	else if ("`model'"=="iv") {
		`qui' ddml yeq, gen(y) mname(`mname'): `cmd' `depvar' `xctrl', `cmdoptions' 
		local j = 1
		foreach d of varlist `dendog' {
			`qui' ddml deq, gen(d`j') mname(`mname'): `cmd' `d' `xctrl', `cmdoptions' 
			local j = `j' + 1
		}
		local j = 1
		foreach z of varlist `exexog' {
			`qui' ddml zeq, gen(z`j') mname(`mname'): `cmd' `z' `xctrl', `cmdoptions' 
			local j = `j' + 1
		}
	}
	else if ("`model'"=="late") {
		`qui' ddml yeq, gen(y) mname(`mname'): `cmd' `depvar' `xctrl', `cmdoptions' 
		`qui' ddml deq, gen(d) mname(`mname'): `cmd' `dendog' `xctrl', `cmdoptions' 
		`qui' ddml zeq, gen(z) mname(`mname'): `cmd' `exexog' `xctrl', `cmdoptions' 
	}
	else if ("`model'"=="partial") {
		`qui' ddml yeq, gen(y) mname(`mname'): `cmd' `depvar' `xctrl', `cmdoptions' 
		local j = 1
		foreach d of varlist `dexog' {
			`qui' ddml deq, gen(d`j') mname(`mname'): `cmd' `d' `xctrl', `cmdoptions' 
			local j = `j' + 1
		}
	}
	else if ("`model'"=="interactive") {
		`qui' ddml yeq, gen(y) mname(`mname'): `cmd' `depvar' `xctrl', `cmdoptions' 
		`qui' ddml deq, gen(d) mname(`mname'): `cmd' `dexog' `xctrl', `cmdoptions' 
	}		
	`qui' ddml crossfit, mname(`mname')
	ddml estimate, mname(`mname')

end 

mata:
// basic IV parser
// taken from: https://github.com/statalasso/pdslasso/blob/master/ivlasso.ado
void s_ivparse(string scalar cmdline)
{
	// dep var is first word on line
	depvar	= ""
	i 		= 1
	c		= substr(cmdline,1,1)
	while (!((c==" ") | (c=="") | (c=="(") )) {
		depvar	= depvar + c
		i		= i + 1
		c		= substr(cmdline,i,1)
	}
	// loop through remainder, separating into dexog and parenthetical lists
	dexog	= ""
	dendog	= ""
	xctrl	= ""
	exexog	= ""
	pclauselist = J(0, 1, "")
	while (!(c=="")) {
		
		if (c!="(") {
			while (!((c=="(") | (c==""))) {
				dexog = dexog + c
				i	= i + 1
				c	= substr(cmdline,i,1)
			}
		}
		else {
			// start counter and initialize pclause
			pbal=1
			pclause = ""
			i	= i + 1
			c	= substr(cmdline,i,1)
			while (!((pbal==0) | (c==""))) {
				if (c=="(") {
					pbal=pbal+1
				}
				if (c==")") {
					pbal=pbal-1
				}
				if (pbal!=0) {
					pclause = pclause + c
					i	= i + 1
					c	= substr(cmdline,i,1)
				}
			}
			pclauselist = (pclauselist \ pclause)
			i	= i + 1
			c	= substr(cmdline,i,1)
			
			if (strpos(pclause,"=")) {
				epos	= strpos(pclause,"=")
				// strrpos unavailable in Stata 13
				// epos2	= strrpos(pclause,"=")
				epos2	= strlen(pclause) - strpos(strreverse(pclause),"=") + 1
				if (epos==epos2) {
					dendog = dendog + substr(pclause, 1, epos-1)
					exexog = exexog + substr(pclause, epos+1, .)
				}
				else {
					errprintf("\nsyntax error - too many =s\n")
					exit(198)
				}
			}
			else {
				xctrl = xctrl + pclause + " "
			}
			
		}
	}
	depvar	= strtrim(stritrim(depvar))
	dexog	= strtrim(stritrim(dexog))
	dendog	= strtrim(stritrim(dendog))
	xctrl	= strtrim(stritrim(xctrl))
	exexog	= strtrim(stritrim(exexog))
	st_global("s(exexog)",exexog)
	st_global("s(xctrl)",xctrl)
	st_global("s(dendog)",dendog)
	st_global("s(dexog)",dexog)
	st_global("s(depvar)",depvar)
}
end