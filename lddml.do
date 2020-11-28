* Locals used in whichddml; set when compiled
local stata_version `c(stata_version)'
local born_date `c(born_date)'
local current_date `c(current_date)'

version 13
mata:
mata clear

void whichddml()
{
""
"ddml ver xxx 3nov2020"
"compiled under Stata " + "`stata_version'" + " born " + "`born_date'"
"Mata library for ddml and related programs"
"authors AA/MS"
st_sclear()
st_global("s(stata_born_date)","`born_date'")
st_global("s(stata_version)","`stata_version'")
st_global("s(compiled_date)","`current_date")
}

// some of the string matrices are actually vectors
struct ddmlStruct {
	string scalar		model			// model; partial, iv, late, etc
	real colvector		id				// id variable (name in Stata will be modelname_id)
	real matrix			idFold			// col 1 = id, col 2 = fold identifier
	real matrix			idSample		// col 1 = id, col 2 = sample indicator
	string scalar		strDatavars		// string with expanded names of Stata variables
	string scalar		nameY			// dependent variable 
	string colvector	nameYtilde		// names of orthogonalized variables
	string scalar		nameYopt 		// name of optimal orthog. Y variable
	string scalar		nameY0opt		// name of optimal orthog. Y variable E[Y|D=0]
	string scalar		nameY1opt		// name of optimal orthog. Y variable E[Y|D=1]
	string colvector	nameD			// name of treatment variable(s)
	string matrix		nameDtilde		// names of orthogonalized treatment variables OR name of optimal instrument
	string matrix		nameDopt		// name of optimal orthog. D variable(s) (partial linear model)
	string matrix		nameD0opt		// name of optimal orthog. D variable(s) E[D|Z=0]
	string matrix		nameD1opt		// name of optimal orthog. D variable(s) E[D|Z=1]
	string colvector	nameZ			// name of instrument(s)
	string matrix		nameZtilde		// names of orthogonalized instruments
	string matrix		nameZopt		// names of optimal orthog. instruments
	pointer rowvector	eqnlist			// list of all orthog equations
	string rowvector	eqnlistNames		// names of corresponding Vtilde variable
}

// to add: boolean to indicate min MSE / optimal orthogonalized var
struct eqnStruct {
	string scalar		eqntype			// yeq, deq, zeq
	string scalar		Vname			// should perhaps rename to nameV
	string scalar		Vtilde			// should perhaps rename to nameVtilde
	real matrix			idVtilde		// col 1 = id, col 2 = orthogonalized
	string scalar		eststring
	string scalar		command
	real scalar			MSE
	real scalar 		MSE0
	real scalar 		MSE1
	real scalar			N
	real scalar 		N0
	real scalar 		N1
	real scalar			crossfit		// boolean, 0 or 1
}

mata mlib create lddml, dir(PERSONAL) replace
mata mlib add lddml *()
mata mlib index
mata describe using lddml

end
